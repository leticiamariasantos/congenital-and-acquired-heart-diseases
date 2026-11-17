# =============================================================================
# 03_prevalencias_razoes_IC.R
# Prevalências e razões de internação (por 1.000) com IC 95% exato de Poisson
#
#   Prevalência de malformações congênitas do aparelho circulatório em
#     nascidos vivos = (casos SINASC / total de nascidos vivos) × 1.000
#   Razão de internações de menores de 1 ano = (internações SIH / total de
#     nascidos vivos) × 1.000
#
# Escalas: anual, trimestral e mensal. Conjuntos: Q20–Q26 (principal) e
# Q20–Q28 (sensibilidade). IC exato de Poisson (Garwood, 1936).
#
# Saídas (results/tables/):
#   prevalencias_anuais.csv, prevalencias_trimestrais.csv,
#   prevalencias_mensais.csv, razoes_internacao_anuais.csv,
#   razoes_internacao_trimestrais.csv, razoes_internacao_mensais.csv
#
# Uso: Rscript scripts/03_prevalencias_razoes_IC.R  (ou via run_all.R)
# =============================================================================

if (basename(getwd()) == "scripts" && file.exists("00_config.R")) setwd("..")
stopifnot(file.exists("scripts/00_config.R"))
source("scripts/00_config.R")
source("scripts/00_utils.R")
garantir_diretorios()

for (p in c("dplyr", "tidyr", "readr", "lubridate")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  suppressPackageStartupMessages(library(p, character.only = TRUE))
}

# -----------------------------------------------------------------------------
# 1. Leitura dos dados processados
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

conjuntos <- c("Q20_Q26" = "Q20-Q26 (principal)",
               "Q20_Q28" = "Q20-Q28 (sensibilidade)")

# Grade mensal completa 2010–2019
grade_mensal <- expand.grid(
  ano = CONFIG$anos,
  mes = CONFIG$meses
) %>%
  dplyr::mutate(mes_ano = as.Date(sprintf("%04d-%02d-01", ano, mes))) %>%
  dplyr::arrange(mes_ano)

# -----------------------------------------------------------------------------
# 2. Contagens mensais (casos SINASC, internações SIH e denominador)
# -----------------------------------------------------------------------------
contar_mensal <- function(dados, rotulo) {
  dados %>%
    dplyr::count(ano, mes, name = "n") %>%
    dplyr::mutate(conjunto = rotulo)
}

casos_sinasc <- dplyr::bind_rows(
  contar_mensal(sin_q20q26, "Q20_Q26"),
  contar_mensal(sin_q20q28, "Q20_Q28")
)

internacoes <- dplyr::bind_rows(
  contar_mensal(sih_q20q26, "Q20_Q26"),
  contar_mensal(sih_q20q28, "Q20_Q28")
)

# Junta tudo em uma única base mensal (grade completa x 2 conjuntos)
base_mensal <- expand.grid(
  mes_ano = grade_mensal$mes_ano,
  conjunto = names(conjuntos),
  stringsAsFactors = FALSE
) %>%
  dplyr::mutate(
    ano = lubridate::year(mes_ano),
    mes = lubridate::month(mes_ano),
    trimestre = ceiling(mes / 3)
  ) %>%
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
    casos        = tidyr::replace_na(casos, 0L),
    internacoes  = tidyr::replace_na(internacoes, 0L),
    n_nascidos   = as.numeric(tidyr::replace_na(n_nascidos, NA_real_))
  ) %>%
  dplyr::arrange(conjunto, mes_ano)

# -----------------------------------------------------------------------------
# 3. Cálculo das taxas e ICs exatos de Poisson
# -----------------------------------------------------------------------------
# mult = 1000 / denominador  =>  estimativa = casos * 1000 / denominador
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
  prev <- calcular_taxa(dados, "casos", "n_nascidos")
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

base_mensal <- adicionar_taxas(base_mensal)

