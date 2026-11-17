# =============================================================================
# 04_series_temporais.R
# Análise descritiva da TENDÊNCIA e da SAZONALIDADE das séries temporais de
# nascidos vivos (SINASC) e internações (SIH-RD) com malformações congênitas do
# aparelho circulatório (CID-10 Q20-Q28) — Campos dos Goytacazes (RJ), 2020-2024.
#
# Produz:
#   - Taxas mensais por 10.000 nascidos vivos com IC 95% (exato de Poisson)
#   - Taxas anuais por 10.000 nascidos vivos com IC 95%
#   - Testes de tendência (Mann-Kendall anual e Mann-Kendall sazonal)
#   - Análise de sazonalidade (taxas por mês-calendário + testes)
#   - Decomposição STL (tendência, sazonalidade, resíduo)
#
# Saídas em results/00_descritiva/.
#
# Uso (a partir da raiz do repositório):
#   Rscript analysis/04_series_temporais.R
# =============================================================================

options(stringsAsFactors = FALSE)
Sys.setenv(TZ = "America/Sao_Paulo")

for (p in c("dplyr", "tidyr", "readr", "ggplot2", "lubridate", "Kendall", "trend")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
}
invisible(lapply(c("dplyr", "tidyr", "readr", "ggplot2", "lubridate",
                   "Kendall", "trend"), library, character.only = TRUE))

source("src/00_config.R")
source("src/01_utils.R")
garantir_diretorios()

MULT <- 1e4  # taxas por 10.000 nascidos vivos
meses_pt <- c("Jan", "Fev", "Mar", "Abr", "Mai", "Jun",
              "Jul", "Ago", "Set", "Out", "Nov", "Dez")

# -----------------------------------------------------------------------------
# 1. Dados: casos mensais e denominador (nascidos vivos)
# -----------------------------------------------------------------------------
sinasc <- readRDS(CONFIG$arquivos$sinasc_rds) %>%
  dplyr::mutate(
    DTNASC = as.Date(DTNASC),
    mes_ano = as.Date(sprintf("%04d-%02d-01", lubridate::year(DTNASC),
                              lubridate::month(DTNASC)))
  )
sih <- readRDS(CONFIG$arquivos$sih_rds) %>%
  dplyr::mutate(
    ANO_CMPT = as.integer(ANO_CMPT), MES_CMPT = as.integer(MES_CMPT),
    mes_ano = as.Date(sprintf("%04d-%02d-01", ANO_CMPT, MES_CMPT))
  )

grade <- data.frame(
  mes_ano = seq(as.Date("2020-01-01"), as.Date("2024-12-01"), by = "month")
)

# Denominador: total de nascidos vivos do município por mês (cache SINASC)
tot_nascidos <- tryCatch({
  dplyr::bind_rows(lapply(CONFIG$anos, function(a) {
    f <- file.path(CONFIG$dirs$cache_processado,
                   sprintf("SINASC_RJ_%d_processado.rds", a))
    if (!file.exists(f)) stop("cache ausente: ", f)
    x <- readRDS(f)
    x <- x[x$CODMUNRES == CONFIG$municipio_residencia_codigo, "DTNASC", drop = FALSE]
    x %>%
      dplyr::mutate(dt = as.Date(DTNASC)) %>%
      dplyr::filter(!is.na(dt)) %>%
      dplyr::mutate(mes_ano = as.Date(sprintf("%04d-%02d-01",
                                              lubridate::year(dt), lubridate::month(dt)))) %>%
      dplyr::count(mes_ano, name = "nascidos")
  }))
}, error = function(e) {
  warning("Denominador (nascidos vivos) indisponível: ", conditionMessage(e))
  NULL
})
if (is.null(tot_nascidos)) {
  stop("O denominador de nascidos vivos é necessário. Verifique o cache SINASC.")
}

