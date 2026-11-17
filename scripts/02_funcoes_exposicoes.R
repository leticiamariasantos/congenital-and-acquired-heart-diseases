# =============================================================================
# 02_funcoes_exposicoes.R
# Funções compartilhadas de download/processamento das EXPOSIÇÕES ambientais.
#
# Usadas por scripts/02_download_process_exposures.R (2010–2019) e
# scripts/06_etapa1_2020_2024.R (2020–2024).
#
#   Temperatura e umidade : INMET, estação A607 (Campos dos Goytacazes),
#                           agregação mensal com critério de qualidade
#                           (>= 80% dos dias com registro).
#   PM2,5                  : VIGIAR / Ministério da Saúde (µg/m³).
# =============================================================================

# -----------------------------------------------------------------------------
# INMET — estação A607 (temperatura e umidade)
# -----------------------------------------------------------------------------
# Os arquivos históricos horários do INMET estão em:
#   https://portal.inmet.gov.br/uploads/dadoshistoricos/AAAA.zip
# O portal exige User-Agent de navegador (por isso usamos httr::GET).

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
ler_inmet <- function(caminho) {
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
  cat(sprintf("  INMET A607 %04d extraído.\n", ano))
  arquivo_csv
}

# Agrega os dados horários do INMET A607 em médias mensais, com o critério de
# qualidade: mantém apenas meses com >= 80% dos dias com registro (temperatura
# E umidade). Retorna o data frame mensal com colunas de cobertura.
processar_temp_umidade <- function(anos) {
  inmet_bruto <- dplyr::bind_rows(lapply(anos, function(ano) {
    ler_inmet(extrair_csv_estacao(ano))
  }))

  inmet_bruto %>%
    dplyr::filter(!is.na(data)) %>%
    dplyr::mutate(
      ano     = lubridate::year(data),
      mes     = lubridate::month(data),
      mes_ano = as.Date(sprintf("%04d-%02d-01", ano, mes))
    ) %>%
    dplyr::group_by(mes_ano, ano, mes) %>%
    dplyr::summarise(
      n_dias_mes = as.integer(lubridate::days_in_month(mes_ano[1])),
      temp_media_c     = mean(temp_c, na.rm = TRUE),
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
}

# -----------------------------------------------------------------------------
# PM2,5 (VIGIAR) — concentração mensal
# -----------------------------------------------------------------------------
# Fonte primária: data/raw/vigiar/vigiar_pm25_campos_mensal.csv (série completa
# 2010–2025). Retorna a série mensal do período solicitado (grade completa, com
# NA explícito para meses sem dado).
processar_pm25 <- function(anos) {
  caminho <- CONFIG$arquivos$vigiar_pm25_bruto
  if (!file.exists(caminho)) {
    stop(sprintf("Arquivo VIGIAR ausente: %s.", caminho))
  }
  pm25_bruto <- readr::read_csv(caminho, show_col_types = FALSE)

  pm25 <- pm25_bruto %>%
    dplyr::transmute(
      mes_ano = as.Date(sprintf("%04d-%02d-01", as.integer(ano), as.integer(mes))),
      ano     = as.integer(ano),
      mes     = as.integer(mes),
      pm25    = round(as.numeric(pm25), 4)
    ) %>%
    dplyr::filter(ano %in% anos) %>%
    dplyr::arrange(mes_ano)

  grade <- data.frame(
    mes_ano = seq(as.Date(sprintf("%04d-01-01", min(anos))),
                  as.Date(sprintf("%04d-12-01", max(anos))), by = "month")
  )
  pm25 <- grade %>%
    dplyr::left_join(pm25, by = "mes_ano") %>%
    dplyr::mutate(ano = lubridate::year(mes_ano),
                  mes = lubridate::month(mes_ano)) %>%
    dplyr::select(mes_ano, ano, mes, pm25)
  pm25
}
