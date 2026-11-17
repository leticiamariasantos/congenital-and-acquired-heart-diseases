# =============================================================================
# 03_funcoes_analise.R
# Funções compartilhadas da análise estatística (Etapa 1): taxas por 1.000 com
# IC de Poisson, tendência (Mann-Kendall / Hirsch-Slack) e sazonalidade
# (STL, razão de verossimilhança, qui-quadrado, Kruskal-Wallis).
#
# Usadas por scripts/03, 04 (2010–2019) e 06 (2020–2024), garantindo
# metodologia idêntica nos dois períodos.
# =============================================================================

conjuntos <- c("Q20_Q26" = "Q20-Q26 (principal)",
               "Q20_Q28" = "Q20-Q28 (sensibilidade)")
nome_conjunto <- function(x) unname(conjuntos[x])

# -----------------------------------------------------------------------------
# 1. Montagem da base mensal (casos + internações + denominador)
# -----------------------------------------------------------------------------
contar_mensal <- function(dados, rotulo) {
  dados %>%
    dplyr::count(ano, mes, name = "n") %>%
    dplyr::mutate(conjunto = rotulo)
}

calcular_taxa <- function(dados, numerador, denominador) {
  mult <- 1000 / dados[[denominador]]
  ic <- ic_poisson_exato(dados[[numerador]], nivel = 0.95, mult = mult)
  data.frame(
    taxa_por_1000 = ic$estimativa,
    ic95_inf      = ic$ic95_inf,
    ic95_sup      = ic$ic95_sup
  )
}

adicionar_taxas <- function(dados) {
  prev  <- calcular_taxa(dados, "casos", "n_nascidos")
  razao <- calcular_taxa(dados, "internacoes", "n_nascidos")
  dplyr::bind_cols(
    dados,
    prevalencia_por_1000 = prev$taxa_por_1000,
    prevalencia_ic95_inf = prev$ic95_inf,
    prevalencia_ic95_sup = prev$ic95_sup,
    razao_internacao_por_1000 = razao$taxa_por_1000,
    razao_ic95_inf = razao$ic95_inf,
    razao_ic95_sup = razao$ic95_sup
  )
}

montar_base_mensal <- function(anos, sin_q20q26, sin_q20q28,
                               sih_q20q26, sih_q20q28, totais) {
  grade_mensal <- expand.grid(ano = anos, mes = CONFIG$meses) %>%
    dplyr::mutate(mes_ano = as.Date(sprintf("%04d-%02d-01", ano, mes))) %>%
    dplyr::arrange(mes_ano)

  casos_sinasc <- dplyr::bind_rows(
    contar_mensal(sin_q20q26, "Q20_Q26"),
    contar_mensal(sin_q20q28, "Q20_Q28")
  )
  internacoes <- dplyr::bind_rows(
    contar_mensal(sih_q20q26, "Q20_Q26"),
    contar_mensal(sih_q20q28, "Q20_Q28")
  )

  base <- expand.grid(mes_ano = grade_mensal$mes_ano,
                      conjunto = names(conjuntos),
                      stringsAsFactors = FALSE) %>%
    dplyr::mutate(ano = lubridate::year(mes_ano),
                  mes = lubridate::month(mes_ano)) %>%
    dplyr::left_join(
      casos_sinasc %>% dplyr::select(ano, mes, conjunto, casos = n),
      by = c("ano", "mes", "conjunto")
    ) %>%
    dplyr::left_join(
      internacoes %>% dplyr::select(ano, mes, conjunto, internacoes = n),
      by = c("ano", "mes", "conjunto")
    ) %>%
    dplyr::left_join(
      totais %>% dplyr::select(ano, mes, n_nascidos),
      by = c("ano", "mes")
    ) %>%
    dplyr::mutate(
      casos       = tidyr::replace_na(casos, 0L),
      internacoes = tidyr::replace_na(internacoes, 0L),
      n_nascidos  = as.numeric(tidyr::replace_na(n_nascidos, NA_real_))
    ) %>%
    dplyr::arrange(conjunto, mes_ano)

  adicionar_taxas(base)
}

