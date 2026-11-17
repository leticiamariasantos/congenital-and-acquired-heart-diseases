# =============================================================================
# 07_panorama_2010_2024.R
# Consolida a Etapa 1 dos dois períodos (2010–2019 e 2020–2024) em um
# panorama único 2010–2024, com tabelas anuais/mensais combinadas e um texto
# de Resultados e Discussão consolidado.
#
# Saídas:
#   results/tables/panorama_*_2010_2024.csv
#   results/text/resultados_discussao_panorama_2010_2024.md
#
# Uso: Rscript scripts/07_panorama_2010_2024.R  (ou via run_all.R)
# =============================================================================

if (basename(getwd()) == "scripts" && file.exists("00_config.R")) setwd("..")
stopifnot(file.exists("scripts/00_config.R"))
source("scripts/00_config.R")
source("scripts/00_utils.R")
garantir_diretorios()

for (p in c("dplyr", "tidyr", "readr")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  suppressPackageStartupMessages(library(p, character.only = TRUE))
}

fmt <- function(x, d = 2) formatC(x, digits = d, format = "f",
                                  decimal.mark = ",", big.mark = ".")
fmt_int <- function(x) prettyNum(x, big.mark = ".", decimal.mark = ",")

# -----------------------------------------------------------------------------
# 1. Leitura das tabelas dos dois períodos
# -----------------------------------------------------------------------------
ler <- function(caminho) readr::read_csv(caminho, show_col_types = FALSE)

prev_anual_1019 <- ler(CONFIG$tabelas$prevalencias_anuais)
prev_anual_2024 <- ler(CONFIG$tabelas_2020_2024$prevalencias_anuais)
razao_anual_1019 <- ler(CONFIG$tabelas$razoes_anuais)
razao_anual_2024 <- ler(CONFIG$tabelas_2020_2024$razoes_anuais)
prev_mensal_1019 <- ler(CONFIG$tabelas$prevalencias_mensais)
prev_mensal_2024 <- ler(CONFIG$tabelas_2020_2024$prevalencias_mensais)
razao_mensal_1019 <- ler(CONFIG$tabelas$razoes_mensais)
razao_mensal_2024 <- ler(CONFIG$tabelas_2020_2024$razoes_mensais)

tend_1019 <- ler(CONFIG$tabelas$testes_tendencia)
tend_2024 <- ler(CONFIG$tabelas_2020_2024$testes_tendencia)
saz_1019  <- ler(CONFIG$tabelas$testes_sazonalidade)
saz_2024  <- ler(CONFIG$tabelas_2020_2024$testes_sazonalidade)

# -----------------------------------------------------------------------------
# 2. Consolidação com marcador de período
# -----------------------------------------------------------------------------
marcar <- function(df, periodo) dplyr::mutate(df, periodo = periodo)

prev_anual <- dplyr::bind_rows(
  marcar(prev_anual_1019, "2010-2019"),
  marcar(prev_anual_2024, "2020-2024")
) %>% dplyr::arrange(conjunto, ano)

razao_anual <- dplyr::bind_rows(
  marcar(razao_anual_1019, "2010-2019"),
  marcar(razao_anual_2024, "2020-2024")
) %>% dplyr::arrange(conjunto, ano)

prev_mensal <- dplyr::bind_rows(
  marcar(prev_mensal_1019, "2010-2019"),
  marcar(prev_mensal_2024, "2020-2024")
) %>% dplyr::arrange(conjunto, mes_ano)

razao_mensal <- dplyr::bind_rows(
  marcar(razao_mensal_1019, "2010-2019"),
  marcar(razao_mensal_2024, "2020-2024")
) %>% dplyr::arrange(conjunto, mes_ano)

readr::write_csv(prev_anual,  CONFIG$panorama$prevalencias_anuais,  na = "")
readr::write_csv(prev_mensal, CONFIG$panorama$prevalencias_mensais, na = "")
readr::write_csv(razao_anual, CONFIG$panorama$razoes_anuais,        na = "")
readr::write_csv(razao_mensal, CONFIG$panorama$razoes_mensais,      na = "")

# -----------------------------------------------------------------------------
# 3. Números-chave por período
# -----------------------------------------------------------------------------
resumo_periodo <- function(prev, razao, periodo_rotulo) {
  p <- prev %>% dplyr::filter(periodo == periodo_rotulo)
  r <- razao %>% dplyr::filter(periodo == periodo_rotulo)
  data.frame(
    periodo = periodo_rotulo,
    nascidos = sum(p$denominador[p$conjunto == unique(p$conjunto)[1]]),
    casos_q26 = sum(p$casos[p$conjunto == "Q20-Q26 (principal)"]),
    casos_q28 = sum(p$casos[p$conjunto == "Q20-Q28 (sensibilidade)"]),
    intern_q26 = sum(r$internacoes[r$conjunto == "Q20-Q26 (principal)"]),
    intern_q28 = sum(r$internacoes[r$conjunto == "Q20-Q28 (sensibilidade)"])
  )
}

