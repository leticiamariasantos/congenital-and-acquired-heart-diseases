# =============================================================================
# 02_download_process_exposures.R
# Download e processamento das EXPOSIÇÕES ambientais — 2010–2019
#
#   Temperatura e umidade : INMET, estação A607 (Campos dos Goytacazes),
#                           agregação mensal com critério de qualidade
#                           (>= 80% dos dias com registro).
#   PM2,5                  : VIGIAR / Ministério da Saúde (µg/m³).
#
# Saídas (data/processed/):
#   temp_umidade_mensal_A607_2010_2019.csv
#   temp_umidade_mensal_A607_2010_2019_exclusoes.csv
#   pm25_mensal_campos_2010_2019.csv
#
# Uso: Rscript scripts/02_download_process_exposures.R  (ou via run_all.R)
# =============================================================================

# -----------------------------------------------------------------------------
# 0. Ambiente
# -----------------------------------------------------------------------------
if (basename(getwd()) == "scripts" && file.exists("00_config.R")) setwd("..")
stopifnot(file.exists("scripts/00_config.R"))
source("scripts/00_config.R")
source("scripts/00_utils.R")
source("scripts/02_funcoes_exposicoes.R")
garantir_diretorios()

for (p in c("dplyr", "tidyr", "readr", "lubridate", "stringr", "httr")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  suppressPackageStartupMessages(library(p, character.only = TRUE))
}

# -----------------------------------------------------------------------------
# 1. INMET A607 (temperatura e umidade) — 2010–2019
# -----------------------------------------------------------------------------
cat("Baixando/processando INMET A607 2010–2019 ...\n")
temp_umidade_mensal <- processar_temp_umidade(CONFIG$anos)

exclusoes <- temp_umidade_mensal %>%
  dplyr::filter(!qualidade_ok) %>%
  dplyr::select(mes_ano, ano, mes, n_dias_mes, n_dias_temp, n_dias_umid,
                cobertura_temp_pct, cobertura_umid_pct)

readr::write_csv(temp_umidade_mensal, CONFIG$arquivos$temp_umidade_mensal, na = "")
readr::write_csv(exclusoes, CONFIG$arquivos$temp_umidade_exclusoes, na = "")

# -----------------------------------------------------------------------------
# 2. PM2,5 (VIGIAR) — 2010–2019
# -----------------------------------------------------------------------------
cat("Processando PM2,5 (VIGIAR) ...\n")
pm25_mensal <- processar_pm25(CONFIG$anos)
readr::write_csv(pm25_mensal, CONFIG$arquivos$pm25_mensal, na = "")

# -----------------------------------------------------------------------------
# 3. Resumo no console
# -----------------------------------------------------------------------------
cat("\n========== EXPOSIÇÕES — CONCLUÍDO ==========\n")
cat("INMET A607 — meses processados:", nrow(temp_umidade_mensal), "\n")
cat("INMET A607 — meses com qualidade ok:",
    sum(temp_umidade_mensal$qualidade_ok), "\n")
cat("INMET A607 — meses EXCLUÍDOS (cobertura < 80%):", nrow(exclusoes), "\n")
if (nrow(exclusoes) > 0) {
  print(as.data.frame(exclusoes))
}
cat("\nPM2,5 (VIGIAR) — meses:", nrow(pm25_mensal), "\n")
cat("PM2,5 ausentes:", sum(is.na(pm25_mensal$pm25)), "\n")
cat("Resumo PM2,5 (µg/m³):\n")
print(summary(pm25_mensal$pm25))
cat("\nResumo temperatura (°C):\n")
print(summary(temp_umidade_mensal$temp_media_c))
cat("\nResumo umidade (%):\n")
print(summary(temp_umidade_mensal$umidade_media_pct))
cat("=============================================\n")