# -----------------------------------------------------------------------------
# 2. Tabelas (anual e mensal)
# -----------------------------------------------------------------------------
gerar_tabelas <- function(base_mensal) {
  base_anual <- base_mensal %>%
    dplyr::group_by(ano, conjunto) %>%
    dplyr::summarise(casos = sum(casos), internacoes = sum(internacoes),
                     n_nascidos = sum(n_nascidos, na.rm = TRUE),
                     .groups = "drop") %>%
    adicionar_taxas()

  list(
    base_anual = base_anual,
    prevalencias_anuais = base_anual %>%
      dplyr::transmute(ano, conjunto = nome_conjunto(conjunto),
                       casos, denominador = n_nascidos, prevalencia_por_1000,
                       ic95_inf = prevalencia_ic95_inf,
                       ic95_sup = prevalencia_ic95_sup) %>%
      dplyr::arrange(conjunto, ano),
    prevalencias_mensais = base_mensal %>%
      dplyr::transmute(mes_ano, ano, mes, conjunto = nome_conjunto(conjunto),
                       casos, denominador = n_nascidos, prevalencia_por_1000,
                       ic95_inf = prevalencia_ic95_inf,
                       ic95_sup = prevalencia_ic95_sup) %>%
      dplyr::arrange(conjunto, mes_ano),
    razoes_anuais = base_anual %>%
      dplyr::transmute(ano, conjunto = nome_conjunto(conjunto),
                       internacoes, denominador = n_nascidos,
                       razao_internacao_por_1000,
                       ic95_inf = razao_ic95_inf,
                       ic95_sup = razao_ic95_sup) %>%
      dplyr::arrange(conjunto, ano),
    razoes_mensais = base_mensal %>%
      dplyr::transmute(mes_ano, ano, mes, conjunto = nome_conjunto(conjunto),
                       internacoes, denominador = n_nascidos,
                       razao_internacao_por_1000,
                       ic95_inf = razao_ic95_inf,
                       ic95_sup = razao_ic95_sup) %>%
      dplyr::arrange(conjunto, mes_ano)
  )
}

# -----------------------------------------------------------------------------
# 3. Tendência
# -----------------------------------------------------------------------------
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

rodar_tendencia <- function(base_mensal, ano_inicio) {
  out <- list()
  for (conj in unique(base_mensal$conjunto)) {
    anual <- base_mensal %>%
      dplyr::filter(conjunto == conj) %>%
      dplyr::group_by(ano) %>%
      dplyr::summarise(casos = sum(casos), internacoes = sum(internacoes),
                       denominador = sum(n_nascidos, na.rm = TRUE),
                       .groups = "drop") %>%
      dplyr::mutate(prevalencia = 1000 * casos / denominador,
                    razao = 1000 * internacoes / denominador)

    mk_prev  <- trend::mk.test(anual$prevalencia)
    mk_razao <- trend::mk.test(anual$razao)

    out[[length(out) + 1]] <- data.frame(
      indicador = "Prevalência (SINASC)", conjunto = nome_conjunto(conj), escala = "Anual",
      teste = "Mann-Kendall", extrair_mk(mk_prev, nrow(anual)))
    out[[length(out) + 1]] <- data.frame(
      indicador = "Razão de internação (SIH)", conjunto = nome_conjunto(conj), escala = "Anual",
      teste = "Mann-Kendall", extrair_mk(mk_razao, nrow(anual)))

    mensal <- base_mensal %>% dplyr::filter(conjunto == conj) %>%
      dplyr::arrange(mes_ano)

    smk_prev  <- trend::smk.test(stats::ts(mensal$prevalencia_por_1000,
                                           start = c(ano_inicio, 1),
                                           frequency = 12))
    smk_razao <- trend::smk.test(stats::ts(mensal$razao_internacao_por_1000,
                                           start = c(ano_inicio, 1),
                                           frequency = 12))

    out[[length(out) + 1]] <- data.frame(
      indicador = "Prevalência (SINASC)", conjunto = nome_conjunto(conj), escala = "Mensal",
      teste = "Seasonal Mann-Kendall (Hirsch-Slack)",
      extrair_mk(smk_prev, nrow(mensal)))
    out[[length(out) + 1]] <- data.frame(
      indicador = "Razão de internação (SIH)", conjunto = nome_conjunto(conj), escala = "Mensal",
      teste = "Seasonal Mann-Kendall (Hirsch-Slack)",
      extrair_mk(smk_razao, nrow(mensal)))
  }
  dplyr::bind_rows(out) %>%
    dplyr::mutate(interpretacao = interpretar_p(p_valor)) %>%
    dplyr::relocate(interpretacao, .after = p_valor)
}

