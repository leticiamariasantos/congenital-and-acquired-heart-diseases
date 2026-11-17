# =============================================================================
# 01_funcoes_datasus.R
# Funções compartilhadas de download e extração dos DESFECHOS (DATASUS).
#
# Usadas por scripts/01_download_process_datasus.R (2010–2019) e
# scripts/06_etapa1_2020_2024.R (2020–2024), garantindo critérios idênticos.
#
#   SIH-RD : internações de menores de 1 ano, residentes em Campos dos
#            Goytacazes (330100), com diagnóstico principal OU secundário em
#            Q20–Q26 (desfecho principal) e Q20–Q28 (sensibilidade).
#   SINASC : nascidos vivos residentes com CODANOMAL contendo Q20–Q26 / Q20–Q28
#            e o total de nascidos vivos (denominador).
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Download (com cache em disco e retry)
# -----------------------------------------------------------------------------
# SINASC: um arquivo por ano.
baixar_sinasc_ano <- function(ano) {
  baixar_com_retry(
    arquivo_cache = file.path(CONFIG$dirs$cache_raw,
                              sprintf("SINASC_%s_%04d_raw.rds", CONFIG$uf, ano)),
    baixar = function() {
      microdatasus::fetch_datasus(
        year_start = ano, year_end = ano, uf = CONFIG$uf,
        information_system = "SINASC",
        timeout = 1800, stop_on_error = TRUE
      )
    },
    rotulo = sprintf("Baixando SINASC %s %04d", CONFIG$uf, ano)
  )
}

# SIH-RD: um arquivo por mês (o volume mensal é grande; granularidade mensal
# permite retomada em caso de falha e mantém a memória sob controle).
baixar_sih_mes <- function(ano, mes) {
  baixar_com_retry(
    arquivo_cache = file.path(CONFIG$dirs$cache_raw,
                              sprintf("SIH_RD_%s_%04d_%02d_raw.rds",
                                      CONFIG$uf, ano, mes)),
    baixar = function() {
      microdatasus::fetch_datasus(
        year_start = ano, month_start = mes,
        year_end = ano, month_end = mes,
        uf = CONFIG$uf, information_system = "SIH-RD",
        timeout = 1800, stop_on_error = TRUE
      )
    },
    rotulo = sprintf("Baixando SIH-RD %s %04d-%02d", CONFIG$uf, ano, mes)
  )
}

# -----------------------------------------------------------------------------
# 2. Extração dos casos
# -----------------------------------------------------------------------------
# A filtragem usa os dados BRUTOS retornados pelo microdatasus (sem
# process_sih/process_sinasc), que já contêm todas as colunas necessárias:
#   SIH   : MUNIC_RES (6 dígitos), DIAG_PRINC, DIAGSEC1..9, NASC, DT_INTER,
#           COD_IDADE (1..5), IDADE, SEXO, RACA_COR.
#   SINASC: CODMUNRES (6 dígitos), CODANOMAL, DTNASC, IDANOMAL, SEXO, RACACOR.

# --- SIH-RD -------------------------------------------------------------
# Concatena os diagnósticos secundários (DIAGSEC1..9) em uma única string,
# removendo vazios/NA/"0000".
concatenar_diags_secundarios <- function(dados, cols) {
  if (length(cols) == 0L) return(rep("", nrow(dados)))
  m <- as.data.frame(lapply(dados[, cols, drop = FALSE], function(v) {
    v <- as.character(v)
    v[is.na(v) | v %in% c("", "0000")] <- ""
    v
  }), stringsAsFactors = FALSE)
  apply(m, 1, function(r) paste(r[r != ""], collapse = "; "))
}

extrair_casos_sih <- function(raw, regex, codigo_mun6) {
  verificar_colunas(
    raw,
    c("MUNIC_RES", "DIAG_PRINC", "DIAG_SECUN", "NASC", "DT_INTER",
      "COD_IDADE", "IDADE", "ANO_CMPT", "MES_CMPT"),
    "SIH-RD"
  )

  cols_diagsec <- intersect(paste0("DIAGSEC", 1:9), names(raw))

  raw %>%
    dplyr::mutate(
      municipio_res = as.character(MUNIC_RES),
      residente     = substr(municipio_res, 1, 6) == codigo_mun6,
      idade_dias    = calcular_idade_dias(NASC, DT_INTER, COD_IDADE, IDADE),
      menor_1_ano   = !is.na(idade_dias) & idade_dias >= 0 &
                      idade_dias <= CONFIG$criterios$idade_menor_1_ano_max_dias,
      tem_diagnostico = tem_diagnostico_sih(raw, regex),
      diag_secun    = concatenar_diags_secundarios(raw, cols_diagsec)
    ) %>%
    dplyr::filter(residente & menor_1_ano & tem_diagnostico) %>%
    dplyr::mutate(
      dt_inter = parse_data(DT_INTER),
      # A série temporal usa a competência (ANO_CMPT/MES_CMPT), padrão do SIH
      # para definir o período de referência do registro.
      ano      = as.integer(ANO_CMPT),
      mes      = as.integer(MES_CMPT),
      sexo     = as.character(SEXO),
      raca_cor = as.character(RACA_COR),
      diag_princ = as.character(DIAG_PRINC)
    ) %>%
    dplyr::select(ano, mes, dt_inter, idade_dias, sexo, raca_cor,
                  diag_princ, diag_secun, municipio_res)
}