dados <- grade %>%
  dplyr::left_join(sinasc %>% dplyr::count(mes_ano, name = "casos_sinasc"), by = "mes_ano") %>%
  dplyr::left_join(sih %>% dplyr::count(mes_ano, name = "internacoes"), by = "mes_ano") %>%
  dplyr::left_join(tot_nascidos, by = "mes_ano") %>%
  tidyr::replace_na(list(casos_sinasc = 0L, internacoes = 0L)) %>%
  dplyr::arrange(mes_ano) %>%
  dplyr::mutate(ano = lubridate::year(mes_ano), mes = lubridate::month(mes_ano))

# -----------------------------------------------------------------------------
# 2. Taxas por 10.000 nascidos vivos com IC 95% (exato de Poisson / Garwood)
# -----------------------------------------------------------------------------
# IC exato para uma taxa = casos / nascidos:
#   [qchisq(0.025, 2x)/2 ; qchisq(0.975, 2(x+1))/2] / nascidos
taxa_ic <- function(casos, nascidos, mult = MULT) {
  casos <- as.numeric(casos); nascidos <- as.numeric(nascidos)
  inf <- ifelse(casos == 0, 0, stats::qchisq(0.025, 2 * casos) / 2)
  sup <- stats::qchisq(0.975, 2 * (casos + 1)) / 2
  list(
    taxa = casos / nascidos * mult,
    ic_inf = inf / nascidos * mult,
    ic_sup = sup / nascidos * mult
  )
}

# Taxas mensais
ic_sin <- taxa_ic(dados$casos_sinasc, dados$nascidos)
ic_sih <- taxa_ic(dados$internacoes, dados$nascidos)

taxas_mensais <- dados %>%
  dplyr::mutate(
    taxa_sinasc = ic_sin$taxa, sinasc_inf = ic_sin$ic_inf, sinasc_sup = ic_sin$ic_sup,
    taxa_sih = ic_sih$taxa, sih_inf = ic_sih$ic_inf, sih_sup = ic_sih$ic_sup
  ) %>%
  dplyr::select(mes_ano, ano, mes, casos_sinasc, internacoes, nascidos,
                taxa_sinasc, sinasc_inf, sinasc_sup,
                taxa_sih, sih_inf, sih_sup)
readr::write_csv(taxas_mensais,
                 file.path(CONFIG$dirs$descritiva, "taxas_mensais_10000.csv"), na = "")

# Taxas anuais
taxas_anuais <- dados %>%
  dplyr::group_by(ano) %>%
  dplyr::summarise(casos_sinasc = sum(casos_sinasc), internacoes = sum(internacoes),
                   nascidos = sum(nascidos), .groups = "drop")
ic_sin_a <- taxa_ic(taxas_anuais$casos_sinasc, taxas_anuais$nascidos)
ic_sih_a <- taxa_ic(taxas_anuais$internacoes, taxas_anuais$nascidos)
taxas_anuais <- taxas_anuais %>%
  dplyr::mutate(
    taxa_sinasc = ic_sin_a$taxa, sinasc_inf = ic_sin_a$ic_inf, sinasc_sup = ic_sin_a$ic_sup,
    taxa_sih = ic_sih_a$taxa, sih_inf = ic_sih_a$ic_inf, sih_sup = ic_sih_a$ic_sup
  )
readr::write_csv(taxas_anuais,
                 file.path(CONFIG$dirs$descritiva, "taxas_anuais_10000.csv"), na = "")

# -----------------------------------------------------------------------------
# 3. Testes de tendência
# -----------------------------------------------------------------------------
mk_linha <- function(x, desfecho, nivel) {
  x <- as.numeric(x)
  mk <- Kendall::MannKendall(x)
  ss <- tryCatch(trend::sens.slope(x), error = function(e) NULL)
  data.frame(
    desfecho = desfecho,
    nivel = nivel,
    teste = "Mann-Kendall",
    tau = as.numeric(mk$tau),
    S = as.numeric(mk$S),
    p_valor = as.numeric(mk$sl),
    inclinacao_sen = if (is.null(ss)) NA_real_ else as.numeric(ss$estimates["Sen's slope"]),
    stringsAsFactors = FALSE
  )
}

