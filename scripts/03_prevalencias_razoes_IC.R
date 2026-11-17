# =============================================================================
# 03_prevalencias_razoes_IC.R
# Prevalências e razões de internação (por 1.000) com IC 95% exato de Poisson
#
#   Prevalência = (casos SINASC / total de nascidos vivos) × 1.000
#   Razão de internação = (internações SIH < 1 ano / total de nascidos vivos) × 1.000
#
# Escalas: anual e mensal. Conjuntos: Q20–Q26 (principal) e Q20–Q28
# (sensibilidade). IC exato de Poisson (Garwood, 1936).
#
# Saídas (results/tables/):
#   prevalencias_anuais.csv, prevalencias_mensais.csv,
#   razoes_internacao_anuais.csv, razoes_internacao_mensais.csv
#
# Uso: Rscript scripts/03_prevalencias_razoes_IC.R  (ou via run_all.R)
# =============================================================================

if (basename(getwd()) == "scripts" && file.exists("00_config.R")) setwd("..")
stopifnot(file.exists("scripts/00_config.R"))
source("scripts/00_config.R")
source("scripts/00_utils.R")
source("scripts/03_funcoes_analise.R")
garantir_diretorios()

for (p in c("dplyr", "tidyr", "readr", "lubridate")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  suppressPackageStartupMessages(library(p, character.only = TRUE))
}

# -----------------------------------------------------------------------------
# 1. Leitura dos dados processados (2010–2019)
# -----------------------------------------------------------------------------
sin_q20q26 <- readr::read_csv(CONFIG$arquivos$nascidos_malformacao_q20q26,
                              show_col_types = FALSE)
sin_q20q28 <- readr::read_csv(CONFIG$arquivos$nascidos_malformacao_q20q28,
                              show_col_types = FALSE)
sih_q20q26 <- readr::read_csv(CONFIG$arquivos$internacoes_q20q26,
                              show_col_types = FALSE)
sih_q20q28 <- readr::read_csv(CONFIG$arquivos$internacoes_q20q28,
                              show_col_types = FALSE)
totais     <- readr::read_csv(CONFIG$arquivos$nascidos_totais,
                              show_col_types = FALSE)

# -----------------------------------------------------------------------------
# 2. Base mensal e tabelas
# -----------------------------------------------------------------------------
base_mensal <- montar_base_mensal(CONFIG$anos, sin_q20q26, sin_q20q28,
                                  sih_q20q26, sih_q20q28, totais)
tab <- gerar_tabelas(base_mensal)

readr::write_csv(tab$prevalencias_anuais,  CONFIG$tabelas$prevalencias_anuais,  na = "")
readr::write_csv(tab$prevalencias_mensais, CONFIG$tabelas$prevalencias_mensais, na = "")
readr::write_csv(tab$razoes_anuais,        CONFIG$tabelas$razoes_anuais,        na = "")
readr::write_csv(tab$razoes_mensais,       CONFIG$tabelas$razoes_mensais,       na = "")

# -----------------------------------------------------------------------------
# 3. Resumo no console
# -----------------------------------------------------------------------------
cat("\n========== PREVALÊNCIAS E RAZÕES — CONCLUÍDO ==========\n")
cat("Prevalências anuais (Q20–Q26) por 1.000 nascidos vivos:\n")
print(tab$prevalencias_anuais %>%
        dplyr::filter(conjunto == "Q20-Q26 (principal)") %>%
        dplyr::select(ano, casos, denominador, prevalencia_por_1000,
                      ic95_inf, ic95_sup), n = Inf)
cat("\nRazões de internação anuais (Q20–Q26) por 1.000 nascidos vivos:\n")
print(tab$razoes_anuais %>%
        dplyr::filter(conjunto == "Q20-Q26 (principal)") %>%
        dplyr::select(ano, internacoes, denominador, razao_internacao_por_1000,
                      ic95_inf, ic95_sup), n = Inf)
cat("\nTotais por conjunto:\n")
print(tab$base_anual %>%
        dplyr::group_by(conjunto) %>%
        dplyr::summarise(casos = sum(casos), internacoes = sum(internacoes),
                         nascidos = sum(n_nascidos), .groups = "drop"), n = Inf)
cat("==========================================================\n")
