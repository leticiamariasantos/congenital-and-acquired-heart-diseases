# =============================================================================
# 02_analise_inferencial.R
# Análise estatística inferencial — cardiopatias congênitas (CID-10 Q20–Q28)
# Campos dos Goytacazes (RJ), 2020–2024.
#
# Etapas:
#   1. Mann-Kendall + Sen's slope (tendência anual de casos SINASC e internações SIH-RD)
#   2. Correlação de Spearman (exposições ambientais x desfechos mensais)
#   3. Modelagem: Poisson, Quasi-Poisson, Binomial Negativa, lags e DLNM
#      (exposições climáticas INMET e PM2.5 do VIGIAR)
#   4. Exportação de tabelas (results/tabelas/*.csv) e figuras (results/figures/*.png)
#   5. Resumo interpretativo no console
#
# Uso (a partir da raiz do repositório):
#   Rscript analysis/02_analise_inferencial.R
#
# Dependências: ver requirements.R (instala automaticamente o que faltar).
# =============================================================================

options(stringsAsFactors = FALSE)
Sys.setenv(TZ = "America/Sao_Paulo")
options(scipen = 999)  # evita notação científica nos CSV/console

# -----------------------------------------------------------------------------
# 1. Carregamento de pacotes e configurações
# -----------------------------------------------------------------------------
# Ordem importa: dplyr/tidyr/ggplot2 são carregados por último para que as
# funções select(), filter(), summarise(), etc. tenham precedência sobre
# conflitos com MASS e Hmisc.
pacotes <- c(
  "MASS", "Hmisc", "Kendall", "trend", "dlnm",            # estatística/modelagem
  "lubridate", "readr", "tidyr", "dplyr", "ggplot2"  # manipulação/visualização
)
faltantes <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltantes) > 0L) {
  cat("Instalando pacotes faltantes:", paste(faltantes, collapse = ", "), "\n")
  install.packages(faltantes)
}
invisible(lapply(pacotes, library, character.only = TRUE))

source("src/00_config.R")
source("src/01_utils.R")
garantir_diretorios()
dir.create(CONFIG$dirs$resultados, recursive = TRUE, showWarnings = FALSE)

# Salva figura em uma pasta específica de modelo (padrão: descritiva)
salvar_figura <- function(plot, nome, dir = CONFIG$dirs$descritiva,
                          largura = 8, altura = 5) {
  ggsave(file.path(dir, nome), plot = plot,
         width = largura, height = altura, dpi = 300)
  invisible(plot)
}

# -----------------------------------------------------------------------------
# 2. Leitura e agregação dos dados SINASC e SIH-RD (nível mensal e anual)
# -----------------------------------------------------------------------------
sinasc <- readRDS(CONFIG$arquivos$sinasc_rds)
sih <- readRDS(CONFIG$arquivos$sih_rds)

# SINASC: data de nascimento (DTNASC) -> ano/mês
sinasc <- sinasc %>%
  dplyr::mutate(
    DTNASC = as.Date(DTNASC),
    ano = as.integer(format(DTNASC, "%Y")),
    mes = as.integer(format(DTNASC, "%m")),
    mes_ano = as.Date(sprintf("%04d-%02d-01", ano, mes))
  )

# SIH-RD: competência (ANO_CMPT/MES_CMPT) = mês de processamento da AIH
sih <- sih %>%
  dplyr::mutate(
    ANO_CMPT = as.integer(ANO_CMPT),
    MES_CMPT = as.integer(MES_CMPT),
    ano = ANO_CMPT,
    mes = MES_CMPT,
    mes_ano = as.Date(sprintf("%04d-%02d-01", ano, mes))
  )

# Grade mensal completa (2020-01 até 2024-12), para preencher meses sem casos
grade_mensal <- data.frame(
  mes_ano = seq(as.Date("2020-01-01"), as.Date("2024-12-01"), by = "month")
) %>%
  dplyr::mutate(ano = lubridate::year(mes_ano), mes = lubridate::month(mes_ano))

# Agregação mensal — casos SINASC (nascidos vivos com Q20–Q28)
sinasc_mes <- sinasc %>%
  dplyr::count(mes_ano, name = "casos_sinasc") %>%
  dplyr::right_join(grade_mensal, by = "mes_ano") %>%
  tidyr::replace_na(list(casos_sinasc = 0L)) %>%
  dplyr::arrange(mes_ano)

# Agregação mensal — internações SIH-RD (menores de 1 ano com Q20–Q28)
sih_mes <- sih %>%
  dplyr::count(mes_ano, name = "internacoes_sih") %>%
  dplyr::right_join(grade_mensal, by = "mes_ano") %>%
  tidyr::replace_na(list(internacoes_sih = 0L)) %>%
  dplyr::arrange(mes_ano)

# Agregação anual (para o Mann-Kendall)
sinasc_ano <- sinasc %>%
  dplyr::count(ano, name = "casos_sinasc") %>%
  dplyr::right_join(data.frame(ano = CONFIG$anos), by = "ano") %>%
  tidyr::replace_na(list(casos_sinasc = 0L)) %>%
  dplyr::arrange(ano)

sih_ano <- sih %>%
  dplyr::count(ano, name = "internacoes_sih") %>%
  dplyr::right_join(data.frame(ano = CONFIG$anos), by = "ano") %>%
  tidyr::replace_na(list(internacoes_sih = 0L)) %>%
  dplyr::arrange(ano)

