# =============================================================================
# 04_tendencia_sazonalidade.R
# Análise de tendência e sazonalidade — Etapa 1
#
#   Tendência:
#     - Séries anuais  -> Mann-Kendall (trend::mk.test)
#     - Séries mensais -> Seasonal Mann-Kendall / Hirsch-Slack (trend::smk.test)
#   Sazonalidade:
#     - Decomposição STL das exposições (temperatura, umidade, PM2,5)
#     - Razão de verossimilhança entre modelos de Poisson com e sem efeito de
#       mês (desfechos)
#     - Testes complementares: qui-quadrado (distribuição mensal dos casos) e
#       Kruskal-Wallis (variação mensal das exposições)
#
# Saídas:
#   results/tables/testes_tendencia.csv
#   results/tables/testes_sazonalidade.csv
#   results/figures/fig_serie_temporal_desfechos.png
#   results/figures/fig_serie_temporal_exposicoes.png
#   results/figures/fig_boxplot_exposicoes_mensais.png
#   results/figures/fig_stl_*.png (uma por exposição)
#
# Uso: Rscript scripts/04_tendencia_sazonalidade.R  (ou via run_all.R)
# =============================================================================

if (basename(getwd()) == "scripts" && file.exists("00_config.R")) setwd("..")
stopifnot(file.exists("scripts/00_config.R"))
source("scripts/00_config.R")
source("scripts/00_utils.R")
garantir_diretorios()

for (p in c("dplyr", "tidyr", "readr", "lubridate", "ggplot2", "trend",
            "Kendall", "viridisLite")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  suppressPackageStartupMessages(library(p, character.only = TRUE))
}

# -----------------------------------------------------------------------------
# 1. Leitura e montagem da base mensal
# -----------------------------------------------------------------------------
prev_mensal <- readr::read_csv(CONFIG$tabelas$prevalencias_mensais,
                               show_col_types = FALSE)
razao_mensal <- readr::read_csv(CONFIG$tabelas$razoes_mensais,
                                show_col_types = FALSE)

base_mensal <- prev_mensal %>%
  dplyr::rename(prevalencia_ic95_inf = ic95_inf,
                prevalencia_ic95_sup = ic95_sup) %>%
  dplyr::left_join(
    razao_mensal %>%
      dplyr::select(mes_ano, conjunto, internacoes, razao_internacao_por_1000,
                    ic95_inf, ic95_sup) %>%
      dplyr::rename(razao_ic95_inf = ic95_inf, razao_ic95_sup = ic95_sup),
    by = c("mes_ano", "conjunto")
  )

# --- Exposições ----------------------------------------------------------
temp_umid <- readr::read_csv(CONFIG$arquivos$temp_umidade_mensal,
                             show_col_types = FALSE)
pm25      <- readr::read_csv(CONFIG$arquivos$pm25_mensal,
                             show_col_types = FALSE)

exposicoes <- temp_umid %>%
  dplyr::select(mes_ano, ano, mes, temp_media_c, umidade_media_pct,
                qualidade_ok) %>%
  dplyr::left_join(pm25 %>% dplyr::select(mes_ano, pm25), by = "mes_ano") %>%
  dplyr::mutate(
    # meses que não passam no critério de qualidade do INMET => NA
    temp_media_c     = ifelse(qualidade_ok, temp_media_c, NA_real_),
    umidade_media_pct = ifelse(qualidade_ok, umidade_media_pct, NA_real_)
  ) %>%
  dplyr::arrange(mes_ano)

# -----------------------------------------------------------------------------
# 2. Tendência
# -----------------------------------------------------------------------------
# Extrai de forma segura S, tau, z e p-valor de um objeto htest do {trend}.
extrair_mk <- function(res, n_obs) {
  S   <- tryCatch(unname(res$estimates["S"]), error = function(e) NA_real_)
  tau <- tryCatch(unname(res$estimates["tau"]), error = function(e) NA_real_)
  z   <- tryCatch(unname(res$statistic), error = function(e) NA_real_)
  p   <- tryCatch(unname(res$p.value), error = function(e) NA_real_)
  data.frame(S = S, tau = tau, z = z, p_valor = p, n = n_obs)
}

