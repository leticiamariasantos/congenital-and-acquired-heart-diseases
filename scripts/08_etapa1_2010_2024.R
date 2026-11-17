# =============================================================================
# 08_etapa1_2010_2024.R
# Análise da SÉRIE COMPLETA 2010–2024 (análise principal), com a mesma
# metodologia da Etapa 1:
#   - Desfecho principal Q20–Q26 e sensibilidade Q20–Q28
#   - Taxas por 1.000 nascidos vivos; escalas anual e mensal
#   - IC 95% exato de Poisson; Mann-Kendall e Hirsch-Slack
#   - Sazonalidade: STL + Kruskal-Wallis nas exposições; Poisson (LR) e
#     qui-quadrado nos desfechos
#
# Por eficiência, reutiliza os dados já processados de 2010–2019 e 2020–2024
# (data/processed/*.csv) e apenas os concatena — sem novo download.
#
# Saídas:
#   data/processed/*_2010_2024.csv
#   results/tables/*_2010_2024.csv
#   results/figures_2010_2024/
#   results/text/resultados_discussao_2010_2024.md
#
# Uso: Rscript scripts/08_etapa1_2010_2024.R  (ou via run_all.R)
# =============================================================================

if (basename(getwd()) == "scripts" && file.exists("00_config.R")) setwd("..")
stopifnot(file.exists("scripts/00_config.R"))
source("scripts/00_config.R")
source("scripts/00_utils.R")
source("scripts/03_funcoes_analise.R")
garantir_diretorios()
dir.create(CONFIG$dirs$figuras_2010_2024, recursive = TRUE, showWarnings = FALSE)

for (p in c("dplyr", "tidyr", "readr", "lubridate", "ggplot2", "trend",
            "Kendall", "viridisLite")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  suppressPackageStartupMessages(library(p, character.only = TRUE))
}

anos_completo <- 2010:2024

# Leitores robustos: tudo como caractere e conversão explícita, para evitar
# divergência de tipo entre os CSVs dos dois períodos (ex.: sexo "1" vs 1).
ler_csv_char <- function(caminho) {
  readr::read_csv(caminho, show_col_types = FALSE,
                  col_types = readr::cols(.default = readr::col_character()))
}
ler_casos <- function(caminho) {
  ler_csv_char(caminho) %>%
    dplyr::mutate(dplyr::across(dplyr::any_of(c("ano", "mes")), as.integer))
}
ler_totais <- function(caminho) {
  ler_csv_char(caminho) %>%
    dplyr::mutate(ano = as.integer(ano), mes = as.integer(mes),
                  n_nascidos = as.numeric(n_nascidos))
}
ler_temp_umid <- function(caminho) {
  ler_csv_char(caminho) %>%
    dplyr::mutate(
      mes_ano = as.Date(mes_ano),
      ano = as.integer(ano), mes = as.integer(mes),
      n_dias_mes = as.integer(n_dias_mes),
      n_dias_temp = as.integer(n_dias_temp),
      n_dias_umid = as.integer(n_dias_umid),
      temp_media_c = as.numeric(temp_media_c),
      umidade_media_pct = as.numeric(umidade_media_pct),
      cobertura_temp_pct = as.numeric(cobertura_temp_pct),
      cobertura_umid_pct = as.numeric(cobertura_umid_pct),
      qualidade_ok = as.logical(qualidade_ok)
    )
}
ler_pm25 <- function(caminho) {
  ler_csv_char(caminho) %>%
    dplyr::mutate(mes_ano = as.Date(mes_ano),
                  ano = as.integer(ano), mes = as.integer(mes),
                  pm25 = as.numeric(pm25))
}

# -----------------------------------------------------------------------------
# 1. Concatenação dos desfechos (2010–2019 + 2020–2024)
# -----------------------------------------------------------------------------
cat("Consolidando desfechos 2010–2024 ...\n")