# -----------------------------------------------------------------------------
# 3. Leitura e agregação dos dados climáticos INMET (nível mensal)
# -----------------------------------------------------------------------------
# Os arquivos INMET têm 8 linhas de metadados; o cabeçalho fica na linha 9.
# O separador é vírgula e os decimais vêm entre aspas com vírgula (ex.: "25,1").
# As colunas são renomeadas por posição para nomes ASCII estáveis.
ler_inmet <- function(caminho) {
  d <- read.csv(caminho, skip = 8, fileEncoding = "UTF-8",
                stringsAsFactors = FALSE, check.names = FALSE,
                na.strings = c("", "NA", "-9999"))
  names(d) <- c(
    "data", "hora_utc", "precip_mm", "pressao_mb", "pressao_max_mb",
    "pressao_min_mb", "radiacao_kjm2", "temp_c", "temp_orvalho_c",
    "temp_max_c", "temp_min_c", "temp_orvalho_max_c", "temp_orvalho_min_c",
    "umid_max_pct", "umid_min_pct", "umid_pct", "vento_dir_gr",
    "vento_rajada_ms", "vento_vel_ms"
  )

  # Converte "vírgula decimal" para ponto e trata ausentes de forma explícita
  num_br <- function(x) {
    x <- as.character(x)
    x <- trimws(x)
    x[x %in% c("", "NA", "-9999", "null", "NULL")] <- NA_character_
    suppressWarnings(as.numeric(sub(",", ".", x, fixed = TRUE)))
  }

  d <- d %>%
    dplyr::mutate(
      data = as.Date(data, format = "%Y/%m/%d"),
      dplyr::across(
        c(precip_mm, pressao_mb, pressao_max_mb, pressao_min_mb,
          radiacao_kjm2, temp_c, temp_orvalho_c, temp_max_c, temp_min_c,
          temp_orvalho_max_c, temp_orvalho_min_c, umid_max_pct, umid_min_pct,
          umid_pct, vento_dir_gr, vento_rajada_ms, vento_vel_ms),
        num_br
      )
    )
  d
}

clima_bruto <- dplyr::bind_rows(lapply(CONFIG$anos, function(a) {
  caminho <- file.path("data/raw/inmet",
                       sprintf("inmet_campos_goytacazes_%d.csv", a))
  if (!file.exists(caminho)) {
    warning("Arquivo INMET ausente: ", caminho)
    return(NULL)
  }
  ler_inmet(caminho)
}))

# Agregação mensal das variáveis climáticas de interesse:
#   - temperatura média mensal  (média horária do bulbo seco)
#   - precipitação total mensal (soma horária)
#   - umidade relativa média    (média horária)
# Valores ausentes são removidos explicitamente (na.rm = TRUE); n_horas registra
# a cobertura horária de cada mês para fins de auditoria.
clima_mensal <- clima_bruto %>%
  dplyr::mutate(
    ano = lubridate::year(data),
    mes = lubridate::month(data),
    mes_ano = as.Date(sprintf("%04d-%02d-01", ano, mes))
  ) %>%
  dplyr::group_by(mes_ano, ano, mes) %>%
  dplyr::summarise(
    temp_media_c   = mean(temp_c, na.rm = TRUE),
    precip_total_mm = sum(precip_mm, na.rm = TRUE),
    umid_media_pct = mean(umid_pct, na.rm = TRUE),
    n_horas        = sum(!is.na(temp_c)),
    .groups = "drop"
  ) %>%
  dplyr::arrange(mes_ano)

# -----------------------------------------------------------------------------
# 4. Denominador (offset): total de nascidos vivos no município por mês
# -----------------------------------------------------------------------------
# O offset de exposição ideal é o total de nascidos vivos de Campos dos
# Goytacazes. Como os dados processados contêm apenas os casos Q20–Q28,
# reconstruímos o denominador a partir do cache SINASC completo do RJ
# (data/cache/processed). Se o cache não estiver disponível, seguimos sem
# offset (modelo de contagens simples), com aviso explícito.
nascimentos_totais <- tryCatch({
  dplyr::bind_rows(lapply(CONFIG$anos, function(a) {
    caminho <- file.path(CONFIG$dirs$cache_processado,
                         sprintf("SINASC_RJ_%d_processado.rds", a))
    if (!file.exists(caminho)) {
      stop("Cache SINASC ausente: ", caminho)
    }
    x <- readRDS(caminho)
    verificar_colunas(x, c("CODMUNRES", "DTNASC"), "cache SINASC")
    x <- x[x$CODMUNRES == CONFIG$municipio_residencia_codigo, "DTNASC", drop = FALSE]
    x <- x %>%
      dplyr::mutate(dt = as.Date(DTNASC)) %>%
      dplyr::filter(!is.na(dt)) %>%
      dplyr::mutate(
        ano = lubridate::year(dt),
        mes = lubridate::month(dt),
        mes_ano = as.Date(sprintf("%04d-%02d-01", ano, mes))
      ) %>%
      dplyr::count(mes_ano, name = "nasc_tot")
    x
  }))
}, error = function(e) {
  warning("Não foi possível montar o denominador de nascidos vivos: ",
          conditionMessage(e), "\nSeguiremos SEM offset nos modelos.")
  NULL
})

usar_offset <- !is.null(nascimentos_totais)

if (usar_offset) {
  nascimentos_totais <- grade_mensal %>%
    dplyr::left_join(nascimentos_totais, by = "mes_ano") %>%
    tidyr::replace_na(list(nasc_tot = 0L))
  # Meses sem nenhum nascimento registrado (suspeita de dado ausente) -> NA
  nascimentos_totais$nasc_tot[nascimentos_totais$nasc_tot == 0L] <- NA_real_
}

# -----------------------------------------------------------------------------
# 5. Junção das bases (chave: ano-mês)
# -----------------------------------------------------------------------------
# PM2.5 mensal (VIGIAR) — processado em data/processed/pm25_campos_2020_2024.rds
pm25_mensal <- readRDS(file.path(CONFIG$dirs$dados, "pm25_campos_2020_2024.rds"))

dados_mensais <- grade_mensal %>%
  dplyr::left_join(sinasc_mes %>% dplyr::select(mes_ano, casos_sinasc),
                   by = "mes_ano") %>%
  dplyr::left_join(sih_mes %>% dplyr::select(mes_ano, internacoes_sih),
                   by = "mes_ano") %>%
  dplyr::left_join(clima_mensal %>% dplyr::select(mes_ano, temp_media_c,
                                                  precip_total_mm, umid_media_pct,
                                                  n_horas),
                   by = "mes_ano") %>%
  dplyr::left_join(pm25_mensal %>% dplyr::select(mes_ano, pm25),
                   by = "mes_ano")

if (usar_offset) {
  dados_mensais <- dados_mensais %>%
    dplyr::left_join(nascimentos_totais %>% dplyr::select(mes_ano, nasc_tot),
                     by = "mes_ano")
} else {
  dados_mensais$nasc_tot <- NA_real_
}

dados_mensais <- dados_mensais %>%
  dplyr::arrange(mes_ano) %>%
  dplyr::mutate(
    casos_sinasc    = tidyr::replace_na(casos_sinasc, 0L),
    internacoes_sih = tidyr::replace_na(internacoes_sih, 0L)
  )

