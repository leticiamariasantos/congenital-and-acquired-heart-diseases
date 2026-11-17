# =============================================================================
# 01_download_process_datasus.R
# Download e processamento dos DESFECHOS de saúde (DATASUS) — 2010–2019
#
# Critérios (idênticos aos de 2020–2024, ver scripts/01_funcoes_datasus.R):
#   SIH-RD : internações de menores de 1 ano, residentes em Campos dos
#            Goytacazes (330100), com diagnóstico principal OU secundário em
#            Q20–Q26 (desfecho principal) e Q20–Q28 (sensibilidade).
#   SINASC : nascidos vivos residentes com CODANOMAL contendo Q20–Q26 / Q20–Q28,
#            além do total de nascidos vivos (denominador).
#
# Saídas (data/processed/):
#   internacoes_q20q26_campos.csv
#   internacoes_q20q28_campos.csv
#   nascidos_malformacao_q20q26_campos.csv
#   nascidos_malformacao_q20q28_campos.csv
#   nascidos_totais_campos.csv
#
# Uso: Rscript scripts/01_download_process_datasus.R  (ou via run_all.R)
# =============================================================================

# -----------------------------------------------------------------------------
# 0. Ambiente
# -----------------------------------------------------------------------------
if (basename(getwd()) == "scripts" && file.exists("00_config.R")) setwd("..")
stopifnot(file.exists("scripts/00_config.R"))
source("scripts/00_config.R")
source("scripts/00_utils.R")
source("scripts/01_funcoes_datasus.R")
garantir_diretorios()

for (p in c("microdatasus", "dplyr", "tidyr", "readr", "lubridate", "stringr")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  suppressPackageStartupMessages(library(p, character.only = TRUE))
}

# -----------------------------------------------------------------------------
# 1. Processamento 2010–2019
# -----------------------------------------------------------------------------
cat("============================================================\n")
cat("PIPELINE DATASUS — 2010–2019 | Campos dos Goytacazes (330100)\n")
cat("============================================================\n")

res <- processar_desfechos_periodo(CONFIG$anos)

# -----------------------------------------------------------------------------
# 2. Exportação
# -----------------------------------------------------------------------------
readr::write_csv(res$sih_q20q26, CONFIG$arquivos$internacoes_q20q26, na = "")
readr::write_csv(res$sih_q20q28, CONFIG$arquivos$internacoes_q20q28, na = "")
readr::write_csv(res$sin_q20q26, CONFIG$arquivos$nascidos_malformacao_q20q26, na = "")
readr::write_csv(res$sin_q20q28, CONFIG$arquivos$nascidos_malformacao_q20q28, na = "")
readr::write_csv(res$sin_totais, CONFIG$arquivos$nascidos_totais, na = "")

# -----------------------------------------------------------------------------
# 3. Resumo no console
# -----------------------------------------------------------------------------
cat("\n========== RESULTADO DATASUS — CONCLUÍDO ==========\n")
cat("SINASC casos Q20–Q26 (principal)  :", nrow(res$sin_q20q26), "\n")
cat("SINASC casos Q20–Q28 (sensib.)    :", nrow(res$sin_q20q28), "\n")
cat("SINASC totais de nascidos vivos   :", sum(res$sin_totais$n_nascidos), "\n")
cat("SIH-RD internações Q20–Q26 (princ.):", nrow(res$sih_q20q26), "\n")
cat("SIH-RD internações Q20–Q28 (sensib.):", nrow(res$sih_q20q28), "\n")
cat("\nArquivos gravados em data/processed/: \n")
for (a in names(CONFIG$arquivos)[1:5]) {
  cat("  ", CONFIG$arquivos[[a]], "\n")
}
cat("====================================================\n")