smk_linha <- function(x, desfecho) {
  tsx <- stats::ts(as.numeric(x), start = c(2020, 1), frequency = 12)
  smk <- trend::smk.test(tsx)
  data.frame(
    desfecho = desfecho,
    nivel = "mensal (sazonal)",
    teste = "Mann-Kendall sazonal (Hirsch-Slack)",
    tau = NA_real_,
    S = as.numeric(smk$estimate["S"]),
    p_valor = as.numeric(smk$p.value),
    inclinacao_sen = NA_real_,
    stringsAsFactors = FALSE
  )
}

resumo_tendencia <- dplyr::bind_rows(
  mk_linha(taxas_anuais$casos_sinasc, "SINASC (nascidos vivos Q20-Q28)", "anual"),
  mk_linha(taxas_anuais$internacoes, "SIH-RD (internações Q20-Q28 <1 ano)", "anual"),
  smk_linha(dados$casos_sinasc, "SINASC (nascidos vivos Q20-Q28)"),
  smk_linha(dados$internacoes, "SIH-RD (internações Q20-Q28 <1 ano)")
)
readr::write_csv(resumo_tendencia,
                 file.path(CONFIG$dirs$descritiva, "tendencia_mann_kendall.csv"), na = "")

# -----------------------------------------------------------------------------
# 4. Sazonalidade: taxas por mês-calendário + testes
# -----------------------------------------------------------------------------
# Taxas agrupadas por mês-calendário (soma dos 5 anos de cada mês)
sazon <- dados %>%
  dplyr::group_by(mes) %>%
  dplyr::summarise(casos_sinasc = sum(casos_sinasc), internacoes = sum(internacoes),
                   nascidos = sum(nascidos), .groups = "drop")
ic_sin_s <- taxa_ic(sazon$casos_sinasc, sazon$nascidos)
ic_sih_s <- taxa_ic(sazon$internacoes, sazon$nascidos)
sazon <- sazon %>%
  dplyr::mutate(
    mes_nome = meses_pt[mes],
    taxa_sinasc = ic_sin_s$taxa, sinasc_inf = ic_sin_s$ic_inf, sinasc_sup = ic_sin_s$ic_sup,
    taxa_sih = ic_sih_s$taxa, sih_inf = ic_sih_s$ic_inf, sih_sup = ic_sih_s$ic_sup
  )
readr::write_csv(sazon,
                 file.path(CONFIG$dirs$descritiva, "sazonalidade_mensal.csv"), na = "")

# Testes de sazonalidade
teste_saz <- function(casos, nascidos, desfecho) {
  obs <- tapply(casos, dados$mes, sum)
  qui <- suppressWarnings(stats::chisq.test(obs))
  kw <- stats::kruskal.test(as.numeric(casos) / as.numeric(nascidos) ~ factor(dados$mes))
  m0 <- stats::glm(casos ~ offset(log(nascidos)), family = stats::poisson)
  m1 <- tryCatch(stats::glm(casos ~ factor(dados$mes) + offset(log(nascidos)),
                            family = stats::poisson), error = function(e) NULL)
  lrt_stat <- lrt_gl <- lrt_p <- NA_real_
  if (!is.null(m1)) {
    an <- stats::anova(m0, m1, test = "Chisq")
    lrt_stat <- an$Deviance[2]; lrt_gl <- an$Df[2]; lrt_p <- an$`Pr(>Chi)`[2]
  }
  data.frame(
    desfecho = desfecho,
    teste = c("Qui-quadrado (uniformidade entre meses)",
              "Kruskal-Wallis (taxas por mês)",
              "Razão de verossimilhança (Poisson, efeito de mês)"),
    estatistica = c(as.numeric(qui$statistic), as.numeric(kw$statistic), lrt_stat),
    gl = c(as.numeric(qui$parameter), as.numeric(kw$parameter), lrt_gl),
    p_valor = c(qui$p.value, kw$p.value, lrt_p),
    stringsAsFactors = FALSE
  )
}
resumo_sazonalidade <- dplyr::bind_rows(
  teste_saz(dados$casos_sinasc, dados$nascidos, "SINASC (nascidos vivos Q20-Q28)"),
  teste_saz(dados$internacoes, dados$nascidos, "SIH-RD (internações Q20-Q28 <1 ano)")
)
readr::write_csv(resumo_sazonalidade,
                 file.path(CONFIG$dirs$descritiva, "testes_sazonalidade.csv"), na = "")