resumo <- dplyr::bind_rows(
  resumo_periodo(prev_anual, razao_anual, "2010-2019"),
  resumo_periodo(prev_anual, razao_anual, "2020-2024")
) %>%
  dplyr::mutate(
    prev_q26 = 1000 * casos_q26 / nascidos,
    prev_q28 = 1000 * casos_q28 / nascidos,
    razao_q26 = 1000 * intern_q26 / nascidos,
    razao_q28 = 1000 * intern_q28 / nascidos
  )

# -----------------------------------------------------------------------------
# 4. Tabelas Markdown
# -----------------------------------------------------------------------------
md_tabela_prev <- function(df) {
  linhas <- apply(df, 1, function(r) {
    sprintf("| %s | %s | %s | %s | %s | %s–%s |",
            r["ano"], r["periodo"], r["casos"], r["denominador"],
            fmt(as.numeric(r["prevalencia_por_1000"])),
            fmt(as.numeric(r["ic95_inf"])), fmt(as.numeric(r["ic95_sup"])))
  })
  c("| Ano | Período | Casos | Nascidos vivos | Prevalência (‰) | IC 95% (Poisson) |",
    "|-----|---------|-------|----------------|-----------------|------------------|",
    linhas)
}

md_tabela_razao <- function(df) {
  linhas <- apply(df, 1, function(r) {
    sprintf("| %s | %s | %s | %s | %s | %s–%s |",
            r["ano"], r["periodo"], r["internacoes"], r["denominador"],
            fmt(as.numeric(r["razao_internacao_por_1000"])),
            fmt(as.numeric(r["ic95_inf"])), fmt(as.numeric(r["ic95_sup"])))
  })
  c("| Ano | Período | Internações | Nascidos vivos | Razão (‰) | IC 95% (Poisson) |",
    "|-----|---------|-------------|----------------|-----------|------------------|",
    linhas)
}

ic_global <- function(casos, nasc) {
  ic_poisson_exato(casos, mult = 1000 / nasc)
}

res_1019 <- resumo[resumo$periodo == "2010-2019", ]
res_2024 <- resumo[resumo$periodo == "2020-2024", ]

