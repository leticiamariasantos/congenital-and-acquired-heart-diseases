# =============================================================================
# 02_download_process_exposures.R
# Download e processamento das EXPOSIÇÕES ambientais — 2010–2019
#
#   Temperatura e umidade : INMET, estação automática A607 (Campos dos
#                           Goytacazes), agregação mensal com critério de
#                           qualidade (>= 80% dos dias com registro).
#   PM2,5                  : VIGIAR / Ministério da Saúde, concentração mensal
#                           (µg/m³).
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
garantir_diretorios()

for (p in c("dplyr", "tidyr", "readr", "lubridate", "stringr", "httr")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  suppressPackageStartupMessages(library(p, character.only = TRUE))
}

# -----------------------------------------------------------------------------
# 1. INMET — estação A607 (temperatura e umidade)
# -----------------------------------------------------------------------------
# Os arquivos históricos horários do INMET estão em:
#   https://portal.inmet.gov.br/uploads/dadoshistoricos/AAAA.zip
# Cada .zip contém os arquivos CSV de todas as estações automáticas do ano.
# Extraímos apenas o arquivo da estação A607 (Campos dos Goytacazes).
#
# O portal exige um User-Agent de navegador (download.file com wininet falha),
# por isso usamos httr::GET com cabeçalho de User-Agent.

# URL base e nome do arquivo de cache do zip por ano
url_zip_inmet <- function(ano) {
  sprintf("https://portal.inmet.gov.br/uploads/dadoshistoricos/%04d.zip", ano)
}
caminho_zip_inmet <- function(ano) {
  file.path(CONFIG$dirs$cache_raw, sprintf("inmet_%04d.zip", ano))
}

# Baixa o zip anual do INMET (com cache). Retorna o caminho do arquivo local.
baixar_zip_inmet <- function(ano) {
  dest <- caminho_zip_inmet(ano)
  if (file.exists(dest) && file.info(dest)$size > 0) {
    cat(sprintf("  [cache] INMET zip %04d\n", ano))
    return(dest)
  }
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  cat(sprintf("  Baixando INMET %04d.zip ...\n", ano))
  for (tentativa in 1:3) {
    resp <- tryCatch(
      httr::GET(url_zip_inmet(ano),
                httr::user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64)"),
                httr::write_disk(dest, overwrite = TRUE),
                httr::timeout(900)),
      error = function(e) NULL
    )
    if (!is.null(resp) && httr::status_code(resp) == 200 &&
        file.info(dest)$size > 0) {
      return(dest)
    }
    Sys.sleep(5 * tentativa)
  }
  stop(sprintf("Falha ao baixar INMET %04d.zip.", ano))
}

# Lê o CSV horário de uma estação INMET. Os arquivos históricos têm 8 linhas
# de metadados e o cabeçalho na linha 9. O formato mudou ao longo do tempo:
#   - arquivos antigos (ex.: 2010): separador ";", data "YYYY-MM-DD", ISO-8859-1
#   - arquivos recentes (ex.: 2020): separador ",", data "YYYY/MM/DD"
# O separador é detectado automaticamente e as colunas renomeadas por posição.
ler_inmet <- function(caminho) {
  # Detecta o separador pela linha de cabeçalho (linha 9), lendo o arquivo
  # como latin1 (os arquivos INMET antigos são ISO-8859-1; ler como UTF-8
  # geraria strings inválidas e falharia na detecção).
  con <- file(caminho, "r", encoding = "latin1")
  cab <- readLines(con, n = 10, warn = FALSE)[9]
  close(con)
  sep <- if (grepl(";", cab, fixed = TRUE)) ";" else ","

  d <- utils::read.csv(caminho, skip = 8, sep = sep, dec = ",",
                       fileEncoding = "latin1",
                       stringsAsFactors = FALSE, check.names = FALSE,
                       na.strings = c("", "NA", "-9999", "null", "NULL"))
  names(d) <- c(
    "data", "hora_utc", "precip_mm", "pressao_mb", "pressao_max_mb",
    "pressao_min_mb", "radiacao_kjm2", "temp_c", "temp_orvalho_c",
    "temp_max_c", "temp_min_c", "temp_orvalho_max_c", "temp_orvalho_min_c",
    "umid_max_pct", "umid_min_pct", "umid_pct", "vento_dir_gr",
    "vento_rajada_ms", "vento_vel_ms"
  )
  # Remove uma eventual coluna extra (o ";" final gera uma coluna vazia)
  d <- d[, 1:19]

  num_br <- function(x) {
    x <- trimws(as.character(x))
    x[x %in% c("", "NA", "-9999", "null", "NULL")] <- NA_character_
    suppressWarnings(as.numeric(sub(",", ".", x, fixed = TRUE)))
  }

  d %>%
    dplyr::mutate(
      data = lubridate::ymd(data),
      dplyr::across(c(temp_c, umid_pct), num_br)
    )
}