# -----------------------------------------------------------------------------
# 5. Decomposição STL (tendência + sazonalidade + resíduo)
# -----------------------------------------------------------------------------
stl_componentes <- function(x, desfecho) {
  fit <- stats::stl(stats::ts(as.numeric(x), start = c(2020, 1), frequency = 12),
                    s.window = "periodic", robust = TRUE)
  s <- fit$time.series
  data.frame(desfecho = desfecho, mes_ano = dados$mes_ano,
             observado = as.numeric(x),
             tendencia = as.numeric(s[, "trend"]),
             sazonal = as.numeric(s[, "seasonal"]),
             residuo = as.numeric(s[, "remainder"]))
}
stl_df <- dplyr::bind_rows(
  stl_componentes(dados$casos_sinasc, "Nascidos vivos Q20-Q28 (SINASC)"),
  stl_componentes(dados$internacoes, "Internações Q20-Q28 <1 ano (SIH-RD)")
)
readr::write_csv(stl_df, file.path(CONFIG$dirs$descritiva, "stl_decomposicao.csv"), na = "")

# -----------------------------------------------------------------------------
# 6. Figuras
# -----------------------------------------------------------------------------
salvar <- function(plot, nome, largura = 8, altura = 5) {
  ggsave(file.path(CONFIG$dirs$descritiva, nome), plot = plot,
         width = largura, height = altura, dpi = 300)
  invisible(plot)
}

# 6.1 Taxas mensais (por 10.000 nascidos vivos) com IC 95%
largo <- dplyr::bind_rows(
  taxas_mensais %>% dplyr::transmute(mes_ano, desfecho = "Nascidos vivos Q20-Q28 (SINASC)",
                                     taxa = taxa_sinasc, inf = sinasc_inf, sup = sinasc_sup),
  taxas_mensais %>% dplyr::transmute(mes_ano, desfecho = "Internações Q20-Q28 <1 ano (SIH-RD)",
                                     taxa = taxa_sih, inf = sih_inf, sup = sih_sup)
) %>% dplyr::mutate(desfecho = factor(desfecho,
    levels = c("Nascidos vivos Q20-Q28 (SINASC)",
               "Internações Q20-Q28 <1 ano (SIH-RD)")))

fig_taxas <- ggplot(largo, aes(x = mes_ano, y = taxa)) +
  geom_ribbon(aes(ymin = inf, ymax = sup), fill = cor_destaque, alpha = 0.18) +
  geom_line(color = cor_destaque, linewidth = 0.7) +
  geom_point(color = cor_destaque, size = 1.2) +
  facet_wrap(~ desfecho, ncol = 1, scales = "free_y") +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y",
               expand = expansion(mult = c(0.02, 0.02))) +
  labs(title = "Taxas mensais por 10.000 nascidos vivos (IC 95%)",
       subtitle = "Campos dos Goytacazes (RJ), 2020–2024",
       x = "Ano", y = "Taxa por 10.000 nascidos vivos") +
  theme_cellpress()
salvar(fig_taxas, "fig_taxas_mensais.png", largura = 9, altura = 7)

# 6.2 Sazonalidade — taxas por mês-calendário (pontos anuais + taxa agrupada + IC)
pontos_saz <- dplyr::bind_rows(
  dados %>% dplyr::transmute(mes, desfecho = "Nascidos vivos Q20-Q28 (SINASC)",
                             taxa = ic_sin$taxa),
  dados %>% dplyr::transmute(mes, desfecho = "Internações Q20-Q28 <1 ano (SIH-RD)",
                             taxa = ic_sih$taxa)
) %>% dplyr::mutate(desfecho = factor(desfecho,
    levels = c("Nascidos vivos Q20-Q28 (SINASC)",
               "Internações Q20-Q28 <1 ano (SIH-RD)")))