# -----------------------------------------------------------------------------
# 5. Texto consolidado
# -----------------------------------------------------------------------------
linhas <- c(
  "# Resultados e Discussão — Panorama 2010–2024 (Etapa 1)",
  "",
  "**Desfechos:** nascidos vivos com malformações congênitas do aparelho",
  "circulatório (SINASC) e internações de menores de 1 ano (SIH-RD).",
  "**Município:** Campos dos Goytacazes (IBGE 3301009), Rio de Janeiro.",
  "**Períodos:** 2010–2019 e 2020–2024, analisados com a MESMA metodologia",
  "(desfecho principal Q20–Q26; sensibilidade Q20–Q28; taxas por 1.000 nascidos",
  "vivos; IC 95% exato de Poisson; escalas anual e mensal).",
  "",
  "---",
  "",
  "## 1. Síntese dos dois períodos",
  "",
  "| Período | Nascidos vivos | Casos Q20–Q26 | Casos Q20–Q28 | Internações Q20–Q26 | Internações Q20–Q28 |",
  "|---------|----------------|---------------|---------------|---------------------|---------------------|",
  sprintf("| 2010–2019 | %s | %s | %s | %s | %s |",
          fmt_int(res_1019$nascidos), fmt_int(res_1019$casos_q26),
          fmt_int(res_1019$casos_q28), fmt_int(res_1019$intern_q26),
          fmt_int(res_1019$intern_q28)),
  sprintf("| 2020–2024 | %s | %s | %s | %s | %s |",
          fmt_int(res_2024$nascidos), fmt_int(res_2024$casos_q26),
          fmt_int(res_2024$casos_q28), fmt_int(res_2024$intern_q26),
          fmt_int(res_2024$intern_q28)),
  "",
  "## 2. Prevalência (por 1.000 nascidos vivos)",
  "",
  sprintf("**2010–2019:** Q20–Q26 = %s‰ (IC 95%% %s–%s); Q20–Q28 = %s‰ (IC 95%% %s–%s).",
          fmt(res_1019$prev_q26),
          fmt(ic_global(res_1019$casos_q26, res_1019$nascidos)$ic95_inf),
          fmt(ic_global(res_1019$casos_q26, res_1019$nascidos)$ic95_sup),
          fmt(res_1019$prev_q28),
          fmt(ic_global(res_1019$casos_q28, res_1019$nascidos)$ic95_inf),
          fmt(ic_global(res_1019$casos_q28, res_1019$nascidos)$ic95_sup)),
  sprintf("**2020–2024:** Q20–Q26 = %s‰ (IC 95%% %s–%s); Q20–Q28 = %s‰ (IC 95%% %s–%s).",
          fmt(res_2024$prev_q26),
          fmt(ic_global(res_2024$casos_q26, res_2024$nascidos)$ic95_inf),
          fmt(ic_global(res_2024$casos_q26, res_2024$nascidos)$ic95_sup),
          fmt(res_2024$prev_q28),
          fmt(ic_global(res_2024$casos_q28, res_2024$nascidos)$ic95_inf),
          fmt(ic_global(res_2024$casos_q28, res_2024$nascidos)$ic95_sup)),
  "",
  "## 3. Razão de internação (por 1.000 nascidos vivos)",
  "",
  sprintf("**2010–2019:** Q20–Q26 = %s‰ (IC 95%% %s–%s); Q20–Q28 = %s‰ (IC 95%% %s–%s).",
          fmt(res_1019$razao_q26),
          fmt(ic_global(res_1019$intern_q26, res_1019$nascidos)$ic95_inf),
          fmt(ic_global(res_1019$intern_q26, res_1019$nascidos)$ic95_sup),
          fmt(res_1019$razao_q28),
          fmt(ic_global(res_1019$intern_q28, res_1019$nascidos)$ic95_inf),
          fmt(ic_global(res_1019$intern_q28, res_1019$nascidos)$ic95_sup)),
  sprintf("**2020–2024:** Q20–Q26 = %s‰ (IC 95%% %s–%s); Q20–Q28 = %s‰ (IC 95%% %s–%s).",
          fmt(res_2024$razao_q26),
          fmt(ic_global(res_2024$intern_q26, res_2024$nascidos)$ic95_inf),
          fmt(ic_global(res_2024$intern_q26, res_2024$nascidos)$ic95_sup),
          fmt(res_2024$razao_q28),
          fmt(ic_global(res_2024$intern_q28, res_2024$nascidos)$ic95_inf),
          fmt(ic_global(res_2024$intern_q28, res_2024$nascidos)$ic95_sup)),
  "",
  "### Prevalência anual — Q20–Q26 (principal)",
  "",
  md_tabela_prev(prev_anual %>% dplyr::filter(conjunto == "Q20-Q26 (principal)")),
  "",
  "### Prevalência anual — Q20–Q28 (sensibilidade)",
  "",
  md_tabela_prev(prev_anual %>% dplyr::filter(conjunto == "Q20-Q28 (sensibilidade)")),
  "",
  "### Razão de internação anual — Q20–Q26 (principal)",
  "",
  md_tabela_razao(razao_anual %>% dplyr::filter(conjunto == "Q20-Q26 (principal)")),
  "",
  "### Razão de internação anual — Q20–Q28 (sensibilidade)",
  "",
  md_tabela_razao(razao_anual %>% dplyr::filter(conjunto == "Q20-Q28 (sensibilidade)")),
  "",
  "## 4. Tendência e sazonalidade (comparativo)",
  "",
  "### Tendência",
  "",
  "| Período | Indicador | Escala | Teste | p-valor |",
  "|---------|-----------|--------|-------|---------|",
  apply(dplyr::bind_rows(
    tend_1019 %>% dplyr::mutate(periodo = "2010-2019"),
    tend_2024 %>% dplyr::mutate(periodo = "2020-2024")
  ), 1, function(r) {
    sprintf("| %s | %s | %s | %s | %s |", r["periodo"], r["indicador"],
            r["escala"], r["teste"], fmt(as.numeric(r["p_valor"]), d = 4))
  }),
  "",
  "### Sazonalidade",
  "",
  "| Período | Indicador | Teste | p-valor |",
  "|---------|-----------|-------|---------|",
  apply(dplyr::bind_rows(
    saz_1019 %>% dplyr::mutate(periodo = "2010-2019"),
    saz_2024 %>% dplyr::mutate(periodo = "2020-2024")
  ), 1, function(r) {
    sprintf("| %s | %s | %s | %s |", r["periodo"], r["indicador"],
            r["teste"], fmt(as.numeric(r["p_valor"]), d = 4))
  }),
  "",
  "---",
  "",
  "*Documento gerado automaticamente pelo script",
  " `scripts/07_panorama_2010_2024.R`.*"
)

texto <- paste(linhas, collapse = "\n")
writeLines(texto, CONFIG$panorama$texto)

cat("Panorama gravado em:\n")
for (a in names(CONFIG$panorama)) cat("  ", CONFIG$panorama[[a]], "\n")
cat("\nResumo por período:\n")
print(as.data.frame(resumo))