# -----------------------------------------------------------------------------
# 6. Mann-Kendall + Sen's slope (tendência anual)
# -----------------------------------------------------------------------------
# tau de Kendall (com correção para empates), p-valor bilateral e inclinação
# de Sen (mediana das inclinações par-a-par) com IC 95%.
resumo_mk <- function(x, nome) {
  x <- x[!is.na(x)]
  n <- length(x)

  if (n < 3L || length(unique(x)) < 2L) {
    return(data.frame(
      serie = nome, n = n, tau = NA_real_, p_valor = NA_real_,
      sen_slope = NA_real_, sen_ic95_inf = NA_real_, sen_ic95_sup = NA_real_,
      interpretacao = "série insuficiente para teste de tendência",
      stringsAsFactors = FALSE
    ))
  }

  mk <- Kendall::MannKendall(x)
  ss <- tryCatch(trend::sens.slope(x, conf.level = 0.95),
                 error = function(e) NULL)

  sen <- if (is.null(ss)) NA_real_ else as.numeric(ss$estimates["Sen's slope"])
  lci <- if (is.null(ss) || is.null(ss$conf.int)) NA_real_ else ss$conf.int[1]
  uci <- if (is.null(ss) || is.null(ss$conf.int)) NA_real_ else ss$conf.int[2]

  tau <- as.numeric(mk$tau)
  p <- as.numeric(mk$sl)

  direcao <- if (is.na(tau)) "indefinida"
             else if (tau > 0) "aumento"
             else if (tau < 0) "redução"
             else "sem tendência"
  sig <- if (is.na(p)) "indefinida"
         else if (p < 0.05) "estatisticamente significativa"
         else "não significativa"

  data.frame(
    serie = nome, n = n, tau = tau, p_valor = p,
    sen_slope = sen, sen_ic95_inf = lci, sen_ic95_sup = uci,
    interpretacao = paste("tendência de", direcao, "—", sig),
    stringsAsFactors = FALSE
  )
}

resumo_mann_kendall <- dplyr::bind_rows(
  resumo_mk(sinasc_ano$casos_sinasc, "SINASC — nascidos vivos Q20-Q28 (anual)"),
  resumo_mk(sih_ano$internacoes_sih, "SIH-RD — internações Q20-Q28 <1 ano (anual)")
)

# -----------------------------------------------------------------------------
# 7. Correlação de Spearman (exposições ambientais x desfechos mensais)
# -----------------------------------------------------------------------------
nomes_variaveis <- c(
  casos_sinasc    = "Casos SINASC (Q20-Q28)",
  internacoes_sih = "Internações SIH-RD (<1 ano)",
  temp_media_c    = "Temperatura média (°C)",
  precip_total_mm = "Precipitação total (mm)",
  umid_media_pct  = "Umidade relativa (%)",
  pm25            = "PM2.5 (µg/m³)"
)

vars_corr <- c("casos_sinasc", "internacoes_sih",
               "temp_media_c", "precip_total_mm", "umid_media_pct", "pm25")

matriz_dados <- as.matrix(dados_mensais[, vars_corr])
colnames(matriz_dados) <- nomes_variaveis[vars_corr]

# Hmisc::rcorr calcula rho de Spearman + p-valores (pairwise complete)
rc <- Hmisc::rcorr(matriz_dados, type = "spearman")
matriz_rho <- rc$r
matriz_p <- rc$P
matriz_n <- rc$n

# Tabela longa (triângulo superior da matriz)
indices <- which(upper.tri(matriz_rho), arr.ind = TRUE)
resumo_spearman <- data.frame(
  variavel_1 = rownames(matriz_rho)[indices[, 1]],
  variavel_2 = colnames(matriz_rho)[indices[, 2]],
  rho = matriz_rho[indices],
  p_valor = matriz_p[indices],
  n = matriz_n[indices],
  stringsAsFactors = FALSE
) %>%
  dplyr::mutate(significativo = ifelse(p_valor < 0.05, "Sim", "Não")) %>%
  dplyr::arrange(dplyr::desc(abs(rho)))

# -----------------------------------------------------------------------------
# 7b. Spearman sobre as TAXAS mensais (por 10.000 nascidos vivos)
# -----------------------------------------------------------------------------
# A metodologia especifica as TAXAS mensais (por 10.000 NV). Repetimos a
# correlação usando as taxas = casos / nascidos vivos do mês × 10.000.
if (usar_offset) {
  dados_mensais <- dados_mensais %>%
    dplyr::mutate(
      taxa_sinasc = casos_sinasc / nasc_tot * 1e4,
      taxa_sih    = internacoes_sih / nasc_tot * 1e4
    )

  nomes_taxas <- c(
    taxa_sinasc     = "Taxa SINASC (por 10.000 NV)",
    taxa_sih        = "Taxa SIH-RD (por 10.000 NV)",
    temp_media_c    = "Temperatura média (°C)",
    precip_total_mm = "Precipitação total (mm)",
    umid_media_pct  = "Umidade relativa (%)",
    pm25            = "PM2.5 (µg/m³)"
  )
  vars_corr_taxas <- names(nomes_taxas)
  m_taxas <- as.matrix(dados_mensais[, vars_corr_taxas])
  colnames(m_taxas) <- nomes_taxas[vars_corr_taxas]

  rc_taxas <- Hmisc::rcorr(m_taxas, type = "spearman")
  matriz_rho_taxas <- rc_taxas$r
  matriz_p_taxas   <- rc_taxas$P
  matriz_n_taxas   <- rc_taxas$n

  idx_taxas <- which(upper.tri(matriz_rho_taxas), arr.ind = TRUE)
  resumo_spearman_taxas <- data.frame(
    variavel_1 = rownames(matriz_rho_taxas)[idx_taxas[, 1]],
    variavel_2 = colnames(matriz_rho_taxas)[idx_taxas[, 2]],
    rho = matriz_rho_taxas[idx_taxas],
    p_valor = matriz_p_taxas[idx_taxas],
    n = matriz_n_taxas[idx_taxas],
    stringsAsFactors = FALSE
  ) %>%
    dplyr::mutate(significativo = ifelse(p_valor < 0.05, "Sim", "Não")) %>%
    dplyr::arrange(dplyr::desc(abs(rho)))
} else {
  resumo_spearman_taxas <- NULL
  matriz_rho_taxas <- NULL
  matriz_p_taxas <- NULL
}