agrup_saz <- dplyr::bind_rows(
  sazon %>% dplyr::transmute(mes, desfecho = "Nascidos vivos Q20-Q28 (SINASC)",
                             taxa = taxa_sinasc, inf = sinasc_inf, sup = sinasc_sup),
  sazon %>% dplyr::transmute(mes, desfecho = "Internações Q20-Q28 <1 ano (SIH-RD)",
                             taxa = taxa_sih, inf = sih_inf, sup = sih_sup)
) %>% dplyr::mutate(desfecho = factor(desfecho,
    levels = c("Nascidos vivos Q20-Q28 (SINASC)",
               "Internações Q20-Q28 <1 ano (SIH-RD)")))

fig_saz <- ggplot() +
  geom_point(data = pontos_saz, aes(x = mes, y = taxa), color = "grey55", size = 1.2,
             alpha = 0.7, position = position_jitter(width = 0.12, seed = 1)) +
  geom_errorbar(data = agrup_saz, aes(x = mes, ymin = inf, ymax = sup),
                width = 0.2, color = cor_destaque) +
  geom_point(data = agrup_saz, aes(x = mes, y = taxa), color = cor_destaque, size = 2.2) +
  geom_line(data = agrup_saz, aes(x = mes, y = taxa), color = cor_destaque,
            linewidth = 0.5, alpha = 0.6) +
  facet_wrap(~ desfecho, ncol = 1, scales = "free_y") +
  scale_x_continuous(breaks = 1:12, labels = meses_pt) +
  labs(title = "Sazonalidade — taxa por mês-calendário (IC 95%)",
       subtitle = "Pontos cinza = taxas de cada ano; pontos verdes = taxa agrupada (5 anos)",
       x = "Mês", y = "Taxa por 10.000 nascidos vivos") +
  theme_cellpress()
salvar(fig_saz, "fig_sazonalidade_mensal.png", largura = 9, altura = 7)

# 6.3 Decomposição STL
stl_longo <- stl_df %>%
  tidyr::pivot_longer(c(tendencia, sazonal, residuo),
                      names_to = "componente", values_to = "valor") %>%
  dplyr::mutate(componente = factor(componente,
    levels = c("tendencia", "sazonal", "residuo"),
    labels = c("Tendência", "Sazonalidade", "Resíduo")))

fig_stl <- ggplot(stl_longo, aes(x = mes_ano, y = valor)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey70") +
  geom_line(color = cor_destaque, linewidth = 0.6) +
  facet_grid(desfecho ~ componente, scales = "free_y") +
  scale_x_date(date_breaks = "2 years", date_labels = "%Y") +
  labs(title = "Decomposição STL das taxas mensais (por 10.000 nascidos vivos)",
       subtitle = "Componentes: tendência, sazonalidade e resíduo",
       x = "Ano", y = "Componente da taxa") +
  theme_cellpress(base_size = 7)
salvar(fig_stl, "fig_decomposicao_stl.png", largura = 10, altura = 6)

# -----------------------------------------------------------------------------
# 7. Resumo no console
# -----------------------------------------------------------------------------
cat("\n===== SÉRIES TEMPORAIS: TENDÊNCIA E SAZONALIDADE =====\n\n")
cat("Taxas anuais por 10.000 nascidos vivos (IC 95%):\n")
print(as.data.frame(taxas_anuais %>%
  dplyr::transmute(ano, nascidos,
                   SINASC = sprintf("%.1f (%.1f-%.1f)", taxa_sinasc, sinasc_inf, sinasc_sup),
                   SIH = sprintf("%.1f (%.1f-%.1f)", taxa_sih, sih_inf, sih_sup))),
  row.names = FALSE)
cat("\nTestes de tendência:\n")
print(resumo_tendencia, row.names = FALSE)
cat("\nTestes de sazonalidade:\n")
print(resumo_sazonalidade, row.names = FALSE)
cat("\nArquivos salvos em:", CONFIG$dirs$descritiva, "\n")