# --- SINASC -------------------------------------------------------------
extrair_casos_sinasc <- function(raw, regex, codigo_mun6) {
  verificar_colunas(raw, c("CODMUNRES", "CODANOMAL", "DTNASC"), "SINASC")

  raw %>%
    dplyr::mutate(
      codmunres  = as.character(CODMUNRES),
      residente  = substr(codmunres, 1, 6) == codigo_mun6,
      codanomal  = as.character(CODANOMAL),
      tem_q      = tem_cid_q(CODANOMAL, regex)
    ) %>%
    dplyr::filter(residente & tem_q) %>%
    dplyr::mutate(
      dt_nasc = parse_data(DTNASC),
      ano     = lubridate::year(dt_nasc),
      mes     = lubridate::month(dt_nasc),
      sexo    = as.character(SEXO),
      raca_cor = as.character(RACACOR)
    ) %>%
    dplyr::select(ano, mes, dt_nasc, sexo, raca_cor, codanomal, codmunres)
}

# --- Totais de nascidos vivos (denominador) -----------------------------
extrair_totais_sinasc <- function(raw, codigo_mun6) {
  verificar_colunas(raw, c("CODMUNRES", "DTNASC"), "SINASC")
  raw %>%
    dplyr::mutate(
      codmunres = as.character(CODMUNRES),
      residente = substr(codmunres, 1, 6) == codigo_mun6,
      dt_nasc   = parse_data(DTNASC)
    ) %>%
    dplyr::filter(residente & !is.na(dt_nasc)) %>%
    dplyr::mutate(
      ano = lubridate::year(dt_nasc),
      mes = lubridate::month(dt_nasc)
    ) %>%
    dplyr::count(ano, mes, name = "n_nascidos") %>%
    dplyr::mutate(mes_ano = as.Date(sprintf("%04d-%02d-01", ano, mes))) %>%
    dplyr::arrange(mes_ano)
}

# -----------------------------------------------------------------------------
# 3. Processamento de um período completo
# -----------------------------------------------------------------------------
# Baixa e extrai todos os desfechos de um período de anos. Retorna uma lista
# com os cinco data frames consolidados:
#   sih_q20q26, sih_q20q28, sin_q20q26, sin_q20q28, sin_totais
processar_desfechos_periodo <- function(anos) {
  sih_q20q26 <- list()
  sih_q20q28 <- list()
  sin_q20q26 <- list()
  sin_q20q28 <- list()
  sin_totais <- list()

  for (ano in anos) {
    cat(sprintf("\n[%d] SINASC\n", ano))
    sin_raw <- baixar_sinasc_ano(ano)
    sin_q20q26[[as.character(ano)]] <- extrair_casos_sinasc(
      sin_raw, CONFIG$criterios$cid_q20_q26_regex, CONFIG$municipio_codigo_6)
    sin_q20q28[[as.character(ano)]] <- extrair_casos_sinasc(
      sin_raw, CONFIG$criterios$cid_q20_q28_regex, CONFIG$municipio_codigo_6)
    sin_totais[[as.character(ano)]] <- extrair_totais_sinasc(
      sin_raw, CONFIG$municipio_codigo_6)
    rm(sin_raw); invisible(gc())

    cat(sprintf("[%d] SIH-RD\n", ano))
    for (mes in CONFIG$meses) {
      sih_raw <- baixar_sih_mes(ano, mes)
      sih_q20q26[[sprintf("%d-%02d", ano, mes)]] <- extrair_casos_sih(
        sih_raw, CONFIG$criterios$cid_q20_q26_regex, CONFIG$municipio_codigo_6)
      sih_q20q28[[sprintf("%d-%02d", ano, mes)]] <- extrair_casos_sih(
        sih_raw, CONFIG$criterios$cid_q20_q28_regex, CONFIG$municipio_codigo_6)
      rm(sih_raw); invisible(gc())
    }
  }

  list(
    sih_q20q26 = dplyr::bind_rows(sih_q20q26) %>% dplyr::arrange(dt_inter),
    sih_q20q28 = dplyr::bind_rows(sih_q20q28) %>% dplyr::arrange(dt_inter),
    sin_q20q26 = dplyr::bind_rows(sin_q20q26) %>% dplyr::arrange(dt_nasc),
    sin_q20q28 = dplyr::bind_rows(sin_q20q28) %>% dplyr::arrange(dt_nasc),
    sin_totais = dplyr::bind_rows(sin_totais) %>% dplyr::arrange(mes_ano)
  )
}