# --- Agregação trimestral ------------------------------------------------
base_trimestral <- base_mensal %>%
  dplyr::group_by(ano, trimestre, conjunto) %>%
  dplyr::summarise(
    casos        = sum(casos),
    internacoes  = sum(internacoes),
    n_nascidos   = sum(n_nascidos, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  adicionar_taxas()

# --- Agregação anual -----------------------------------------------------
base_anual <- base_mensal %>%
  dplyr::group_by(ano, conjunto) %>%
  dplyr::summarise(
    casos        = sum(casos),
    internacoes  = sum(internacoes),
    n_nascidos   = sum(n_nascidos, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  adicionar_taxas()

# -----------------------------------------------------------------------------
# 4. Exportação das tabelas
# -----------------------------------------------------------------------------
nome_conjunto <- function(x) unname(conjuntos[x])

# Prevalências
prevalencias_anuais <- base_anual %>%
  dplyr::transmute(ano, conjunto = nome_conjunto(conjunto),
                   casos, denominador = n_nascidos,
                   prevalencia_por_1000,
                   ic95_inf = prevalencia_ic95_inf,
                   ic95_sup = prevalencia_ic95_sup) %>%
  dplyr::arrange(conjunto, ano)

prevalencias_trimestrais <- base_trimestral %>%
  dplyr::transmute(ano, trimestre, conjunto = nome_conjunto(conjunto),
                   casos, denominador = n_nascidos,
                   prevalencia_por_1000,
                   ic95_inf = prevalencia_ic95_inf,
                   ic95_sup = prevalencia_ic95_sup) %>%
  dplyr::arrange(conjunto, ano, trimestre)

prevalencias_mensais <- base_mensal %>%
  dplyr::transmute(mes_ano, ano, mes, conjunto = nome_conjunto(conjunto),
                   casos, denominador = n_nascidos,
                   prevalencia_por_1000,
                   ic95_inf = prevalencia_ic95_inf,
                   ic95_sup = prevalencia_ic95_sup) %>%
  dplyr::arrange(conjunto, mes_ano)

# Razões de internação
razoes_anuais <- base_anual %>%
  dplyr::transmute(ano, conjunto = nome_conjunto(conjunto),
                   internacoes, denominador = n_nascidos,
                   razao_internacao_por_1000,
                   ic95_inf = razao_ic95_inf,
                   ic95_sup = razao_ic95_sup) %>%
  dplyr::arrange(conjunto, ano)

razoes_trimestrais <- base_trimestral %>%
  dplyr::transmute(ano, trimestre, conjunto = nome_conjunto(conjunto),
                   internacoes, denominador = n_nascidos,
                   razao_internacao_por_1000,
                   ic95_inf = razao_ic95_inf,
                   ic95_sup = razao_ic95_sup) %>%
  dplyr::arrange(conjunto, ano, trimestre)

razoes_mensais <- base_mensal %>%
  dplyr::transmute(mes_ano, ano, mes, conjunto = nome_conjunto(conjunto),
                   internacoes, denominador = n_nascidos,
                   razao_internacao_por_1000,
                   ic95_inf = razao_ic95_inf,
                   ic95_sup = razao_ic95_sup) %>%
  dplyr::arrange(conjunto, mes_ano)

readr::write_csv(prevalencias_anuais,      CONFIG$tabelas$prevalencias_anuais,      na = "")
readr::write_csv(prevalencias_trimestrais, CONFIG$tabelas$prevalencias_trimestrais, na = "")
readr::write_csv(prevalencias_mensais,     CONFIG$tabelas$prevalencias_mensais,     na = "")
readr::write_csv(razoes_anuais,            CONFIG$tabelas$razoes_anuais,            na = "")
readr::write_csv(razoes_trimestrais,       CONFIG$tabelas$razoes_trimestrais,       na = "")
readr::write_csv(razoes_mensais,           CONFIG$tabelas$razoes_mensais,           na = "")

# -----------------------------------------------------------------------------
# 5. Resumo no console
# -----------------------------------------------------------------------------
cat("\n========== PREVALÊNCIAS E RAZÕES — CONCLUÍDO ==========\n")
cat("Prevalências anuais (Q20–Q26) por 1.000 nascidos vivos:\n")
print(prevalencias_anuais %>%
        dplyr::filter(conjunto == "Q20-Q26 (principal)") %>%
        dplyr::select(ano, casos, denominador, prevalencia_por_1000,
                      ic95_inf, ic95_sup), n = Inf)
cat("\nRazões de internação anuais (Q20–Q26) por 1.000 nascidos vivos:\n")
print(razoes_anuais %>%
        dplyr::filter(conjunto == "Q20-Q26 (principal)") %>%
        dplyr::select(ano, internacoes, denominador, razao_internacao_por_1000,
                      ic95_inf, ic95_sup), n = Inf)
cat("\nTotais por conjunto:\n")
print(base_anual %>%
        dplyr::group_by(conjunto) %>%
        dplyr::summarise(casos = sum(casos), internacoes = sum(internacoes),
                         nascidos = sum(n_nascidos), .groups = "drop"), n = Inf)
cat("==========================================================\n")