# -----------------------------------------------------------------------------
# 8. Modelagem estatística
# -----------------------------------------------------------------------------
# 8.1 Exposição ambiental defasada (lags)
#     Para o SINASC (nascidos vivos), a exposição relevante é a janela de
#     1–3 meses antes do parto (período da cardiogênese, conforme definido no
#     estudo) — inclui variáveis climáticas e PM2.5. Para o SIH-RD (internação),
#     a exposição é contemporânea (lag 0).
# -----------------------------------------------------------------------------
dados_mensais <- dados_mensais %>%
  dplyr::arrange(mes_ano) %>%
  dplyr::mutate(
    temp_lag1   = dplyr::lag(temp_media_c, 1L),
    temp_lag2   = dplyr::lag(temp_media_c, 2L),
    temp_lag3   = dplyr::lag(temp_media_c, 3L),
    precip_lag1 = dplyr::lag(precip_total_mm, 1L),
    precip_lag2 = dplyr::lag(precip_total_mm, 2L),
    precip_lag3 = dplyr::lag(precip_total_mm, 3L),
    umid_lag1   = dplyr::lag(umid_media_pct, 1L),
    umid_lag2   = dplyr::lag(umid_media_pct, 2L),
    umid_lag3   = dplyr::lag(umid_media_pct, 3L),
    pm25_lag1   = dplyr::lag(pm25, 1L),
    pm25_lag2   = dplyr::lag(pm25, 2L),
    pm25_lag3   = dplyr::lag(pm25, 3L)
  )

offset_log <- if (usar_offset) "log(nasc_tot)" else NULL

# -----------------------------------------------------------------------------
# 8.2 Poisson, Quasi-Poisson e Binomial Negativa (exposição contemporânea)
# -----------------------------------------------------------------------------
preditores <- c("temp_media_c", "precip_total_mm", "umid_media_pct", "pm25")

tabela_modelo <- function(modelo, nome_modelo, nome_desfecho, n,
                          dispersao = NA_real_, aic = NA_real_,
                          theta_nb = NA_real_) {
  s <- summary(modelo)$coefficients
  ci <- tryCatch(stats::confint(modelo),
                 error = function(e) stats::confint.default(modelo))
  data.frame(
    desfecho = nome_desfecho,
    modelo = nome_modelo,
    n_observacoes = n,
    dispersao = dispersao,
    aic = aic,
    theta_nb = theta_nb,
    termo = rownames(s),
    estimativa = s[, 1],
    erro_padrao = s[, 2],
    irr = exp(s[, 1]),
    ic95_inf = exp(ci[, 1]),
    ic95_sup = exp(ci[, 2]),
    p_valor = s[, ncol(s)],
    stringsAsFactors = FALSE
  )
}

modelos_contagem <- function(dados, desfecho, preditores,
                             offset_log = NULL, nome_desfecho = desfecho) {
  vars <- c(desfecho, preditores)
  if (!is.null(offset_log)) {
    vars <- c(vars, sub("^log\\((.*)\\)$", "\\1", offset_log))
  }
  d <- dados[stats::complete.cases(dados[, vars, drop = FALSE]), , drop = FALSE]

  formula_str <- paste(desfecho, "~", paste(preditores, collapse = " + "))
  if (!is.null(offset_log)) {
    formula_str <- paste(formula_str, "+ offset(", offset_log, ")")
  }
  f <- stats::as.formula(formula_str)

  # Poisson (base)
  m_pois <- stats::glm(f, family = stats::poisson, data = d)
  pearson_chi2 <- sum(stats::residuals(m_pois, type = "pearson")^2)
  disp_pois <- pearson_chi2 / stats::df.residual(m_pois)

  # Quasi-Poisson
  m_qp <- stats::glm(f, family = stats::quasipoisson, data = d)
  disp_qp <- summary(m_qp)$dispersion

  # Binomial Negativa (silencia avisos de "iteration limit" quando theta -> Inf,
  # situação esperada quando os dados são equidispersos)
  m_nb <- suppressWarnings(tryCatch(MASS::glm.nb(f, data = d),
                                    error = function(e) NULL))

  tabela <- dplyr::bind_rows(
    tabela_modelo(m_pois, "Poisson", nome_desfecho, nrow(d),
                  disp_pois, stats::AIC(m_pois), NA_real_),
    tabela_modelo(m_qp, "Quasi-Poisson", nome_desfecho, nrow(d),
                  disp_qp, NA_real_, NA_real_),
    if (!is.null(m_nb)) {
      tabela_modelo(m_nb, "Binomial Negativa", nome_desfecho, nrow(d),
                    NA_real_, stats::AIC(m_nb), as.numeric(m_nb$theta))
    } else {
      NULL
    }
  )
  rownames(tabela) <- NULL

  list(
    tabela = tabela,
    poisson = m_pois,
    quasipoisson = m_qp,
    nb = m_nb,
    dispersao_poisson = disp_pois,
    n = nrow(d)
  )
}

mod_sinasc <- modelos_contagem(dados_mensais, "casos_sinasc", preditores,
                               offset_log = offset_log,
                               nome_desfecho = "SINASC (casos mensais Q20-Q28)")
mod_sih <- modelos_contagem(dados_mensais, "internacoes_sih", preditores,
                            offset_log = offset_log,
                            nome_desfecho = "SIH-RD (internações mensais Q20-Q28)")

resumo_poisson <- dplyr::bind_rows(mod_sinasc$tabela, mod_sih$tabela)

# -----------------------------------------------------------------------------
# 8.3 Poisson com lags climáticos (1–3 meses) — SINASC
# -----------------------------------------------------------------------------
# A cardiogênese ocorre no início da gestação; aqui, conforme definido no
# estudo, avaliamos a exposição ambiental (clima + PM2.5) 1–3 meses antes do
# nascimento.
preditores_lag_sinasc <- c(
  "temp_lag1", "temp_lag2", "temp_lag3",
  "precip_lag1", "precip_lag2", "precip_lag3",
  "umid_lag1", "umid_lag2", "umid_lag3",
  "pm25_lag1", "pm25_lag2", "pm25_lag3"
)

