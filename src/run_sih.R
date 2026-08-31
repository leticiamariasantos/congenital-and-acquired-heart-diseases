# =============================================================================
# run_sih.R
# Executa o pipeline SIH-RD completo.
#
# Uso (a partir da raiz do repositório):
#   Rscript src/run_sih.R
# =============================================================================

options(stringsAsFactors = FALSE)
Sys.setenv(TZ = "America/Sao_Paulo")
options(timeout = 1800)

pacotes <- c(
  "microdatasus", "dplyr", "purrr", "stringr",
  "lubridate", "readr", "digest", "jsonlite", "tibble"
)
faltantes <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltantes) > 0L) {
  install.packages(faltantes)
}
invisible(lapply(pacotes, library, character.only = TRUE))

source("src/00_config.R")
source("src/01_utils.R")
source("src/02_download.R")
source("src/04_process_sih.R")

garantir_diretorios()

grade <- expand.grid(ano = CONFIG$anos, mes = CONFIG$meses) %>%
  dplyr::arrange(ano, mes)

tempo_total <- system.time({
  saidas <- purrr::pmap(
    list(grade$ano, grade$mes),
    processar_sih_mes
  )
})

resultado_final <- dplyr::bind_rows(purrr::map(saidas, "dados")) %>%
  dplyr::select(-dplyr::any_of(CONFIG$colunas_sensiveis_sih)) %>%
  dplyr::mutate(
    audit_row_id = dplyr::row_number(),
    audit_hash_linha = hash_linhas(.)
  )

auditoria_final <- dplyr::bind_rows(purrr::map(saidas, "auditoria"))

readr::write_rds(resultado_final, CONFIG$arquivos$sih_rds)
readr::write_csv(resultado_final, CONFIG$arquivos$sih_csv, na = "")
readr::write_csv(auditoria_final, CONFIG$arquivos$sih_auditoria, na = "")

checksums <- list(
  rds = digest::digest(file = CONFIG$arquivos$sih_rds, algo = "sha256"),
  csv = digest::digest(file = CONFIG$arquivos$sih_csv, algo = "sha256"),
  auditoria = digest::digest(file = CONFIG$arquivos$sih_auditoria, algo = "sha256")
)

metadados <- montar_metadados(
  projeto = "SIH-RD RJ Campos dos Goytacazes Q20-Q28 menor de 1 ano 2020-2024",
  base = "SIH-RD/DATASUS",
  uf = CONFIG$uf,
  periodo = paste(range(CONFIG$anos), collapse = "-"),
  criterios = list(
    municipio_residencia_codigo = CONFIG$municipio_residencia_codigo,
    criterio_municipio = "MUNIC_RES",
    criterio_diagnostico = "DIAG_PRINC Q20-Q28 (diagnóstico principal)",
    criterio_idade = "idade_dias_estimado >= 0 e < 365 (Neonato 0-28; Lactente 29-364)",
    colunas_originais_preservadas = TRUE,
    colunas_removidas_privacidade = CONFIG$colunas_sensiveis_sih
  ),
  n_total = nrow(resultado_final),
  tempo_total_segundos = as.numeric(tempo_total["elapsed"]),
  checksums_sha256 = checksums,
  pacotes = pacotes
)

# Contagens complementares para o metadado
metadados$n_neonato <- sum(resultado_final$classe_idade == "Neonato", na.rm = TRUE)
metadados$n_lactente <- sum(resultado_final$classe_idade == "Lactente", na.rm = TRUE)

jsonlite::write_json(metadados, CONFIG$arquivos$sih_metadados,
                     pretty = TRUE, auto_unbox = TRUE)

cat("\n========== SIH-RD — FINAL ==========\n")
cat("RDS:", normalizePath(CONFIG$arquivos$sih_rds, winslash = "/", mustWork = FALSE), "\n")
cat("CSV:", normalizePath(CONFIG$arquivos$sih_csv, winslash = "/", mustWork = FALSE), "\n")
cat("Auditoria:", normalizePath(CONFIG$arquivos$sih_auditoria, winslash = "/", mustWork = FALSE), "\n")
cat("Metadados:", normalizePath(CONFIG$arquivos$sih_metadados, winslash = "/", mustWork = FALSE), "\n")
cat("Total de registros:", nrow(resultado_final), "\n")
cat("Neonatos:", sum(resultado_final$classe_idade == "Neonato", na.rm = TRUE), "\n")
cat("Lactentes:", sum(resultado_final$classe_idade == "Lactente", na.rm = TRUE), "\n")
cat("Colunas finais:", ncol(resultado_final), "\n")
cat("SHA256 RDS:", checksums$rds, "\n")