sin_q20q26 <- dplyr::bind_rows(
  ler_casos(CONFIG$arquivos$nascidos_malformacao_q20q26),
  ler_casos(CONFIG$arquivos_2020_2024$nascidos_malformacao_q20q26)
)
sin_q20q28 <- dplyr::bind_rows(
  ler_casos(CONFIG$arquivos$nascidos_malformacao_q20q28),
  ler_casos(CONFIG$arquivos_2020_2024$nascidos_malformacao_q20q28)
)
sih_q20q26 <- dplyr::bind_rows(
  ler_casos(CONFIG$arquivos$internacoes_q20q26),
  ler_casos(CONFIG$arquivos_2020_2024$internacoes_q20q26)
)
sih_q20q28 <- dplyr::bind_rows(
  ler_casos(CONFIG$arquivos$internacoes_q20q28),
  ler_casos(CONFIG$arquivos_2020_2024$internacoes_q20q28)
)
totais <- dplyr::bind_rows(
  ler_totais(CONFIG$arquivos$nascidos_totais),
  ler_totais(CONFIG$arquivos_2020_2024$nascidos_totais)
) %>% dplyr::arrange(mes_ano)

readr::write_csv(sin_q20q26, CONFIG$arquivos_2010_2024$nascidos_malformacao_q20q26, na = "")
readr::write_csv(sin_q20q28, CONFIG$arquivos_2010_2024$nascidos_malformacao_q20q28, na = "")
readr::write_csv(sih_q20q26, CONFIG$arquivos_2010_2024$internacoes_q20q26, na = "")
readr::write_csv(sih_q20q28, CONFIG$arquivos_2010_2024$internacoes_q20q28, na = "")
readr::write_csv(totais,     CONFIG$arquivos_2010_2024$nascidos_totais, na = "")

# -----------------------------------------------------------------------------
# 2. Concatenação das exposições
# -----------------------------------------------------------------------------
cat("Consolidando exposições 2010–2024 ...\n")

temp_umid <- dplyr::bind_rows(
  ler_temp_umid(CONFIG$arquivos$temp_umidade_mensal),
  ler_temp_umid(CONFIG$arquivos_2020_2024$temp_umidade_mensal)
) %>% dplyr::arrange(mes_ano)

pm25 <- dplyr::bind_rows(
  ler_pm25(CONFIG$arquivos$pm25_mensal),
  ler_pm25(CONFIG$arquivos_2020_2024$pm25_mensal)
) %>% dplyr::arrange(mes_ano)

readr::write_csv(temp_umid, CONFIG$arquivos_2010_2024$temp_umidade_mensal, na = "")
readr::write_csv(pm25,      CONFIG$arquivos_2010_2024$pm25_mensal, na = "")

exposicoes <- temp_umid %>%
  dplyr::select(mes_ano, ano, mes, temp_media_c, umidade_media_pct,
                qualidade_ok) %>%
  dplyr::left_join(pm25 %>% dplyr::select(mes_ano, pm25), by = "mes_ano") %>%
  dplyr::mutate(
    temp_media_c      = ifelse(qualidade_ok, temp_media_c, NA_real_),
    umidade_media_pct = ifelse(qualidade_ok, umidade_media_pct, NA_real_)
  ) %>%
  dplyr::arrange(mes_ano)

# -----------------------------------------------------------------------------
# 3. Prevalências e razões (por 1.000, anual e mensal)
# -----------------------------------------------------------------------------
base_mensal <- montar_base_mensal(anos_completo, sin_q20q26, sin_q20q28,
                                  sih_q20q26, sih_q20q28, totais)
tab <- gerar_tabelas(base_mensal)

readr::write_csv(tab$prevalencias_anuais,  CONFIG$tabelas_2010_2024$prevalencias_anuais,  na = "")
readr::write_csv(tab$prevalencias_mensais, CONFIG$tabelas_2010_2024$prevalencias_mensais, na = "")
readr::write_csv(tab$razoes_anuais,        CONFIG$tabelas_2010_2024$razoes_anuais,        na = "")
readr::write_csv(tab$razoes_mensais,       CONFIG$tabelas_2010_2024$razoes_mensais,       na = "")

