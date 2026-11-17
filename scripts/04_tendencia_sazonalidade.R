# =============================================================================
# 04_tendencia_sazonalidade.R
# Análise de tendência e sazonalidade — 2010–2019
#
#   Tendência:
#     - Séries anuais  -> Mann-Kendall (trend::mk.test)
#     - Séries mensais -> Seasonal Mann-Kendall / Hirsch-Slack (trend::smk.test)
#   Sazonalidade:
#     - STL das exposições (temperatura, umidade, PM2,5)
#     - Razão de verossimilhança (Poisson com/sem efeito de mês) nos desfechos
#     - Complementares: qui-quadrado (desfechos) e Kruskal-Wallis (exposições)
#
# Saídas:
#   results/tables/testes_tendencia.csv
#   results/tables/testes_sazonalidade.csv
#   results/figures/ (séries temporais, STL, boxplots)
#
# Uso: Rscript scripts/04_tendencia_sazonalidade.R  (ou via run_all.R)
# =============================================================================

if (basename(getwd()) == "scripts" && file.exists("00_config.R")) setwd("..")
stopifnot(file.exists("scripts/00_config.R"))
source("scripts/00_config.R")
source("scripts/00_utils.R")
source("scripts/03_funcoes_analise.R")
garantir_diretorios()

for (p in c("dplyr", "tidyr", "readr", "lubridate", "ggplot2", "trend",
            "Kendall", "viridisLite")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  suppressPackageStartupMessages(library(p, character.only = TRUE))
}

# -----------------------------------------------------------------------------
# 1. Dados (2010–2019)
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

base_mensal <- montar_base_mensal(CONFIG$anos, sin_q20q26, sin_q20q28,
                                  sih_q20q26, sih_q20q28, totais)

temp_umid <- readr::read_csv(CONFIG$arquivos$temp_umidade_mensal,
                             show_col_types = FALSE)
pm25      <- readr::read_csv(CONFIG$arquivos$pm25_mensal,
                             show_col_types = FALSE)
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
# 2. Tendência e sazonalidade
# -----------------------------------------------------------------------------
testes_tendencia <- rodar_tendencia(base_mensal, CONFIG$ano_inicio)
testes_saz      <- rodar_sazonalidade(base_mensal, exposicoes)

readr::write_csv(testes_tendencia, CONFIG$tabelas$testes_tendencia, na = "")
readr::write_csv(testes_saz,      CONFIG$tabelas$testes_sazonalidade, na = "")

# -----------------------------------------------------------------------------
# 3. STL das exposições e figuras
# -----------------------------------------------------------------------------
decompor_stl(exposicoes$temp_media_c, "Temperatura média (°C)",
             file.path(CONFIG$dirs$figuras, "fig_stl_temperatura.png"),
             CONFIG$ano_inicio, CONFIG$ano_fim,
             "INMET A607 · Campos dos Goytacazes · 2010–2019")
decompor_stl(exposicoes$umidade_media_pct, "Umidade relativa (%)",
             file.path(CONFIG$dirs$figuras, "fig_stl_umidade.png"),
             CONFIG$ano_inicio, CONFIG$ano_fim,
             "INMET A607 · Campos dos Goytacazes · 2010–2019")
decompor_stl(exposicoes$pm25, "PM2,5 (µg/m³)",
             file.path(CONFIG$dirs$figuras, "fig_stl_pm25.png"),
             CONFIG$ano_inicio, CONFIG$ano_fim,
             "VIGIAR-MS · Campos dos Goytacazes · 2010–2019")

salvar_figuras(base_mensal, exposicoes, CONFIG$dirs$figuras, "2010–2019")

# -----------------------------------------------------------------------------
# 4. Resumo no console
# -----------------------------------------------------------------------------
cat("\n========== TENDÊNCIA E SAZONALIDADE — CONCLUÍDO ==========\n")
cat("\nTestes de tendência:\n")
print(as.data.frame(testes_tendencia))
cat("\nTestes de sazonalidade:\n")
print(as.data.frame(testes_saz))
cat("\nFiguras geradas em results/figures/:\n")
cat("  fig_serie_temporal_desfechos.png\n")
cat("  fig_serie_temporal_exposicoes.png\n")
cat("  fig_boxplot_exposicoes_mensais.png\n")
cat("  fig_stl_temperatura.png / fig_stl_umidade.png / fig_stl_pm25.png\n")
cat("===========================================================\n")