# -----------------------------------------------------------------------------
# 4. Sazonalidade
# -----------------------------------------------------------------------------
rodar_sazonalidade <- function(base_mensal, exposicoes) {
  out <- list()
  for (conj in unique(base_mensal$conjunto)) {
    d <- base_mensal %>% dplyr::filter(conjunto == conj)

    # Razão de verossimilhança (Poisson com/sem efeito de mês)
    m0 <- stats::glm(casos ~ 1, family = poisson,
                     offset = log(n_nascidos), data = d)
    m1 <- stats::glm(casos ~ factor(mes), family = poisson,
                     offset = log(n_nascidos), data = d)
    lr <- stats::anova(m0, m1, test = "Chisq")
    out[[length(out) + 1]] <- data.frame(
      indicador = "Casos SINASC (malformações)", conjunto = nome_conjunto(conj),
      teste = "Razão de verossimilhança (Poisson com/sem mês)",
      estatistica = lr$Deviance[2], df = lr$Df[2],
      p_valor = lr$`Pr(>Chi)`[2])

    m0 <- stats::glm(internacoes ~ 1, family = poisson,
                     offset = log(n_nascidos), data = d)
    m1 <- stats::glm(internacoes ~ factor(mes), family = poisson,
                     offset = log(n_nascidos), data = d)
    lr <- stats::anova(m0, m1, test = "Chisq")
    out[[length(out) + 1]] <- data.frame(
      indicador = "Internações SIH (< 1 ano)", conjunto = nome_conjunto(conj),
      teste = "Razão de verossimilhança (Poisson com/sem mês)",
      estatistica = lr$Deviance[2], df = lr$Df[2],
      p_valor = lr$`Pr(>Chi)`[2])

    # Qui-quadrado (distribuição mensal ponderada pelo denominador)
    d_mes <- d %>%
      dplyr::group_by(mes) %>%
      dplyr::summarise(casos = sum(casos), internacoes = sum(internacoes),
                       denominador = sum(n_nascidos, na.rm = TRUE),
                       .groups = "drop")
    p_esp <- d_mes$denominador / sum(d_mes$denominador, na.rm = TRUE)

    cq <- suppressWarnings(stats::chisq.test(d_mes$casos, p = p_esp))
    out[[length(out) + 1]] <- data.frame(
      indicador = "Casos SINASC (malformações)", conjunto = nome_conjunto(conj),
      teste = "Qui-quadrado (distribuição mensal)",
      estatistica = unname(cq$statistic), df = unname(cq$parameter),
      p_valor = unname(cq$p.value))

    cq2 <- suppressWarnings(stats::chisq.test(d_mes$internacoes, p = p_esp))
    out[[length(out) + 1]] <- data.frame(
      indicador = "Internações SIH (< 1 ano)", conjunto = nome_conjunto(conj),
      teste = "Qui-quadrado (distribuição mensal)",
      estatistica = unname(cq2$statistic), df = unname(cq2$parameter),
      p_valor = unname(cq2$p.value))
  }

  # Kruskal-Wallis nas EXPOSIÇÕES (variação entre meses)
  expo_vars  <- c("temp_media_c", "umidade_media_pct", "pm25")
  expo_nomes <- c("Temperatura (°C)", "Umidade relativa (%)", "PM2,5 (µg/m³)")
  for (i in seq_along(expo_vars)) {
    v <- expo_vars[i]
    dd <- exposicoes[!is.na(exposicoes[[v]]), ]
    kw <- stats::kruskal.test(dd[[v]] ~ as.factor(dd$mes))
    out[[length(out) + 1]] <- data.frame(
      indicador = expo_nomes[i], conjunto = "Exposição",
      teste = "Kruskal-Wallis (variação entre meses)",
      estatistica = unname(kw$statistic), df = unname(kw$parameter),
      p_valor = unname(kw$p.value))
  }

  dplyr::bind_rows(out) %>%
    dplyr::mutate(
      interpretacao = ifelse(p_valor < 0.05,
                             "Evidência de sazonalidade (p < 0,05)",
                             "Sem evidência de sazonalidade (p >= 0,05)")
    )
}