# -----------------------------------------------------------------------------
# 4. Tendência e sazonalidade
# -----------------------------------------------------------------------------
testes_tendencia <- rodar_tendencia(base_mensal, min(anos_completo))
testes_saz      <- rodar_sazonalidade(base_mensal, exposicoes)

readr::write_csv(testes_tendencia, CONFIG$tabelas_2010_2024$testes_tendencia, na = "")
readr::write_csv(testes_saz,      CONFIG$tabelas_2010_2024$testes_sazonalidade, na = "")

# -----------------------------------------------------------------------------
# 5. STL das exposições e figuras
# -----------------------------------------------------------------------------
f <- CONFIG$dirs$figuras_2010_2024
decompor_stl(exposicoes$temp_media_c, "Temperatura média (°C)",
             file.path(f, "fig_stl_temperatura_2010_2024.png"),
             2010, 2024, "INMET A607 · Campos dos Goytacazes · 2010–2024")
decompor_stl(exposicoes$umidade_media_pct, "Umidade relativa (%)",
             file.path(f, "fig_stl_umidade_2010_2024.png"),
             2010, 2024, "INMET A607 · Campos dos Goytacazes · 2010–2024")
decompor_stl(exposicoes$pm25, "PM2,5 (µg/m³)",
             file.path(f, "fig_stl_pm25_2010_2024.png"),
             2010, 2024, "VIGIAR-MS · Campos dos Goytacazes · 2010–2024")

salvar_figuras(base_mensal, exposicoes, f, "2010–2024")

# -----------------------------------------------------------------------------
# 6. Texto de resultados (série completa)
# -----------------------------------------------------------------------------
fmt <- function(x, d = 2) formatC(x, digits = d, format = "f",
                                  decimal.mark = ",", big.mark = ".")
fmt_int <- function(x) prettyNum(x, big.mark = ".", decimal.mark = ",")

nasc <- sum(totais$n_nascidos)
casos_q26 <- sum(sin_q20q26$ano %in% anos_completo)
casos_q28 <- sum(sin_q20q28$ano %in% anos_completo)
int_q26   <- sum(sih_q20q26$ano %in% anos_completo)
int_q28   <- sum(sih_q20q28$ano %in% anos_completo)

ic <- function(x) ic_poisson_exato(x, mult = 1000 / nasc)

