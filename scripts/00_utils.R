# =============================================================================
# 00_utils.R
# Funções utilitárias compartilhadas por todo o pipeline.
# =============================================================================

# -----------------------------------------------------------------------------
# Diretório de trabalho
# -----------------------------------------------------------------------------
# Garante que o R esteja executando a partir da raiz do repositório.
garantir_raiz <- function() {
  if (basename(getwd()) == "scripts" && file.exists("00_config.R")) {
    setwd("..")
  }
  if (!file.exists("scripts/00_config.R")) {
    stop("Não foi possível localizar a raiz do repositório (scripts/00_config.R).",
         " Execute a partir da raiz ou via scripts/run_all.R.")
  }
  invisible(normalizePath(getwd()))
}

# -----------------------------------------------------------------------------
# Códigos CID-10
# -----------------------------------------------------------------------------

# Normaliza um código CID-10: maiúsculas e remove tudo que não for letra/dígito.
normalizar_cid <- function(x) {
  toupper(gsub("[^A-Za-z0-9]", "", as.character(x)))
}

# Extrai todos os códigos "Qxxx" presentes em uma string (campo CODANOMAL do
# SINASC pode conter vários códigos concatenados, ex.: "Q224Q233Q253Q891").
extrair_codigos_q <- function(x) {
  x <- as.character(x)
  achados <- regmatches(x, gregexpr("Q[0-9]{3}", x))
  achados[is.na(x)] <- list(character(0))
  achados
}

# TRUE quando QUALQUER código Q presente na string pertence ao intervalo do regex.
# Varre todos os códigos (não apenas o primeiro), pois o SINASC pode concatenar
# vários códigos no mesmo campo (ex.: "Q031Q248" -> inclui Q248).
tem_cid_q <- function(x, regex) {
  codigos <- extrair_codigos_q(x)
  vapply(codigos, function(cs) {
    length(cs) > 0L && any(grepl(regex, cs))
  }, logical(1))
}

# -----------------------------------------------------------------------------
# Diagnósticos do SIH-RD (principal + secundários)
# -----------------------------------------------------------------------------
# O SIH-RD registra até 9 diagnósticos secundários (DIAGSEC1..DIAGSEC9); o
# campo DIAG_SECUN é legado (em geral "0000"). A função devolve as colunas de
# diagnóstico disponíveis no data frame.
colunas_diagnostico_sih <- function(dados) {
  intersect(c("DIAG_PRINC", "DIAG_SECUN", paste0("DIAGSEC", 1:9)), names(dados))
}

# TRUE quando QUALQUER coluna de diagnóstico (principal ou secundária) casa com
# o regex informado. Implementação vetorizada (loop por coluna + rowSums).
tem_diagnostico_sih <- function(dados, regex) {
  cols <- colunas_diagnostico_sih(dados)
  if (length(cols) == 0L) {
    stop("Nenhuma coluna de diagnóstico encontrada no SIH-RD.")
  }
  m <- matrix(FALSE, nrow = nrow(dados), ncol = length(cols))
  for (j in seq_along(cols)) {
    m[, j] <- grepl(regex, as.character(dados[[cols[j]]]))
  }
  rowSums(m, na.rm = TRUE) > 0L
}

# -----------------------------------------------------------------------------
# Idade no SIH-RD
# -----------------------------------------------------------------------------
# Converte datas em vários formatos (YYYY-MM-DD, YYYYMMDD, DDMMYYYY,
# DD/MM/YYYY) para Date. Os microdados brutos do DATASUS usam "YYYYMMDD"
# (SIH) e "DDMMYYYY" (SINASC); o microdatasus processado usa "YYYY-MM-DD".
# A ordem importa: lubridate::ymd resolve primeiro (YYYYMMDD / YYYY-MM-DD) e,
# para as datas ainda ausentes, lubridate::dmy resolve (DDMMYYYY / DD/MM/YYYY).
parse_data <- function(x) {
  x <- as.character(x)
  out <- suppressWarnings(lubridate::ymd(x))
  idx <- is.na(out)
  out[idx] <- suppressWarnings(lubridate::dmy(x[idx]))
  as.Date(out)
}

# Converte idade por COD_IDADE/IDADE em dias (fallback quando as datas são
# inválidas). Aceita rótulos ("Dias", "Meses", "Anos", "Horas", "Centena de
# anos (100 + idade)") e códigos numéricos ("1".."5").
idade_dias_por_codigo <- function(cod_idade, idade) {
  cod <- toupper(trimws(as.character(cod_idade)))
  idade_num <- suppressWarnings(as.integer(idade))
  dplyr::case_when(
    cod %in% c("HORAS", "HORA", "1") ~ as.integer(round(idade_num / 24)),
    cod %in% c("DIAS", "DIA", "2") ~ idade_num,
    cod %in% c("MESES", "MES", "3") ~ idade_num * CONFIG$criterios$dias_por_mes,
    cod %in% c("ANOS", "ANO", "4") ~ idade_num * CONFIG$criterios$dias_por_ano,
    grepl("CENTENA", cod, ignore.case = TRUE) | cod == "5" ~
      (100L + idade_num) * CONFIG$criterios$dias_por_ano,
    TRUE ~ NA_integer_
  )
}