interpretar_p <- function(p) {
  ifelse(p < 0.001, "Tendência significativa (p < 0,001)",
         ifelse(p < 0.05, "Tendência significativa (p < 0,05)",
                "Sem tendência significativa (p >= 0,05)"))
}

testes_tendencia <- list()

for (conj in unique(base_mensal$conjunto)) {
  # --- séries anuais (Mann-Kendall) ---
  anual <- base_mensal %>%
    dplyr::filter(conjunto == conj) %>%
    dplyr::group_by(ano) %>%
    dplyr::summarise(
      casos = sum(casos), internacoes = sum(internacoes),
      denominador = sum(denominador, na.rm = TRUE), .groups = "drop"
    ) %>%
    dplyr::mutate(
      prevalencia = 1000 * casos / denominador,
      razao       = 1000 * internacoes / denominador
    )

  mk_prev  <- trend::mk.test(anual$prevalencia)
  mk_razao <- trend::mk.test(anual$razao)

  testes_tendencia[[length(testes_tendencia) + 1]] <-
    data.frame(indicador = "Prevalência (SINASC)", conjunto = conj,
               escala = "Anual", teste = "Mann-Kendall",
               extrair_mk(mk_prev, nrow(anual)))
  testes_tendencia[[length(testes_tendencia) + 1]] <-
    data.frame(indicador = "Razão de internação (SIH)", conjunto = conj,
               escala = "Anual", teste = "Mann-Kendall",
               extrair_mk(mk_razao, nrow(anual)))

  # --- séries mensais (Seasonal Mann-Kendall / Hirsch-Slack) ---
  mensal <- base_mensal %>% dplyr::filter(conjunto == conj) %>%
    dplyr::arrange(mes_ano)

  smk_prev  <- trend::smk.test(stats::ts(mensal$prevalencia_por_1000,
                                         start = c(CONFIG$ano_inicio, 1),
                                         frequency = 12))
  smk_razao <- trend::smk.test(stats::ts(mensal$razao_internacao_por_1000,
                                         start = c(CONFIG$ano_inicio, 1),
                                         frequency = 12))

  testes_tendencia[[length(testes_tendencia) + 1]] <-
    data.frame(indicador = "Prevalência (SINASC)", conjunto = conj,
               escala = "Mensal", teste = "Seasonal Mann-Kendall (Hirsch-Slack)",
               extrair_mk(smk_prev, nrow(mensal)))
  testes_tendencia[[length(testes_tendencia) + 1]] <-
    data.frame(indicador = "Razão de internação (SIH)", conjunto = conj,
               escala = "Mensal", teste = "Seasonal Mann-Kendall (Hirsch-Slack)",
               extrair_mk(smk_razao, nrow(mensal)))
}

testes_tendencia <- dplyr::bind_rows(testes_tendencia) %>%
  dplyr::mutate(interpretacao = interpretar_p(p_valor)) %>%
  dplyr::relocate(interpretacao, .after = p_valor)

readr::write_csv(testes_tendencia, CONFIG$tabelas$testes_tendencia, na = "")

# -----------------------------------------------------------------------------
# 3. Sazonalidade
# -----------------------------------------------------------------------------
testes_saz <- list()

