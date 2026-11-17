# =============================================================================
# requirements.R
# Instala todas as dependências do projeto.
#
# Uso (a partir da raiz do repositório):
#   Rscript requirements.R
# =============================================================================

pacotes <- c(
  # Acesso e processamento de dados do DATASUS
  "microdatasus",
  # Download de dados externos (INMET) e manipulação
  "httr", "dplyr", "tidyr", "purrr", "tibble", "stringr", "readr", "lubridate",
  # Visualização
  "ggplot2", "scales", "viridisLite",
  # Análise estatística inferencial e de tendência/sazonalidade
  "Kendall", "trend", "Hmisc", "dlnm",
  # Geração de documento Word (seção de resultados)
  "officer", "flextable",
  # Reproducibilidade e metadados
  "digest", "jsonlite"
)

faltantes <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltantes) > 0L) {
  cat("Instalando pacotes faltantes:", paste(faltantes, collapse = ", "), "\n")
  install.packages(faltantes)
} else {
  cat("Todos os pacotes já estão instalados.\n")
}

# O pacote {vigiar} (PM2.5 e indicadores do VIGIAR/MS) é distribuído pelo GitHub
# e NÃO está no CRAN. Ele é instalado automaticamente por src/run_vigiar.R e
# src/run_vigiar_indicadores.R via:
#   remotes::install_github("santosry/vigiar")
#
# O pacote {BrazilMet} (dados meteorológicos INMET) é opcional na Etapa 1: o
# script scripts/02_download_process_exposures.R baixa diretamente do portal
# do INMET via {httr} (mesma fonte usada pelo BrazilMet), com controle explícito
# do critério de qualidade (>= 80% de dias com registro).
