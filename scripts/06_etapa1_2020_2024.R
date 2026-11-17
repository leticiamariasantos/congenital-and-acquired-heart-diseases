# =============================================================================
# 06_etapa1_2020_2024.R
# Replica a Etapa 1 (2010–2019) para 2020–2024, com a MESMA metodologia:
#   - Desfecho principal Q20–Q26 e sensibilidade Q20–Q28
#   - Taxas por 1.000 nascidos vivos (não por 10.000)
#   - Escalas anual e mensal
#   - IC 95% exato de Poisson; Mann-Kendall e Hirsch-Slack
#   - Sazonalidade: STL + Kruskal-Wallis nas EXPOSIÇÕES; Poisson (LR) e
#     qui-quadrado nos DESFECHOS
#
# Saídas:
#   data/processed/*_2020_2024.csv
#   results/tables/*_2020_2024.csv
#   results/figures_2020_2024/
#
# Uso: Rscript scripts/06_etapa1_2020_2024.R  (ou via run_all.R)
# =============================================================================

if (basename(getwd()) == "scripts" && file.exists("00_config.R")) setwd("..")
stopifnot(file.exists("scripts/00_config.R"))
source("scripts/00_config.R")
source("scripts/00_utils.R")
source("scripts/01_funcoes_datasus.R")
source("scripts/02_funcoes_exposicoes.R")
source("scripts/03_funcoes_analise.R")
garantir_diretorios()
dir.create(CONFIG$dirs$figuras_2020_2024, recursive = TRUE, showWarnings = FALSE)

for (p in c("microdatasus", "dplyr", "tidyr", "readr", "lubridate", "stringr",
            "httr", "ggplot2", "trend", "Kendall", "viridisLite")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  suppressPackageStartupMessages(library(p, character.only = TRUE))
}

anos_2020_2024 <- 2020:2024

# -----------------------------------------------------------------------------
# 1. Desfechos (DATASUS) — 2020–2024
# -----------------------------------------------------------------------------
cat("============================================================\n")
cat("PIPELINE DATASUS — 2020–2024 | Campos dos Goytacazes (330100)\n")
cat("============================================================\n")

res <- processar_desfechos_periodo(anos_2020_2024)

readr::write_csv(res$sih_q20q26, CONFIG$arquivos_2020_2024$internacoes_q20q26, na = "")
readr::write_csv(res$sih_q20q28, CONFIG$arquivos_2020_2024$internacoes_q20q28, na = "")
readr::write_csv(res$sin_q20q26, CONFIG$arquivos_2020_2024$nascidos_malformacao_q20q26, na = "")
readr::write_csv(res$sin_q20q28, CONFIG$arquivos_2020_2024$nascidos_malformacao_q20q28, na = "")
readr::write_csv(res$sin_totais, CONFIG$arquivos_2020_2024$nascidos_totais, na = "")

cat("\n[RESULTADO DATASUS 2020–2024]\n")
cat("SINASC Q20–Q26:", nrow(res$sin_q20q26), "| Q20–Q28:", nrow(res$sin_q20q28),
    "| nascidos:", sum(res$sin_totais$n_nascidos), "\n")
cat("SIH Q20–Q26:", nrow(res$sih_q20q26), "| Q20–Q28:", nrow(res$sih_q20q28), "\n")

# -----------------------------------------------------------------------------
# 2. Exposições — 2020–2024
# -----------------------------------------------------------------------------
cat("\nBaixando/processando INMET A607 e VIGIAR 2020–2024 ...\n")
temp_umid <- processar_temp_umidade(anos_2020_2024)
pm25      <- processar_pm25(anos_2020_2024)

exclusoes <- temp_umid %>%
  dplyr::filter(!qualidade_ok) %>%
  dplyr::select(mes_ano, ano, mes, n_dias_mes, n_dias_temp, n_dias_umid,
                cobertura_temp_pct, cobertura_umid_pct)