# --- 3.1 Razão de verossimilhança (Poisson com vs. sem efeito de mês) ----
for (conj in unique(base_mensal$conjunto)) {
  d <- base_mensal %>% dplyr::filter(conjunto == conj)

  # Desfecho 1: casos SINASC
  m0 <- stats::glm(casos ~ 1, family = poisson,
                   offset = log(denominador), data = d)
  m1 <- stats::glm(casos ~ factor(mes), family = poisson,
                   offset = log(denominador), data = d)
  lr <- stats::anova(m0, m1, test = "Chisq")
  lr_stat <- lr$Deviance[2]; lr_df <- lr$Df[2]; lr_p <- lr$`Pr(>Chi)`[2]

  testes_saz[[length(testes_saz) + 1]] <- data.frame(
    indicador = "Casos SINASC (malformações)", conjunto = conj,
    teste = "Razão de verossimilhança (Poisson com/sem mês)",
    estatistica = lr_stat, df = lr_df, p_valor = lr_p)

  # Desfecho 2: internações SIH
  m0 <- stats::glm(internacoes ~ 1, family = poisson,
                   offset = log(denominador), data = d)
  m1 <- stats::glm(internacoes ~ factor(mes), family = poisson,
                   offset = log(denominador), data = d)
  lr <- stats::anova(m0, m1, test = "Chisq")
  testes_saz[[length(testes_saz) + 1]] <- data.frame(
    indicador = "Internações SIH (< 1 ano)", conjunto = conj,
    teste = "Razão de verossimilhança (Poisson com/sem mês)",
    estatistica = lr$Deviance[2], df = lr$Df[2], p_valor = lr$`Pr(>Chi)`[2])

  # --- 3.2 Qui-quadrado (distribuição mensal dos casos vs. esperado) ----
  # Agrega por mês do calendário (12 categorias) e compara com a distribuição
  # esperada ponderada pelo denominador (df = 11).
  d_mes <- d %>%
    dplyr::group_by(mes) %>%
    dplyr::summarise(casos = sum(casos), internacoes = sum(internacoes),
                     denominador = sum(denominador, na.rm = TRUE),
                     .groups = "drop")
  p_esp <- d_mes$denominador / sum(d_mes$denominador, na.rm = TRUE)

  cq <- suppressWarnings(stats::chisq.test(d_mes$casos, p = p_esp))
  testes_saz[[length(testes_saz) + 1]] <- data.frame(
    indicador = "Casos SINASC (malformações)", conjunto = conj,
    teste = "Qui-quadrado (distribuição mensal)",
    estatistica = unname(cq$statistic), df = unname(cq$parameter),
    p_valor = unname(cq$p.value))

  cq2 <- suppressWarnings(stats::chisq.test(d_mes$internacoes, p = p_esp))
  testes_saz[[length(testes_saz) + 1]] <- data.frame(
    indicador = "Internações SIH (< 1 ano)", conjunto = conj,
    teste = "Qui-quadrado (distribuição mensal)",
    estatistica = unname(cq2$statistic), df = unname(cq2$parameter),
    p_valor = unname(cq2$p.value))
}

# --- 3.3 Kruskal-Wallis (variação mensal das exposições) ----------------
expo_vars <- c("temp_media_c", "umidade_media_pct", "pm25")
expo_nomes <- c("Temperatura (°C)", "Umidade relativa (%)", "PM2,5 (µg/m³)")
for (i in seq_along(expo_vars)) {
  v <- expo_vars[i]
  d <- exposicoes[!is.na(exposicoes[[v]]), ]
  kw <- stats::kruskal.test(d[[v]] ~ as.factor(d$mes))
  testes_saz[[length(testes_saz) + 1]] <- data.frame(
    indicador = expo_nomes[i], conjunto = "Exposição",
    teste = "Kruskal-Wallis (variação entre meses)",
    estatistica = unname(kw$statistic), df = unname(kw$parameter),
    p_valor = unname(kw$p.value))
}

testes_saz <- dplyr::bind_rows(testes_saz) %>%
  dplyr::mutate(
    interpretacao = ifelse(p_valor < 0.05,
                           "Evidência de sazonalidade (p < 0,05)",
                           "Sem evidência de sazonalidade (p >= 0,05)")
  )

readr::write_csv(testes_saz, CONFIG$tabelas$testes_sazonalidade, na = "")

# -----------------------------------------------------------------------------
# 4. Decomposição STL das exposições
# -----------------------------------------------------------------------------
# Preenche NAs internos por interpolação linear (exigência do stl()).
interpolar_na <- function(y) {
  if (sum(!is.na(y)) < 2) return(y)
  idx <- which(!is.na(y))
  y[is.na(y)] <- stats::approx(idx, y[idx],
                               xout = which(is.na(y)), rule = 2)$y
  y
}