# Estima a idade em dias preferindo o cálculo por datas (DT_INTER - NASC);
# usa COD_IDADE/IDADE apenas como fallback.
calcular_idade_dias <- function(nasc, dt_inter, cod_idade, idade) {
  idade_por_data <- as.integer(parse_data(dt_inter) - parse_data(nasc))
  idade_por_codigo <- idade_dias_por_codigo(cod_idade, idade)
  ifelse(!is.na(idade_por_data) & idade_por_data >= 0,
         idade_por_data, idade_por_codigo)
}

# -----------------------------------------------------------------------------
# Validação
# -----------------------------------------------------------------------------
verificar_colunas <- function(dados, colunas, contexto) {
  faltantes <- setdiff(colunas, names(dados))
  if (length(faltantes) > 0L) {
    stop(sprintf("Colunas obrigatórias ausentes em %s: %s",
                 contexto, paste(faltantes, collapse = ", ")))
  }
  invisible(TRUE)
}

# -----------------------------------------------------------------------------
# Download com cache e retry (usado por microdatasus e INMET)
# -----------------------------------------------------------------------------
baixar_com_retry <- function(arquivo_cache, baixar, rotulo, tentativas = 5L) {
  if (file.exists(arquivo_cache)) {
    cat(sprintf("  [cache] %s\n", basename(arquivo_cache)))
    return(readRDS(arquivo_cache))
  }

  erro_final <- NULL
  for (i in seq_len(tentativas)) {
    cat(sprintf("  %s | tentativa %d/%d\n", rotulo, i, tentativas))
    bruto <- tryCatch(baixar(), error = function(e) {
      erro_final <<- conditionMessage(e)
      NULL
    })
    if (!is.null(bruto) && is.data.frame(bruto) && nrow(bruto) > 0L) {
      saveRDS(bruto, arquivo_cache)
      return(bruto)
    }
    Sys.sleep(8 * i)
  }
  stop(sprintf("Falha definitiva em %s. Último erro: %s", rotulo, erro_final))
}

# -----------------------------------------------------------------------------
# Intervalo de confiança exato de Poisson
# -----------------------------------------------------------------------------
# Para uma contagem x, devolve os limites exatos (Garwood, 1936) do IC de nível
# `nivel` para a taxa x * mult. Quando mult = 1000/denominador, obtém-se o IC
# exato da taxa por 1.000.
ic_poisson_exato <- function(x, nivel = 0.95, mult = 1) {
  alfa <- 1 - nivel
  inf <- ifelse(x == 0, 0, 0.5 * stats::qchisq(alfa / 2, 2 * x))
  sup <- 0.5 * stats::qchisq(1 - alfa / 2, 2 * (x + 1))
  data.frame(estimativa = x * mult,
             ic95_inf   = inf * mult,
             ic95_sup   = sup * mult)
}

# -----------------------------------------------------------------------------
# Estilo de figuras (tema "Cell Press" + paleta viridis)
# -----------------------------------------------------------------------------
theme_cellpress <- function(base_size = 8, base_family = "sans") {
  ggplot2::theme_bw(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      panel.background = ggplot2::element_rect(fill = "white", color = NA),
      panel.grid       = ggplot2::element_blank(),
      panel.border     = ggplot2::element_blank(),
      axis.line        = ggplot2::element_line(color = "black", linewidth = 0.4),
      axis.ticks       = ggplot2::element_line(color = "black", linewidth = 0.4),
      axis.ticks.length = ggplot2::unit(0.08, "cm"),
      axis.text        = ggplot2::element_text(color = "black", size = base_size),
      axis.title       = ggplot2::element_text(color = "black", face = "bold"),
      plot.title       = ggplot2::element_text(face = "bold", hjust = 0,
                                               size = base_size + 2, color = "black"),
      plot.subtitle    = ggplot2::element_text(hjust = 0, color = "grey25",
                                               size = base_size),
      plot.caption     = ggplot2::element_text(hjust = 0, color = "grey35"),
      strip.background = ggplot2::element_blank(),
      strip.text       = ggplot2::element_text(face = "bold", hjust = 0,
                                               size = base_size, color = "black"),
      legend.key       = ggplot2::element_blank(),
      legend.background = ggplot2::element_blank(),
      legend.title     = ggplot2::element_text(face = "bold", size = base_size),
      legend.text      = ggplot2::element_text(size = base_size),
      plot.margin      = ggplot2::margin(6, 8, 6, 6)
    )
}

# Paleta viridis discreta
paleta <- function(n) viridisLite::viridis(n)