ajustar_poisson <- function(dados, desfecho, preditores, offset_log,
                            nome_desfecho, rotulo_modelo) {
  vars <- c(desfecho, preditores)
  if (!is.null(offset_log)) {
    vars <- c(vars, sub("^log\\((.*)\\)$", "\\1", offset_log))
  }
  d <- dados[stats::complete.cases(dados[, vars, drop = FALSE]), , drop = FALSE]
  formula_str <- paste(desfecho, "~", paste(preditores, collapse = " + "))
  if (!is.null(offset_log)) {
    formula_str <- paste(formula_str, "+ offset(", offset_log, ")")
  }
  m <- stats::glm(stats::as.formula(formula_str),
                  family = stats::poisson, data = d)
  pearson_chi2 <- sum(stats::residuals(m, type = "pearson")^2)
  disp <- pearson_chi2 / stats::df.residual(m)
  tabela_modelo(m, rotulo_modelo, nome_desfecho, nrow(d),
                disp, stats::AIC(m), NA_real_)
}

resumo_poisson_lags <- ajustar_poisson(
  dados_mensais, "casos_sinasc", preditores_lag_sinasc, offset_log,
  "SINASC (casos mensais Q20-Q28)", "Poisson (lags 1-3 meses)"
)

# -----------------------------------------------------------------------------
# 8.4 DLNM (distributed lag non-linear models) — temperatura
# -----------------------------------------------------------------------------
# Modelo de defasagem distribuída não linear para a temperatura, ajustado com
# Quasi-Poisson + offset e ajustado por precipitação, umidade e PM2.5 (linear).
# SINASC: lag 1–3 meses (cardiogênese); SIH-RD: lag 0–3 meses (aguda/subaguda).
ajustar_dlnm <- function(dados, desfecho, lag, offset_log, nome_desfecho) {
  vars <- c(desfecho, "temp_media_c", "precip_total_mm", "umid_media_pct", "pm25")
  if (!is.null(offset_log)) {
    vars <- c(vars, sub("^log\\((.*)\\)$", "\\1", offset_log))
  }
  d <- dados[stats::complete.cases(dados[, vars, drop = FALSE]), , drop = FALSE]

  cb <- dlnm::crossbasis(
    d$temp_media_c,
    lag = lag,
    argvar = list(fun = "ns", df = 2),
    arglag = list(fun = "integer")
  )

  formula_str <- paste(desfecho, "~ cb + precip_total_mm + umid_media_pct + pm25")
  if (!is.null(offset_log)) {
    formula_str <- paste(formula_str, "+ offset(", offset_log, ")")
  }
  m <- stats::glm(stats::as.formula(formula_str),
                  family = stats::quasipoisson, data = d)

  at <- seq(floor(min(d$temp_media_c)), ceiling(max(d$temp_media_c)), by = 1)
  cen <- stats::median(d$temp_media_c)
  cp <- dlnm::crosspred(cb, m, at = at, cen = cen)

  z <- cp$allfit / cp$allse
  p <- 2 * stats::pnorm(-abs(z))
  p[cp$allse == 0] <- NA_real_

  data.frame(
    desfecho = nome_desfecho,
    lag = paste(lag, collapse = "-"),
    temperatura_c = cp$predvar,
    temperatura_referencia_c = cen,
    rr = cp$allRRfit,
    ic95_inf = cp$allRRlow,
    ic95_sup = cp$allRRhigh,
    p_valor = p,
    stringsAsFactors = FALSE
  )
}

resumo_dlnm <- dplyr::bind_rows(
  ajustar_dlnm(dados_mensais, "casos_sinasc", c(1, 3), offset_log,
               "SINASC (casos mensais Q20-Q28)"),
  ajustar_dlnm(dados_mensais, "internacoes_sih", c(0, 3), offset_log,
               "SIH-RD (internações mensais Q20-Q28)")
)

# -----------------------------------------------------------------------------
# 9. Exportação de tabelas (CSV)
# -----------------------------------------------------------------------------
escrever_csv <- function(tab, nome, dir = CONFIG$dirs$descritiva) {
  readr::write_csv(tab, file.path(dir, nome), na = "")
  invisible(tab)
}

# --- Tendência: Mann-Kendall / Sen's slope ---
escrever_csv(resumo_mann_kendall, "resumo_mann_kendall.csv", CONFIG$dirs$mann_kendall)

# --- Correlação: Spearman ---
escrever_csv(resumo_spearman, "resumo_spearman.csv", CONFIG$dirs$spearman)

# --- Correlação: Spearman sobre as taxas por 10.000 nascidos vivos ---
if (!is.null(resumo_spearman_taxas)) {
  escrever_csv(resumo_spearman_taxas, "resumo_spearman_taxas.csv", CONFIG$dirs$spearman)
  matriz_rho_taxas_df <- data.frame(variavel = rownames(matriz_rho_taxas),
                                    matriz_rho_taxas, check.names = FALSE,
                                    stringsAsFactors = FALSE)
  matriz_p_taxas_df <- data.frame(variavel = rownames(matriz_p_taxas),
                                  matriz_p_taxas, check.names = FALSE,
                                  stringsAsFactors = FALSE)
  escrever_csv(matriz_rho_taxas_df, "matriz_spearman_taxas_rho.csv", CONFIG$dirs$spearman)
  escrever_csv(matriz_p_taxas_df, "matriz_spearman_taxas_p.csv", CONFIG$dirs$spearman)
}

# --- Regressão: Poisson, Quasi-Poisson e Binomial Negativa ---
# Tabela combinada + uma tabela por modelo (cada qual em sua pasta)
escrever_csv(resumo_poisson, "resumo_familias_contagem.csv", CONFIG$dirs$poisson)
escrever_csv(dplyr::filter(resumo_poisson, modelo == "Poisson"),
             "resumo_poisson.csv", CONFIG$dirs$poisson)
escrever_csv(dplyr::filter(resumo_poisson, modelo == "Quasi-Poisson"),
             "resumo_quasi_poisson.csv", CONFIG$dirs$quasi_poisson)
escrever_csv(dplyr::filter(resumo_poisson, modelo == "Binomial Negativa"),
             "resumo_binomial_negativa.csv", CONFIG$dirs$binomial_negativa)

# --- Regressão: Poisson com defasagens (lags 1-3 meses) ---
escrever_csv(resumo_poisson_lags, "resumo_poisson_lags.csv", CONFIG$dirs$poisson_lags)

# --- DLNM ---
escrever_csv(resumo_dlnm, "resumo_dlnm.csv", CONFIG$dirs$dlnm)