decompor_stl <- function(serie, nome, arquivo_png) {
  y <- interpolar_na(serie)
  obj_ts <- stats::ts(y, start = c(CONFIG$ano_inicio, 1), frequency = 12)
  fit <- stats::stl(obj_ts, s.window = "periodic")

  comp <- as.data.frame(fit$time.series)
  comp$observado <- as.numeric(obj_ts)
  comp$mes_ano <- seq(as.Date(sprintf("%04d-01-01", CONFIG$ano_inicio)),
                      as.Date(sprintf("%04d-12-01", CONFIG$ano_fim)),
                      by = "month")

  longo <- comp %>%
    tidyr::pivot_longer(cols = c(observado, seasonal, trend, remainder),
                        names_to = "componente", values_to = "valor") %>%
    dplyr::mutate(componente = factor(componente,
      levels = c("observado", "seasonal", "trend", "remainder"),
      labels = c("Observado", "Sazonal", "Tendência", "Resíduo")))

  g <- ggplot2::ggplot(longo, ggplot2::aes(mes_ano, valor)) +
    ggplot2::geom_line(linewidth = 0.3) +
    ggplot2::facet_wrap(~ componente, ncol = 1, scales = "free_y") +
    ggplot2::labs(title = sprintf("Decomposição STL — %s", nome),
                  subtitle = "INMET A607 / VIGIAR-MS · Campos dos Goytacazes · 2010–2019",
                  x = NULL, y = NULL) +
    theme_cellpress()
  ggplot2::ggsave(arquivo_png, g, width = 8, height = 7, dpi = 300)
  invisible(fit)
}

stl_temp <- decompor_stl(exposicoes$temp_media_c, "Temperatura média (°C)",
                         file.path(CONFIG$dirs$figuras, "fig_stl_temperatura.png"))
stl_umid <- decompor_stl(exposicoes$umidade_media_pct, "Umidade relativa (%)",
                         file.path(CONFIG$dirs$figuras, "fig_stl_umidade.png"))
stl_pm25 <- decompor_stl(exposicoes$pm25, "PM2,5 (µg/m³)",
                         file.path(CONFIG$dirs$figuras, "fig_stl_pm25.png"))

# -----------------------------------------------------------------------------
# 5. Figuras
# -----------------------------------------------------------------------------
# --- 5.1 Séries temporais dos desfechos (prevalência e razão, por 1.000) ---
desfechos_longo <- dplyr::bind_rows(
  base_mensal %>%
    dplyr::transmute(mes_ano, conjunto, indicador = "Prevalência (SINASC)",
                     valor = prevalencia_por_1000,
                     ic_inf = prevalencia_ic95_inf, ic_sup = prevalencia_ic95_sup),
  base_mensal %>%
    dplyr::transmute(mes_ano, conjunto, indicador = "Razão de internação (SIH)",
                     valor = razao_internacao_por_1000,
                     ic_inf = razao_ic95_inf, ic_sup = razao_ic95_sup)
) %>%
  dplyr::mutate(
    conjunto = dplyr::recode(conjunto,
      "Q20-Q26 (principal)" = "Q20–Q26 (principal)",
      "Q20-Q28 (sensibilidade)" = "Q20–Q28 (sensibilidade)")
  )

g_desf <- ggplot2::ggplot(desfechos_longo,
                          ggplot2::aes(mes_ano, valor, color = conjunto)) +
  ggplot2::geom_ribbon(ggplot2::aes(ymin = ic_inf, ymax = ic_sup, fill = conjunto),
                       alpha = 0.15, color = NA) +
  ggplot2::geom_line(linewidth = 0.4) +
  ggplot2::facet_wrap(~ indicador, ncol = 1, scales = "free_y") +
  ggplot2::scale_color_viridis_d(option = "viridis") +
  ggplot2::scale_fill_viridis_d(option = "viridis") +
  ggplot2::labs(title = "Desfechos mensais por 1.000 nascidos vivos (IC 95% Poisson)",
                subtitle = "Campos dos Goytacazes · 2010–2019",
                x = NULL, y = "Taxa por 1.000 nascidos vivos",
                color = NULL, fill = NULL) +
  theme_cellpress()
