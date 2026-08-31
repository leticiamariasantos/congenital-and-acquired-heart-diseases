# =============================================================================
# 02_download.R
# Download de dados do DATASUS via microdatasus, com cache local e retry.
# =============================================================================

# Baixa dados com tentativas repetidas e cache em disco (.rds).
#
# Parâmetros:
#   arquivo_cache : caminho do arquivo .rds usado como cache.
#   baixar        : função sem argumentos que retorna o data frame bruto.
#   rotulo        : texto descritivo usado nas mensagens de progresso.
#   tentativas    : número máximo de tentativas.
#
# Retorna o data frame (lido do cache, se existir).
baixar_com_retry <- function(arquivo_cache, baixar, rotulo, tentativas = 5L) {
  if (file.exists(arquivo_cache)) {
    cat(sprintf("Cache encontrado: %s\n", basename(arquivo_cache)))
    return(readRDS(arquivo_cache))
  }

  erro_final <- NULL
  for (i in seq_len(tentativas)) {
    cat(sprintf("%s | tentativa %d/%d\n", rotulo, i, tentativas))
    bruto <- tryCatch(
      baixar(),
      error = function(e) {
        erro_final <<- conditionMessage(e)
        NULL
      }
    )
    if (!is.null(bruto) && is.data.frame(bruto) && nrow(bruto) > 0L) {
      saveRDS(bruto, arquivo_cache)
      return(bruto)
    }
    Sys.sleep(10 * i)
  }

  stop(sprintf("Falha definitiva em %s. Último erro: %s", rotulo, erro_final))
}

# Download anual do SINASC.
baixar_sinasc_ano <- function(ano) {
  baixar_com_retry(
    arquivo_cache = file.path(
      CONFIG$dirs$cache_raw,
      sprintf("SINASC_%s_%04d_raw.rds", CONFIG$uf, ano)
    ),
    baixar = function() {
      microdatasus::fetch_datasus(
        year_start = ano,
        year_end = ano,
        uf = CONFIG$uf,
        information_system = "SINASC",
        timeout = 1800,
        stop_on_error = TRUE
      )
    },
    rotulo = sprintf("Baixando SINASC %s %04d", CONFIG$uf, ano)
  )
}

# Download mensal do SIH-RD.
baixar_sih_mes <- function(ano, mes) {
  baixar_com_retry(
    arquivo_cache = file.path(
      CONFIG$dirs$cache_raw,
      sprintf("SIH_RD_%s_%04d_%02d_raw.rds", CONFIG$uf, ano, mes)
    ),
    baixar = function() {
      microdatasus::fetch_datasus(
        year_start = ano,
        month_start = mes,
        year_end = ano,
        month_end = mes,
        uf = CONFIG$uf,
        information_system = "SIH-RD",
        timeout = 1800,
        stop_on_error = TRUE
      )
    },
    rotulo = sprintf("Baixando SIH-RD %s %04d-%02d", CONFIG$uf, ano, mes)
  )
}