# Matrizes de correlação (rho e p-valores) em formato largo
matriz_rho_df <- data.frame(variavel = rownames(matriz_rho),
                            matriz_rho, check.names = FALSE,
                            stringsAsFactors = FALSE)
matriz_p_df <- data.frame(variavel = rownames(matriz_p),
                          matriz_p, check.names = FALSE,
                          stringsAsFactors = FALSE)
escrever_csv(matriz_rho_df, "matriz_spearman_rho.csv", CONFIG$dirs$spearman)
escrever_csv(matriz_p_df, "matriz_spearman_p.csv", CONFIG$dirs$spearman)

# -----------------------------------------------------------------------------
# 10. Figuras
# -----------------------------------------------------------------------------
# 10.1 Série temporal mensal dos desfechos
dados_longo_desfechos <- dados_mensais %>%
  dplyr::select(mes_ano, casos_sinasc, internacoes_sih) %>%
  tidyr::pivot_longer(-mes_ano, names_to = "desfecho", values_to = "n") %>%
  dplyr::mutate(desfecho = nomes_variaveis[desfecho])

fig_desfechos <- ggplot(dados_longo_desfechos, aes(x = mes_ano, y = n, color = desfecho)) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1.8) +
  scale_color_viridis_d(end = 0.85) +
  labs(
    title = "Desfechos mensais — cardiopatias congênitas (Q20–Q28)",
    subtitle = "Campos dos Goytacazes (RJ), 2020–2024",
    x = "Ano", y = "Número mensal de casos", color = "Desfecho"
  ) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y",
               expand = expansion(mult = c(0.02, 0.02))) +
  theme_cellpress() +
  theme(legend.position = "bottom")

salvar_figura(fig_desfechos, "fig_serie_temporal_desfechos.png",
              dir = CONFIG$dirs$descritiva, largura = 9, altura = 5)

# 10.2 Séries climáticas mensais (uma variável por painel, unidades distintas)
dados_longo_clima <- dados_mensais %>%
  dplyr::select(mes_ano, temp_media_c, precip_total_mm, umid_media_pct) %>%
  tidyr::pivot_longer(-mes_ano, names_to = "variavel", values_to = "valor") %>%
  dplyr::mutate(variavel = factor(
    nomes_variaveis[variavel],
    levels = nomes_variaveis[c("temp_media_c", "precip_total_mm", "umid_media_pct")],
    labels = paste0(LETTERS[1:3], "   ",
                    nomes_variaveis[c("temp_media_c", "precip_total_mm",
                                      "umid_media_pct")])))

fig_clima <- ggplot(dados_longo_clima, aes(x = mes_ano, y = valor)) +
  geom_line(color = cor_destaque, linewidth = 0.7) +
  facet_wrap(~ variavel, ncol = 1, scales = "free_y") +
  labs(
    title = "Variáveis climáticas mensais — INMET A607 (Campos dos Goytacazes)",
    subtitle = "2020–2024",
    x = "Ano", y = NULL
  ) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y",
               expand = expansion(mult = c(0.02, 0.02))) +
  theme_cellpress()

salvar_figura(fig_clima, "fig_serie_temporal_clima.png",
              dir = CONFIG$dirs$descritiva, largura = 9, altura = 8)

# 10.3 Séries padronizadas (z-score) para comparar desfechos e clima na mesma escala
dados_z <- dados_mensais %>%
  dplyr::select(mes_ano, all_of(vars_corr)) %>%
  dplyr::mutate(dplyr::across(-mes_ano, ~ as.numeric(scale(.)))) %>%
  tidyr::pivot_longer(-mes_ano, names_to = "variavel", values_to = "z") %>%
  dplyr::mutate(variavel = factor(nomes_variaveis[variavel],
                                  levels = nomes_variaveis[vars_corr]))

fig_z <- ggplot(dados_z, aes(x = mes_ano, y = z, color = variavel)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey70") +
  geom_line(linewidth = 0.7) +
  scale_color_viridis_d(end = 0.85) +
  labs(
    title = "Séries mensais padronizadas (z-score)",
    subtitle = "Desfechos e exposições ambientais — Campos dos Goytacazes (RJ), 2020–2024",
    x = "Ano", y = "Escore z", color = NULL
  ) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y",
               expand = expansion(mult = c(0.02, 0.02))) +
  theme_cellpress() +
  theme(legend.position = "bottom")

salvar_figura(fig_z, "fig_series_temporais_normalizadas.png",
              dir = CONFIG$dirs$descritiva, largura = 9, altura = 5)

# 10.4 Heatmap da matriz de Spearman (rho + destaque de p < 0,05)
# Usamos ggplot2 (geom_tile) para a figura, de modo a manter total controle e
# reprodutibilidade; os p-valores vêm de Hmisc::rcorr. Asteriscos marcam p<0,05.
dados_heat <- as.data.frame(as.table(matriz_rho), stringsAsFactors = FALSE)
names(dados_heat) <- c("variavel_1", "variavel_2", "rho")
dados_heat$p_valor <- as.data.frame(as.table(matriz_p), stringsAsFactors = FALSE)$Freq
dados_heat <- dados_heat %>%
  dplyr::mutate(rotulo = sprintf("%.2f%s", rho,
                                ifelse(!is.na(p_valor) & p_valor < 0.05, "*", "")))

fig_corr <- ggplot(dados_heat, aes(x = variavel_1, y = variavel_2, fill = rho)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = rotulo), size = 2.8, color = "grey10") +
  scale_fill_viridis_c(limits = c(-1, 1)) +
  coord_equal() +
  labs(
    title = "Matriz de correlação de Spearman",
    subtitle = "rho entre desfechos (Q20–Q28) e exposições ambientais — * p < 0,05",
    x = NULL, y = NULL, fill = "rho"
  ) +
  theme_cellpress() +
  theme(axis.line = element_blank(),
        axis.ticks = element_blank(),
        axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "right")

salvar_figura(fig_corr, "fig_matriz_correlacao_spearman.png",
              dir = CONFIG$dirs$spearman, largura = 8, altura = 7)

