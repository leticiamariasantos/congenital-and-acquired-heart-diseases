# =============================================================================
# run_sinasc.R
# Executa o pipeline SINASC completo.
#
# Uso (a partir da raiz do repositório):
#   Rscript src/run_sinasc.R
# =============================================================================

options(stringsAsFactors = FALSE)
Sys.setenv(TZ = "America/Sao_Paulo")
options(timeout = 1800)

pacotes <- c(
  "microdatasus", "dplyr", "purrr", "stringr",
  "readr", "digest", "jsonlite", "tibble"
)
faltantes <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltantes) > 0L) {
  install.packages(faltantes)
}
invisible(lapply(pacotes, library, character.only = TRUE))

source("src/00_config.R")
source("src/01_utils.R")
source("src/02_download.R")
source("src/03_process_sinasc.R")

garantir_diretorios()

tempo_total <- system.time({
  saidas <- purrr::map(CONFIG$anos, processar_sinasc_ano)
})

resultado_final <- dplyr::bind_rows(purrr::map(saidas, "dados")) %>%
  dplyr::mutate(
    audit_row_id = dplyr::row_number(),
    audit_hash_linha = hash_linhas(.)
  )

auditoria_final <- dplyr::bind_rows(purrr::map(saidas, "auditoria"))

readr::write_rds(resultado_final, CONFIG$arquivos$sinasc_rds)
readr::write_csv(resultado_final, CONFIG$arquivos$sinasc_csv, na = "")
readr::write_csv(auditoria_final, CONFIG$arquivos$sinasc_auditoria, na = "")

checksums <- list(
  rds = digest::digest(file = CONFIG$arquivos$sinasc_rds, algo = "sha256"),
  csv = digest::digest(file = CONFIG$arquivos$sinasc_csv, algo = "sha256"),
  auditoria = digest::digest(file = CONFIG$arquivos$sinasc_auditoria, algo = "sha256")
)

metadados <- montar_metadados(
  projeto = "SINASC RJ Campos dos Goytacazes Q20-Q28 2020-2024",
  base = "SINASC/DATASUS",
  uf = CONFIG$uf,
  periodo = paste(range(CONFIG$anos), collapse = "-"),
  criterios = list(
    municipio_residencia_codigo = CONFIG$municipio_residencia_codigo,
    criterio_municipio = "CODMUNRES",
    criterio_anomalia = "IDANOMAL em {'1', 'Sim'}",
    criterio_diagnostico = "CODANOMAL contém código Q20-Q28 (qualquer posição)",
    colunas_originais_preservadas = TRUE
  ),
  n_total = nrow(resultado_final),
  tempo_total_segundos = as.numeric(tempo_total["elapsed"]),
  checksums_sha256 = checksums,
  pacotes = pacotes
)

jsonlite::write_json(metadados, CONFIG$arquivos$sinasc_metadados,
                     pretty = TRUE, auto_unbox = TRUE)

cat("\n========== SINASC — FINAL ==========\n")
cat("RDS:", normalizePath(CONFIG$arquivos$sinasc_rds, winslash = "/", mustWork = FALSE), "\n")
cat("CSV:", normalizePath(CONFIG$arquivos$sinasc_csv, winslash = "/", mustWork = FALSE), "\n")
cat("Auditoria:", normalizePath(CONFIG$arquivos$sinasc_auditoria, winslash = "/", mustWork = FALSE), "\n")
cat("Metadados:", normalizePath(CONFIG$arquivos$sinasc_metadados, winslash = "/", mustWork = FALSE), "\n")
cat("Total de registros:", nrow(resultado_final), "\n")
cat("Colunas finais:", ncol(resultado_final), "\n")
cat("SHA256 RDS:", checksums$rds, "\n")
