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
  # Manipulação e importação de dados
  "dplyr", "tidyr", "purrr", "tibble", "stringr", "readr", "lubridate",
  # Visualização
  "ggplot2", "scales",
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
