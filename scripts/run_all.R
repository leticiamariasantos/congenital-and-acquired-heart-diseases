# =============================================================================
# run_all.R
# Executa todo o pipeline da Etapa 1 em ordem.
#
# Uso (a partir da raiz do repositório):
#   Rscript scripts/run_all.R
#
# Etapas:
#   01 - Download e processamento dos desfechos (DATASUS)
#   02 - Download e processamento das exposições (INMET / VIGIAR)
#   03 - Prevalências e razões de internação com IC de Poisson
#   04 - Tendência e sazonalidade
#   05 - Texto de Resultados e Discussão
# =============================================================================

if (basename(getwd()) == "scripts" && file.exists("00_config.R")) setwd("..")
stopifnot(file.exists("scripts/00_config.R"))

t0 <- Sys.time()
cat("============================================================\n")
cat(" PIPELINE ETAPA 1 — 2010–2019 · Campos dos Goytacazes\n")
cat(" Início:", format(t0, "%Y-%m-%d %H:%M:%S"), "\n")
cat("============================================================\n")

scripts <- c(
  "01_download_process_datasus.R",
  "02_download_process_exposures.R",
  "03_prevalencias_razoes_IC.R",
  "04_tendencia_sazonalidade.R",
  "05_generate_results_text.R",
  "06_etapa1_2020_2024.R",
  "08_etapa1_2010_2024.R",
  "07_panorama_2010_2024.R"
)

for (s in scripts) {
  cat(sprintf("\n\n##### Rodando scripts/%s #####\n", s))
  t_script <- Sys.time()
  source(file.path("scripts", s), local = new.env(parent = globalenv()))
  cat(sprintf("##### scripts/%s concluído em %.1f min #####\n", s,
              as.numeric(difftime(Sys.time(), t_script, units = "mins"))))
}

t1 <- Sys.time()
cat("\n============================================================\n")
cat(" PIPELINE CONCLUÍDO\n")
cat(" Término:", format(t1, "%Y-%m-%d %H:%M:%S"), "\n")
cat(" Duração total:", round(as.numeric(difftime(t1, t0, units = "mins")), 1),
    "minutos\n")
cat("============================================================\n")