linhas <- c(
  "# Resultados e Discussão — Série completa 2010–2024 (Etapa 1)",
  "",
  "**Desfechos:** nascidos vivos com malformações congênitas do aparelho",
  "circulatório (SINASC) e internações de menores de 1 ano (SIH-RD).",
  "**Município:** Campos dos Goytacazes (IBGE 3301009), Rio de Janeiro.",
  "**Período:** 2010–2024, analisado como série única.",
  "",
  "---",
  "",
  "## 1. Síntese (2010–2024)",
  "",
  sprintf("Em 15 anos, foram registrados **%s nascidos vivos** residentes.",
          fmt_int(nasc)),
  sprintf("No desfecho principal (Q20–Q26), foram **%s casos** no SINASC —",
          fmt_int(casos_q26)),
  sprintf("prevalência de **%s por 1.000** (IC 95%%: %s–%s) — e **%s",
          fmt(1000 * casos_q26 / nasc),
          fmt(ic(casos_q26)$ic95_inf), fmt(ic(casos_q26)$ic95_sup),
          fmt_int(int_q26)),
  sprintf("internações** de menores de 1 ano (razão %s‰; IC 95%%: %s–%s).",
          fmt(1000 * int_q26 / nasc),
          fmt(ic(int_q26)$ic95_inf), fmt(ic(int_q26)$ic95_sup)),
  sprintf("Na análise de sensibilidade (Q20–Q28), foram **%s casos**",
          fmt_int(casos_q28)),
  sprintf("(prevalência %s‰; IC 95%%: %s–%s) e **%s internações**",
          fmt(1000 * casos_q28 / nasc),
          fmt(ic(casos_q28)$ic95_inf), fmt(ic(casos_q28)$ic95_sup),
          fmt_int(int_q28)),
  sprintf("(razão %s‰; IC 95%%: %s–%s).",
          fmt(1000 * int_q28 / nasc),
          fmt(ic(int_q28)$ic95_inf), fmt(ic(int_q28)$ic95_sup)),
  "",
  "## 2. Prevalência anual por 1.000 nascidos vivos",
  "",
  "| Ano | Casos Q20–Q26 | Casos Q20–Q28 | Nascidos vivos | Prevalência Q20–Q26 (‰) | IC 95% |",
  "|-----|---------------|---------------|----------------|-------------------------|--------|",
  apply(tab$prevalencias_anuais %>%
          dplyr::filter(conjunto == "Q20-Q26 (principal)") %>%
          dplyr::left_join(
            tab$prevalencias_anuais %>%
              dplyr::filter(conjunto == "Q20-Q28 (sensibilidade)") %>%
              dplyr::select(ano, casos_q28 = casos),
            by = "ano"), 1, function(r) {
    sprintf("| %s | %s | %s | %s | %s | %s–%s |",
            r["ano"], r["casos"], r["casos_q28"], r["denominador"],
            fmt(as.numeric(r["prevalencia_por_1000"])),
            fmt(as.numeric(r["ic95_inf"])), fmt(as.numeric(r["ic95_sup"])))
  }),
  "",
  "## 3. Tendência",
  "",
  "| Indicador | Conjunto | Escala | Teste | tau | p-valor |",
  "|-----------|----------|--------|-------|-----|---------|",
  apply(testes_tendencia, 1, function(r) {
    tau <- ifelse(is.na(r["tau"]), "—", fmt(as.numeric(r["tau"])))
    sprintf("| %s | %s | %s | %s | %s | %s |",
            r["indicador"], r["conjunto"], r["escala"], r["teste"], tau,
            fmt(as.numeric(r["p_valor"]), d = 4))
  }),
  "",
  "## 4. Sazonalidade",
  "",
  "| Indicador | Teste | Estatística | gl | p-valor |",
  "|-----------|-------|-------------|----|---------|",
  apply(testes_saz, 1, function(r) {
    sprintf("| %s | %s | %s | %s | %s |",
            r["indicador"], r["teste"], fmt(as.numeric(r["estatistica"])),
            r["df"], fmt(as.numeric(r["p_valor"]), d = 4))
  }),
  "",
  "---",
  "",
  "*Documento gerado automaticamente pelo script",
  " `scripts/08_etapa1_2010_2024.R`.*"
)

writeLines(paste(linhas, collapse = "\n"), CONFIG$tabelas_2010_2024$texto)

# -----------------------------------------------------------------------------
# 7. Resumo no console
# -----------------------------------------------------------------------------
cat("\n========== ETAPA 1 (2010–2024, SÉRIE COMPLETA) — CONCLUÍDA ==========\n")
cat(sprintf("Nascidos vivos: %s\n", fmt_int(nasc)))
cat(sprintf("SINASC Q20–Q26: %s | Q20–Q28: %s\n", casos_q26, casos_q28))
cat(sprintf("SIH    Q20–Q26: %s | Q20–Q28: %s\n", int_q26, int_q28))
cat(sprintf("Prevalência Q20–Q26: %s‰ (IC %s–%s)\n",
            fmt(1000 * casos_q26 / nasc), fmt(ic(casos_q26)$ic95_inf),
            fmt(ic(casos_q26)$ic95_sup)))
cat(sprintf("Razão de internação Q20–Q26: %s‰ (IC %s–%s)\n",
            fmt(1000 * int_q26 / nasc), fmt(ic(int_q26)$ic95_inf),
            fmt(ic(int_q26)$ic95_sup)))
cat("\nTestes de tendência:\n")
print(as.data.frame(testes_tendencia))
cat("\nTestes de sazonalidade:\n")
print(as.data.frame(testes_saz))
cat("=================================================================\n")
