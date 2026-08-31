# =============================================================================
# 04_process_sih.R
# Pipeline SIH-RD: processamento, cálculo de idade e extração dos casos Q20-Q28
# em menores de 1 ano.
#
# SIH-RD = Sistema de Informações Hospitalares — Reduzida.
# Filtros aplicados:
#   1. Município de residência = Campos dos Goytacazes (MUNIC_RES).
#   2. Diagnóstico principal CID-10 Q20-Q28 (DIAG_PRINC).
#   3. Idade estimada >= 0 e < 365 dias (menores de 1 ano).
#
# Classificação etária (ver docs/METODOLOGIA.md):
#   Neonato  : 0 a 28 dias.
#   Lactente : 29 a 364 dias.
# =============================================================================

# Converte datas do SIH (Date, POSIXct ou texto) para Date.
# Aceita "YYYY-MM-DD", "YYYYMMDD" e "DD/MM/YYYY".
parse_data_sih <- function(x) {
  x <- as.character(x)
  out <- suppressWarnings(lubridate::ymd(x))
  idx <- is.na(out) & stringr::str_detect(x, "^\\d{2}/\\d{2}/\\d{4}$")
  out[idx] <- suppressWarnings(lubridate::dmy(x[idx]))
  out
}

# Converte a idade registrada por código (COD_IDADE/IDADE) em dias.
#
# CORREÇÃO DE BUG: o microdatasus retorna COD_IDADE como RÓTULO
# ("Horas", "Dias", "Meses", "Anos", "Centena de anos (100 + idade)")
# e não como código numérico ("1".."5"). A versão anterior comparava com
# "2"/"3"/"4" e, portanto, o fallback nunca funcionava. Aceitamos ambos os
# formatos (rótulo e código numérico).
idade_dias_por_codigo <- function(cod_idade, idade) {
  cod <- toupper(trimws(as.character(cod_idade)))
  idade_num <- suppressWarnings(as.integer(idade))

  dplyr::case_when(
    cod %in% c("HORAS", "HORA", "1") ~
      as.integer(round(idade_num / 24)),
    cod %in% c("DIAS", "DIA", "2") ~
      idade_num,
    cod %in% c("MESES", "MES", "3") ~
      idade_num * CONFIG$criterios$dias_por_mes,
    cod %in% c("ANOS", "ANO", "4") ~
      idade_num * CONFIG$criterios$dias_por_ano,
    # microdatasus usa o rótulo "Centena de anos (100 + idade)" para o código 5
    # (idade >= 100 anos); o valor em IDADE é somado a 100.
    grepl("CENTENA", cod, ignore.case = TRUE) | cod == "5" ~
      (100L + idade_num) * CONFIG$criterios$dias_por_ano,
    TRUE ~ NA_integer_
  )
}

# Estima a idade em dias, preferindo o cálculo por datas (DT_INTER - NASC).
# Quando as datas são inválidas, usa o fallback por COD_IDADE/IDADE.
calcular_idade_dias <- function(nasc, dt_inter, cod_idade, idade) {
  idade_por_data <- as.integer(parse_data_sih(dt_inter) - parse_data_sih(nasc))
  idade_por_codigo <- idade_dias_por_codigo(cod_idade, idade)

  ifelse(
    !is.na(idade_por_data) & idade_por_data >= 0,
    idade_por_data,
    idade_por_codigo
  )
}

# Classifica a idade em dias nas faixas Neonato / Lactente.
classificar_idade <- function(idade_dias) {
  dplyr::case_when(
    !is.na(idade_dias) & idade_dias >= 0 &
      idade_dias <= CONFIG$criterios$idade_neonato_max_dias ~ "Neonato",
    !is.na(idade_dias) & idade_dias >= CONFIG$criterios$idade_lactente_min_dias &
      idade_dias <= CONFIG$criterios$idade_menor_1_ano_max_dias ~ "Lactente",
    TRUE ~ NA_character_
  )
}

# Lê o cache processado ou processa os dados brutos de um mês do SIH-RD.
carregar_sih_processado <- function(ano, mes) {
  arquivo_processado <- file.path(
    CONFIG$dirs$cache_processado,
    sprintf("SIH_RD_%s_%04d_%02d_processado.rds", CONFIG$uf, ano, mes)
  )

  if (file.exists(arquivo_processado)) {
    return(readRDS(arquivo_processado))
  }

  bruto <- baixar_sih_mes(ano, mes)
  processado <- microdatasus::process_sih(
    bruto,
    information_system = "SIH-RD",
    municipality_data = TRUE
  )
  saveRDS(processado, arquivo_processado)
  processado
}

# Aplica os critérios de inclusão a um mês do SIH-RD.
processar_sih_mes <- function(ano, mes) {
  sih <- carregar_sih_processado(ano, mes)

  verificar_colunas(
    sih,
    c("MUNIC_RES", "DIAG_PRINC", "NASC", "DT_INTER", "COD_IDADE", "IDADE"),
    sprintf("SIH-RD %04d-%02d", ano, mes)
  )

  sih_auditado <- sih %>%
    dplyr::mutate(
      audit_ano_execucao = ano,
      audit_mes_execucao = mes,
      diagnostico_principal_norm = normalizar_cid(DIAG_PRINC),
      idade_dias_estimado = calcular_idade_dias(NASC, DT_INTER, COD_IDADE, IDADE),
      classe_idade = classificar_idade(idade_dias_estimado),
      audit_residente_campos =
        substr(as.character(MUNIC_RES), 1, 6) == CONFIG$municipio_residencia_codigo,
      audit_q20_q28_principal = tem_cid_q20_q28(DIAG_PRINC),
      audit_menor_1_ano =
        !is.na(idade_dias_estimado) & idade_dias_estimado >= 0 &
        idade_dias_estimado <= CONFIG$criterios$idade_menor_1_ano_max_dias
    ) %>%
    dplyr::mutate(
      audit_linha_aprovada =
        audit_residente_campos & audit_q20_q28_principal & audit_menor_1_ano
    )

  dados_filtrados <- dplyr::filter(sih_auditado, audit_linha_aprovada)

  auditoria_mes <- tibble::tibble(
    ano = ano,
    mes = mes,
    n_linhas_processadas = nrow(sih_auditado),
    n_residentes_campos = sum(sih_auditado$audit_residente_campos, na.rm = TRUE),
    n_q20_q28_principal = sum(sih_auditado$audit_q20_q28_principal, na.rm = TRUE),
    n_menor_1_ano = sum(sih_auditado$audit_menor_1_ano, na.rm = TRUE),
    n_final_mes = sum(sih_auditado$audit_linha_aprovada, na.rm = TRUE),
    n_neonato = sum(dados_filtrados$classe_idade == "Neonato", na.rm = TRUE),
    n_lactente = sum(dados_filtrados$classe_idade == "Lactente", na.rm = TRUE),
    data_execucao = as.character(Sys.time())
  )

  list(
    dados = dados_filtrados,
    auditoria = auditoria_mes
  )
}