readr::write_csv(temp_umid, CONFIG$arquivos_2020_2024$temp_umidade_mensal, na = "")
readr::write_csv(exclusoes, CONFIG$arquivos_2020_2024$temp_umidade_exclusoes, na = "")
readr::write_csv(pm25,      CONFIG$arquivos_2020_2024$pm25_mensal, na = "")

exposicoes <- temp_umid %>%
  dplyr::select(mes_ano, ano, mes, temp_media_c, umidade_media_pct,
                qualidade_ok) %>%
  dplyr::left_join(pm25 %>% dplyr::select(mes_ano, pm25), by = "mes_ano") %>%
  dplyr::mutate(
    temp_media_c      = ifelse(qualidade_ok, temp_media_c, NA_real_),
    umidade_media_pct = ifelse(qualidade_ok, umidade_media_pct, NA_real_)
  ) %>%
  dplyr::arrange(mes_ano)

cat("INMET 2020–2024 meses com qualidade ok:",
    sum(temp_umid$qualidade_ok), "/", nrow(temp_umid), "\n")

# -----------------------------------------------------------------------------
# 3. Prevalências e razões (por 1.000, anual e mensal)
# -----------------------------------------------------------------------------
base_mensal <- montar_base_mensal(anos_2020_2024,
                                  res$sin_q20q26, res$sin_q20q28,
                                  res$sih_q20q26, res$sih_q20q28,
                                  res$sin_totais)
tab <- gerar_tabelas(base_mensal)

readr::write_csv(tab$prevalencias_anuais,  CONFIG$tabelas_2020_2024$prevalencias_anuais,  na = "")
readr::write_csv(tab$prevalencias_mensais, CONFIG$tabelas_2020_2024$prevalencias_mensais, na = "")
readr::write_csv(tab$razoes_anuais,        CONFIG$tabelas_2020_2024$razoes_anuais,        na = "")
readr::write_csv(tab$razoes_mensais,       CONFIG$tabelas_2020_2024$razoes_mensais,       na = "")

# -----------------------------------------------------------------------------
# 4. Tendência e sazonalidade
# -----------------------------------------------------------------------------
testes_tendencia <- rodar_tendencia(base_mensal, min(anos_2020_2024))
testes_saz      <- rodar_sazonalidade(base_mensal, exposicoes)

readr::write_csv(testes_tendencia, CONFIG$tabelas_2020_2024$testes_tendencia, na = "")
readr::write_csv(testes_saz,      CONFIG$tabelas_2020_2024$testes_sazonalidade, na = "")

# -----------------------------------------------------------------------------
# 5. STL das exposições e figuras (diretório próprio)
# -----------------------------------------------------------------------------
f <- CONFIG$dirs$figuras_2020_2024
decompor_stl(exposicoes$temp_media_c, "Temperatura média (°C)",
             file.path(f, "fig_stl_temperatura_2020_2024.png"),
             2020, 2024, "INMET A607 · Campos dos Goytacazes · 2020–2024")
decompor_stl(exposicoes$umidade_media_pct, "Umidade relativa (%)",
             file.path(f, "fig_stl_umidade_2020_2024.png"),
             2020, 2024, "INMET A607 · Campos dos Goytacazes · 2020–2024")
decompor_stl(exposicoes$pm25, "PM2,5 (µg/m³)",
             file.path(f, "fig_stl_pm25_2020_2024.png"),
             2020, 2024, "VIGIAR-MS · Campos dos Goytacazes · 2020–2024")

salvar_figuras(base_mensal, exposicoes, f, "2020–2024")

# -----------------------------------------------------------------------------
# 6. Resumo no console
# -----------------------------------------------------------------------------
cat("\n========== ETAPA 1 (2020–2024) — CONCLUÍDA ==========\n")
cat("Prevalências anuais (Q20–Q26) por 1.000:\n")
print(tab$prevalencias_anuais %>%
        dplyr::filter(conjunto == "Q20-Q26 (principal)"), n = Inf)
cat("\nTestes de tendência:\n")
print(as.data.frame(testes_tendencia))
cat("\nTestes de sazonalidade:\n")
print(as.data.frame(testes_saz))
cat("======================================================\n")