ggplot2::ggsave(file.path(CONFIG$dirs$figuras, "fig_serie_temporal_desfechos.png"),
                g_desf, width = 9, height = 6, dpi = 300)

# --- 5.2 Séries temporais das exposições ---------------------------------
expo_longo <- exposicoes %>%
  dplyr::select(mes_ano, temp_media_c, umidade_media_pct, pm25) %>%
  tidyr::pivot_longer(-mes_ano, names_to = "variavel", values_to = "valor") %>%
  dplyr::mutate(variavel = factor(variavel,
    levels = c("temp_media_c", "umidade_media_pct", "pm25"),
    labels = c("Temperatura média (°C)", "Umidade relativa (%)", "PM2,5 (µg/m³)")))

g_expo <- ggplot2::ggplot(expo_longo, ggplot2::aes(mes_ano, valor)) +
  ggplot2::geom_line(linewidth = 0.4, color = paleta(1)) +
  ggplot2::facet_wrap(~ variavel, ncol = 1, scales = "free_y") +
  ggplot2::labs(title = "Exposições ambientais mensais",
                subtitle = "INMET A607 / VIGIAR-MS · Campos dos Goytacazes · 2010–2019",
                x = NULL, y = NULL) +
  theme_cellpress()
ggplot2::ggsave(file.path(CONFIG$dirs$figuras, "fig_serie_temporal_exposicoes.png"),
                g_expo, width = 9, height = 7, dpi = 300)

# --- 5.3 Boxplots mensais das exposições ---------------------------------
expo_box <- exposicoes %>%
  dplyr::select(mes, temp_media_c, umidade_media_pct, pm25) %>%
  tidyr::pivot_longer(-mes, names_to = "variavel", values_to = "valor") %>%
  dplyr::filter(!is.na(valor)) %>%
  dplyr::mutate(variavel = factor(variavel,
    levels = c("temp_media_c", "umidade_media_pct", "pm25"),
    labels = c("Temperatura média (°C)", "Umidade relativa (%)", "PM2,5 (µg/m³)")))

g_box <- ggplot2::ggplot(expo_box,
                         ggplot2::aes(factor(mes), valor)) +
  ggplot2::geom_boxplot(fill = paleta(3)[2], alpha = 0.7, outlier.size = 0.5) +
  ggplot2::facet_wrap(~ variavel, ncol = 1, scales = "free_y") +
  ggplot2::labs(title = "Distribuição mensal das exposições (2010–2019)",
                subtitle = "Boxplots por mês · Campos dos Goytacazes",
                x = "Mês", y = NULL) +
  theme_cellpress()
ggplot2::ggsave(file.path(CONFIG$dirs$figuras, "fig_boxplot_exposicoes_mensais.png"),
                g_box, width = 9, height = 7, dpi = 300)

# -----------------------------------------------------------------------------
# 6. Resumo no console
# -----------------------------------------------------------------------------
cat("\n========== TENDÊNCIA E SAZONALIDADE — CONCLUÍDO ==========\n")
cat("\nTestes de tendência:\n")
print(as.data.frame(testes_tendencia))
cat("\nTestes de sazonalidade:\n")
print(as.data.frame(testes_saz))
cat("\nFiguras geradas em results/figures/:\n")
cat("  fig_serie_temporal_desfechos.png\n")
cat("  fig_serie_temporal_exposicoes.png\n")
cat("  fig_boxplot_exposicoes_mensais.png\n")
cat("  fig_stl_temperatura.png / fig_stl_umidade.png / fig_stl_pm25.png\n")
cat("===========================================================\n")