# 10.4b Heatmap da matriz de Spearman sobre as TAXAS mensais (por 10.000 NV)
if (!is.null(matriz_rho_taxas)) {
  dados_heat_taxas <- as.data.frame(as.table(matriz_rho_taxas), stringsAsFactors = FALSE)
  names(dados_heat_taxas) <- c("variavel_1", "variavel_2", "rho")
  dados_heat_taxas$p_valor <- as.data.frame(as.table(matriz_p_taxas),
                                            stringsAsFactors = FALSE)$Freq
  dados_heat_taxas <- dados_heat_taxas %>%
    dplyr::mutate(rotulo = sprintf("%.2f%s", rho,
                                  ifelse(!is.na(p_valor) & p_valor < 0.05, "*", "")))

  fig_corr_taxas <- ggplot(dados_heat_taxas, aes(x = variavel_1, y = variavel_2, fill = rho)) +
    geom_tile(color = "white", linewidth = 0.5) +
    geom_text(aes(label = rotulo), size = 2.8, color = "grey10") +
    scale_fill_viridis_c(limits = c(-1, 1)) +
    coord_equal() +
    labs(title = "Matriz de correlação de Spearman — taxas por 10.000 NV",
         subtitle = "rho entre as taxas mensais e as exposições ambientais — * p < 0,05",
         x = NULL, y = NULL, fill = "rho") +
    theme_cellpress() +
    theme(axis.line = element_blank(),
          axis.ticks = element_blank(),
          axis.text.x = element_text(angle = 45, hjust = 1),
          legend.position = "right")
  salvar_figura(fig_corr_taxas, "fig_matriz_correlacao_spearman_taxas.png",
                dir = CONFIG$dirs$spearman, largura = 8, altura = 7)
}

# 10.5 Dispersão: cada exposição ambiental x cada desfecho (com rho e p-valor)
nomes_desfecho <- nomes_variaveis[c("casos_sinasc", "internacoes_sih")]
nomes_clima <- nomes_variaveis[c("temp_media_c", "precip_total_mm", "umid_media_pct", "pm25")]

pares_dispersao <- expand.grid(desfecho = names(nomes_desfecho),
                               clima = names(nomes_clima),
                               stringsAsFactors = FALSE)

dados_dispersao <- dplyr::bind_rows(lapply(seq_len(nrow(pares_dispersao)), function(i) {
  dx <- pares_dispersao$desfecho[i]
  dy <- pares_dispersao$clima[i]
  ct <- stats::cor.test(dados_mensais[[dx]], dados_mensais[[dy]],
                        method = "spearman", exact = FALSE)
  data.frame(
    desfecho = dx,
    clima = dy,
    x = dados_mensais[[dy]],
    y = dados_mensais[[dx]],
    rotulo = sprintf("rho = %.2f\np = %.3f",
                     as.numeric(ct$estimate), ct$p.value),
    stringsAsFactors = FALSE
  )
}))

fig_dispersao <- ggplot(dados_dispersao, aes(x = x, y = y)) +
  geom_point(color = cor_destaque, size = 1.8, alpha = 0.85) +
  geom_smooth(method = "loess", se = FALSE, color = "grey35", linewidth = 0.5) +
  geom_text(aes(label = rotulo), x = -Inf, y = Inf, hjust = -0.05, vjust = 1.3,
            size = 2.4, inherit.aes = TRUE) +
  facet_grid(desfecho ~ clima, scales = "free",
             labeller = labeller(desfecho = nomes_desfecho, clima = nomes_clima)) +
  labs(
    title = "Relação entre exposições ambientais e desfechos mensais",
    subtitle = "Correlação de Spearman por painel — Campos dos Goytacazes (RJ), 2020–2024",
    x = "Variável ambiental", y = "Contagem mensal"
  ) +
  theme_cellpress(base_size = 7)

salvar_figura(fig_dispersao, "fig_dispersao_clima_desfechos.png",
              dir = CONFIG$dirs$spearman, largura = 9, altura = 6)

# 10.6 DLNM — efeito cumulativo da temperatura
fig_dlnm <- ggplot(resumo_dlnm, aes(x = temperatura_c, y = rr)) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "grey70") +
  geom_ribbon(aes(ymin = ic95_inf, ymax = ic95_sup, fill = desfecho), alpha = 0.2) +
  geom_line(aes(color = desfecho), linewidth = 0.7) +
  facet_wrap(~ desfecho, scales = "free_y") +
  scale_color_viridis_d(end = 0.7) +
  scale_fill_viridis_d(end = 0.7) +
  labs(
    title = "DLNM — efeito cumulativo da temperatura sobre os desfechos",
    subtitle = "Quasi-Poisson com offset; referência = temperatura mediana",
    x = "Temperatura média mensal (°C)", y = "RR cumulativo (IC95%)"
  ) +
  theme_cellpress() +
  theme(legend.position = "none")

salvar_figura(fig_dlnm, "fig_dlnm_temperatura.png",
              dir = CONFIG$dirs$dlnm, largura = 9, altura = 5)

# -----------------------------------------------------------------------------
# 11. Resumo interpretativo no console
# -----------------------------------------------------------------------------
cat("\n")
cat("=======================================================================\n")
cat(" ANÁLISE INFERENCIAL — CARDIOPATIAS CONGÊNITAS (Q20–Q28)\n")
cat(" Campos dos Goytacazes (RJ), 2020–2024\n")
cat("=======================================================================\n\n")

cat("--- 1. Tendência temporal (Mann-Kendall + Sen's slope) -----------------\n")
print(resumo_mann_kendall, row.names = FALSE)
cat("\n")

cat("--- 2. Correlação de Spearman (exposições ambientais x desfechos) ---------\n")
print(resumo_spearman, row.names = FALSE)
if (!is.null(resumo_spearman_taxas)) {
  cat("\n--- 2b. Spearman sobre as TAXAS mensais (por 10.000 nascidos vivos) -----\n")
  print(resumo_spearman_taxas, row.names = FALSE)
}
cat("\n")

cat("--- 3. Modelos de regressão (Poisson/QP/NB, lags e DLNM) ----------------\n")
cat("Offset:", if (usar_offset) "log(total de nascidos vivos no município)" else "NÃO disponível", "\n")
print(resumo_poisson, row.names = FALSE)
cat("\nPoisson com lags climáticos (1-3 meses, SINASC):\n")
print(resumo_poisson_lags, row.names = FALSE)
cat("\nDLNM (efeito cumulativo da temperatura):\n")
print(resumo_dlnm, row.names = FALSE)
cat("\n")