# -----------------------------------------------------------------------------
# 5. STL e figuras
# -----------------------------------------------------------------------------
interpolar_na <- function(y) {
  if (sum(!is.na(y)) < 2) return(y)
  idx <- which(!is.na(y))
  y[is.na(y)] <- stats::approx(idx, y[idx], xout = which(is.na(y)),
                               rule = 2)$y
  y
}

decompor_stl <- function(serie, nome, arquivo_png, ano_inicio, ano_fim,
                         fonte_subtitulo) {
  y <- interpolar_na(serie)
  obj_ts <- stats::ts(y, start = c(ano_inicio, 1), frequency = 12)
  fit <- stats::stl(obj_ts, s.window = "periodic")

  comp <- as.data.frame(fit$time.series)
  comp$observado <- as.numeric(obj_ts)
  comp$mes_ano <- seq(as.Date(sprintf("%04d-01-01", ano_inicio)),
                      as.Date(sprintf("%04d-12-01", ano_fim)), by = "month")

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
                  subtitle = fonte_subtitulo,
                  x = NULL, y = NULL) +
    theme_cellpress()
  ggplot2::ggsave(arquivo_png, g, width = 8, height = 7, dpi = 300)
  invisible(fit)
}

salvar_figuras <- function(base_mensal, exposicoes, dir_figuras, periodo_rotulo) {
  # Séries temporais dos desfechos
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
    dplyr::mutate(conjunto = dplyr::recode(conjunto,
      "Q20-Q26 (principal)" = "Q20–Q26 (principal)",
      "Q20-Q28 (sensibilidade)" = "Q20–Q28 (sensibilidade)"))

  g_desf <- ggplot2::ggplot(desfechos_longo,
                            ggplot2::aes(mes_ano, valor, color = conjunto)) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = ic_inf, ymax = ic_sup, fill = conjunto),
                         alpha = 0.15, color = NA) +
    ggplot2::geom_line(linewidth = 0.4) +
    ggplot2::facet_wrap(~ indicador, ncol = 1, scales = "free_y") +
    ggplot2::scale_color_viridis_d(option = "viridis") +
    ggplot2::scale_fill_viridis_d(option = "viridis") +
    ggplot2::labs(title = "Desfechos mensais por 1.000 nascidos vivos (IC 95% Poisson)",
                  subtitle = sprintf("Campos dos Goytacazes · %s", periodo_rotulo),
                  x = NULL, y = "Taxa por 1.000 nascidos vivos",
                  color = NULL, fill = NULL) +
    theme_cellpress()
  ggplot2::ggsave(file.path(dir_figuras, "fig_serie_temporal_desfechos.png"),
                  g_desf, width = 9, height = 6, dpi = 300)

  # Séries temporais das exposições
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
                  subtitle = sprintf("INMET A607 / VIGIAR-MS · Campos dos Goytacazes · %s",
                                     periodo_rotulo),
                  x = NULL, y = NULL) +
    theme_cellpress()
  ggplot2::ggsave(file.path(dir_figuras, "fig_serie_temporal_exposicoes.png"),
                  g_expo, width = 9, height = 7, dpi = 300)

  # Boxplots mensais das exposições
  expo_box <- exposicoes %>%
    dplyr::select(mes, temp_media_c, umidade_media_pct, pm25) %>%
    tidyr::pivot_longer(-mes, names_to = "variavel", values_to = "valor") %>%
    dplyr::filter(!is.na(valor)) %>%
    dplyr::mutate(variavel = factor(variavel,
      levels = c("temp_media_c", "umidade_media_pct", "pm25"),
      labels = c("Temperatura média (°C)", "Umidade relativa (%)", "PM2,5 (µg/m³)")))

  g_box <- ggplot2::ggplot(expo_box, ggplot2::aes(factor(mes), valor)) +
    ggplot2::geom_boxplot(fill = paleta(3)[2], alpha = 0.7, outlier.size = 0.5) +
    ggplot2::facet_wrap(~ variavel, ncol = 1, scales = "free_y") +
    ggplot2::labs(title = sprintf("Distribuição mensal das exposições (%s)",
                                  periodo_rotulo),
                  subtitle = "Boxplots por mês · Campos dos Goytacazes",
                  x = "Mês", y = NULL) +
    theme_cellpress()
  ggplot2::ggsave(file.path(dir_figuras, "fig_boxplot_exposicoes_mensais.png"),
                  g_box, width = 9, height = 7, dpi = 300)

  invisible(TRUE)
}