# Extrai o arquivo CSV da estação A607 de dentro do zip e salva em data/raw/.
extrair_csv_estacao <- function(ano) {
  arquivo_csv <- file.path(CONFIG$dirs$raw_inmet,
                           sprintf("inmet_campos_goytacazes_%04d.csv", ano))
  if (file.exists(arquivo_csv)) {
    cat(sprintf("  [cache] INMET A607 CSV %04d\n", ano))
    return(arquivo_csv)
  }

  zip_path <- baixar_zip_inmet(ano)
  tmp <- tempfile()
  dir.create(tmp)
  utils::unzip(zip_path, exdir = tmp, junkpaths = TRUE)
  alvo <- list.files(tmp, pattern = CONFIG$estacao_inmet, full.names = TRUE)
  if (length(alvo) == 0L) {
    stop(sprintf("Estação %s não encontrada no zip INMET %04d.",
                 CONFIG$estacao_inmet, ano))
  }
  file.copy(alvo[1], arquivo_csv, overwrite = TRUE)
  unlink(tmp, recursive = TRUE)
  cat(sprintf("  INMET A607 %04d extraído.
", ano))
  arquivo_csv
}

cat("Baixando/processando INMET A607 2010–2019 ...\n")
inmet_bruto <- dplyr::bind_rows(lapply(CONFIG$anos, function(ano) {
  ler_inmet(extrair_csv_estacao(ano))
}))

# --- Agregação mensal com critério de qualidade --------------------------
# Para cada mês, calcula:
#   n_dias_temp : nº de dias com >= 1 registro de temperatura
#   n_dias_umid : nº de dias com >= 1 registro de umidade
#   cobertura_* : fração de dias do mês com registro (>= 80% => ok)
#   temp_media_c / umidade_media_pct : médias mensais (a partir das médias diárias)
temp_umidade_mensal <- inmet_bruto %>%
  dplyr::filter(!is.na(data)) %>%
  dplyr::mutate(
    ano     = lubridate::year(data),
    mes     = lubridate::month(data),
    mes_ano = as.Date(sprintf("%04d-%02d-01", ano, mes))
  ) %>%
  dplyr::group_by(mes_ano, ano, mes) %>%
  dplyr::summarise(
    n_dias_mes = as.integer(lubridate::days_in_month(mes_ano[1])),
    temp_media_c   = mean(temp_c, na.rm = TRUE),
    umidade_media_pct = mean(umid_pct, na.rm = TRUE),
    n_dias_temp = dplyr::n_distinct(data[!is.na(temp_c)]),
    n_dias_umid = dplyr::n_distinct(data[!is.na(umid_pct)]),
    .groups = "drop"
  ) %>%
  dplyr::mutate(
    cobertura_temp_pct = round(n_dias_temp / n_dias_mes, 4),
    cobertura_umid_pct = round(n_dias_umid / n_dias_mes, 4),
    qualidade_ok = cobertura_temp_pct >= CONFIG$criterios$cobertura_minima_inmet &
                   cobertura_umid_pct >= CONFIG$criterios$cobertura_minima_inmet
  ) %>%
  dplyr::arrange(mes_ano)

# Documenta os meses excluídos (cobertura < 80%)
exclusoes <- temp_umidade_mensal %>%
  dplyr::filter(!qualidade_ok) %>%
  dplyr::select(mes_ano, ano, mes, n_dias_mes, n_dias_temp, n_dias_umid,
                cobertura_temp_pct, cobertura_umid_pct)

readr::write_csv(temp_umidade_mensal, CONFIG$arquivos$temp_umidade_mensal, na = "")
readr::write_csv(exclusoes, CONFIG$arquivos$temp_umidade_exclusoes, na = "")

# -----------------------------------------------------------------------------
# 2. PM2,5 (VIGIAR) — concentração mensal
# -----------------------------------------------------------------------------
# Fonte primária: o arquivo bruto já extraído do dashboard VIGIAR/MS
# (data/raw/vigiar/vigiar_pm25_campos_mensal.csv), com a série completa
# 2010–2025. Se o arquivo não existir localmente, tenta baixá-lo pelo pacote
# {vigiar}.
cat("Processando PM2,5 (VIGIAR) ...\n")

ler_pm25_bruto <- function() {
  caminho <- CONFIG$arquivos$vigiar_pm25_bruto
  if (!file.exists(caminho)) {
    stop(sprintf("Arquivo VIGIAR ausente: %s. Rode a extração do VIGIAR ",
                 caminho),
         "(scripts/02 via pacote vigiar) antes de prosseguir.")
  }
  readr::read_csv(caminho, show_col_types = FALSE)
}

pm25_bruto <- tryCatch(ler_pm25_bruto(), error = function(e) {
  warning(conditionMessage(e))
  # Fallback: tenta baixar via pacote {vigiar} (exige sessão ativa no dashboard)
  if (!requireNamespace("vigiar", quietly = TRUE)) {
    stop("Pacote {vigiar} não disponível para o fallback de download.")
  }
  vigiar::vigiar_conectar()
  d <- vigiar::vigiar_baixar("df_mensal", uf = CONFIG$uf)
  # filtra o município no cliente, por segurança
  d <- d[d$muni == CONFIG$municipio_codigo_6, , drop = FALSE]
  readr::write_csv(d, CONFIG$arquivos$vigiar_pm25_bruto, na = "")
  d
})

pm25_mensal <- pm25_bruto %>%
  dplyr::transmute(
    mes_ano = as.Date(sprintf("%04d-%02d-01", as.integer(ano), as.integer(mes))),
    ano     = as.integer(ano),
    mes     = as.integer(mes),
    pm25    = round(as.numeric(pm25), 4)
  ) %>%
  dplyr::filter(ano %in% CONFIG$anos) %>%
  dplyr::arrange(mes_ano)

# Completa a grade mensal 2010–2019 (meses sem dado => NA explícito)
grade <- data.frame(
  mes_ano = seq(as.Date(sprintf("%04d-01-01", CONFIG$ano_inicio)),
                as.Date(sprintf("%04d-12-01", CONFIG$ano_fim)), by = "month")
)
pm25_mensal <- grade %>%
  dplyr::left_join(pm25_mensal, by = "mes_ano") %>%
  dplyr::mutate(ano = lubridate::year(mes_ano),
                mes = lubridate::month(mes_ano)) %>%
  dplyr::select(mes_ano, ano, mes, pm25)

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