cat("--- 4. Interpretação ----------------------------------------------------\n")
for (mk in split(resumo_mann_kendall, resumo_mann_kendall$serie)) {
  cat(sprintf("  • %s: tau = %.2f (p = %.3f), Sen's slope = %.2f — %s.\n",
              mk$serie, mk$tau, mk$p_valor, mk$sen_slope, mk$interpretacao))
}

cat("\n  Correlações de Spearman (exposições ambientais x desfechos):\n")
desfechos_nome <- names(nomes_desfecho)
clima_nome <- names(nomes_clima)
for (dx in desfechos_nome) {
  for (dy in clima_nome) {
    linha <- resumo_spearman[
      (resumo_spearman$variavel_1 == nomes_variaveis[dx] & resumo_spearman$variavel_2 == nomes_variaveis[dy]) |
        (resumo_spearman$variavel_1 == nomes_variaveis[dy] & resumo_spearman$variavel_2 == nomes_variaveis[dx]), ]
    if (nrow(linha) == 1) {
      cat(sprintf("    %s × %s: rho = %.2f, p = %.3f (%s)\n",
                  nomes_variaveis[dx], nomes_variaveis[dy],
                  linha$rho, linha$p_valor, linha$significativo))
    }
  }
}

cat("\n  Modelos de contagem (Poisson, Quasi-Poisson, Binomial Negativa):\n")
for (mod in list(mod_sinasc, mod_sih)) {
  cat(sprintf("    • %s (n = %d; dispersão Pearson/df do Poisson = %.2f):\n",
              mod$tabela$desfecho[1], mod$n, mod$dispersao_poisson))
  for (fam in c("Poisson", "Quasi-Poisson", "Binomial Negativa")) {
    sub <- mod$tabela[mod$tabela$modelo == fam, ]
    if (nrow(sub) == 0L) {
      cat(sprintf("        - %s: não ajustado.\n", fam))
      next
    }
    sig <- sub[sub$termo != "(Intercept)" & sub$p_valor < 0.05, ]
    if (nrow(sig) == 0L) {
      cat(sprintf("        - %s: nenhum preditor significativo (p < 0,05).\n", fam))
    } else {
      for (j in seq_len(nrow(sig))) {
        cat(sprintf("        - %s | %s: IRR = %.3f (IC95%% %.3f–%.3f), p = %.3f\n",
                    fam, sig$termo[j], sig$irr[j],
                    sig$ic95_inf[j], sig$ic95_sup[j], sig$p_valor[j]))
      }
    }
  }
  if (!is.null(mod$nb)) {
    cat(sprintf("        • Binomial Negativa: theta = %.2f (theta grande ≈ Poisson).\n",
                as.numeric(mod$nb$theta)))
  }
}

cat("\n  Poisson com lags ambientais (1–3 meses) — SINASC:\n")
sig_lags <- resumo_poisson_lags[resumo_poisson_lags$termo != "(Intercept)" & resumo_poisson_lags$p_valor < 0.05, ]
if (nrow(sig_lags) == 0L) {
  cat("    • Nenhum preditor defasado significativo (p < 0,05).\n")
} else {
  for (j in seq_len(nrow(sig_lags))) {
    cat(sprintf("    • %s: IRR = %.3f (IC95%% %.3f–%.3f), p = %.3f\n",
                sig_lags$termo[j], sig_lags$irr[j],
                sig_lags$ic95_inf[j], sig_lags$ic95_sup[j], sig_lags$p_valor[j]))
  }
}

cat("\n  DLNM (efeito cumulativo da temperatura):\n")
for (dd in split(resumo_dlnm, resumo_dlnm$desfecho)) {
  cat(sprintf("    • %s (lag %s meses, referência %.1f°C):\n",
              dd$desfecho[1], dd$lag[1], dd$temperatura_referencia_c[1]))
  i_min <- which.min(dd$temperatura_c)
  i_max <- which.max(dd$temperatura_c)
  cat(sprintf("        RR em %.0f°C = %.2f (IC95%% %.2f–%.2f)\n",
              dd$temperatura_c[i_min], dd$rr[i_min],
              dd$ic95_inf[i_min], dd$ic95_sup[i_min]))
  cat(sprintf("        RR em %.0f°C = %.2f (IC95%% %.2f–%.2f)\n",
              dd$temperatura_c[i_max], dd$rr[i_max],
              dd$ic95_inf[i_max], dd$ic95_sup[i_max]))
}

cat("\n  Observações metodológicas:\n")
cat("    - Séries anuais curtas (n = 5 anos): o Mann-Kendall tem poder limitado;\n")
cat("      resultados de tendência devem ser interpretados com cautela.\n")
cat("    - O offset usa o total de nascidos vivos do município; para o SIH-RD é\n")
cat("      uma proxy de exposição (internações do mês referem-se a nascidos dos\n")
cat("      12 meses anteriores), devendo ser interpretada com cautela.\n")
cat("    - Para o SINASC avaliamos lags de 1–3 meses (janela da cardiogênese),\n")
cat("      incluindo clima e PM2.5; para o SIH-RD, exposição contemporânea e\n")
cat("      lag 0–3 meses no DLNM.\n")
cat("    - O PM2.5 do VIGIAR é estimado por satélite/modelagem (não medido em\n")
cat("      superfície); interpretar com cautela.\n")
cat("    - A série de 60 meses limita a complexidade dos modelos defasados\n")
cat("      (DLNM/lags); os resultados devem ser vistos como exploratórios.\n")
cat("    - Contagens mensais são pequenas (muitos zeros), o que reduz o poder\n")
cat("      estatístico dos modelos de regressão.\n")

cat("\n=======================================================================\n")
cat("Resultados por modelo em:", CONFIG$dirs$resultados, "\n")
cat("  descritiva:      ", CONFIG$dirs$descritiva, "\n")
cat("  Mann-Kendall:    ", CONFIG$dirs$mann_kendall, "\n")
cat("  Spearman:        ", CONFIG$dirs$spearman, "\n")
cat("  Poisson:         ", CONFIG$dirs$poisson, "\n")
cat("  Quasi-Poisson:   ", CONFIG$dirs$quasi_poisson, "\n")
cat("  Binomial Negativa:", CONFIG$dirs$binomial_negativa, "\n")
cat("  Poisson (lags):  ", CONFIG$dirs$poisson_lags, "\n")
cat("  DLNM:            ", CONFIG$dirs$dlnm, "\n")
cat("=======================================================================\n")
