# =============================================================================
# 01_utils.R
# Funções utilitárias compartilhadas pelos pipelines SINASC e SIH-RD.
# =============================================================================

# Normaliza um código CID-10: maiúsculas e remove tudo que não for letra/dígito.
# Ex.: "q21.3" -> "Q213"; "Q248Q539Q909" -> "Q248Q539Q909".
#
# CORREÇÃO DE BUG: a versão anterior usava gsub("[^A-Z0-9]", ...) ANTES do
# toupper(), o que removia letras minúsculas. Agora preservamos [A-Za-z0-9]
# e só então convertemos para maiúsculas.
normalizar_cid <- function(x) {
  toupper(gsub("[^A-Za-z0-9]", "", as.character(x)))
}

# Extrai todos os códigos "Qxxx" presentes em uma string.
# No SINASC, o campo CODANOMAL pode conter vários códigos concatenados
# (ex.: "Q224Q233Q253Q891"). Retorna uma lista com um vetor de códigos por linha.
extrair_codigos_q <- function(x) {
  x <- as.character(x)
  achados <- regmatches(x, gregexpr("Q[0-9]{3}", x))
  achados[is.na(x)] <- list(character(0))
  achados
}

# TRUE quando QUALQUER código CID-Q presente na string pertence a Q20-Q28
# (malformações congênitas do aparelho circulatório).
#
# IMPORTANTE (correção de bug): a versão anterior usava grepl("^Q2[0-8]", x),
# que só avaliava o PRIMEIRO código da concatenação. Registros cujo primeiro
# código era não cardíaco (ex.: "Q031Q248") eram descartados indevidamente.
# Esta versão varre todos os códigos presentes.
tem_cid_q20_q28 <- function(x, regex = CONFIG$criterios$cid_q20_q28_regex) {
  codigos <- extrair_codigos_q(x)
  vapply(codigos, function(cs) {
    length(cs) > 0L && any(grepl(regex, cs))
  }, logical(1))
}

# Verifica a presença das colunas obrigatórias em um data frame e,
# se houver ausência, interrompe com mensagem clara.
verificar_colunas <- function(dados, colunas, contexto) {
  faltantes <- setdiff(colunas, names(dados))
  if (length(faltantes) > 0L) {
    stop(sprintf(
      "Colunas obrigatórias ausentes em %s: %s",
      contexto, paste(faltantes, collapse = ", ")
    ))
  }
  invisible(TRUE)
}

# Calcula um hash SHA-256 determinístico para cada linha de um data frame.
# Útil para rastrear a proveniência de cada registro.
hash_linhas <- function(dados) {
  vapply(seq_len(nrow(dados)), function(i) {
    linha <- vapply(dados[i, , drop = FALSE], as.character, character(1))
    digest::digest(paste(linha, collapse = "|"), algo = "sha256")
  }, character(1))
}

# Monta o bloco de metadados de execução (reprodutibilidade), sem dados pessoais.
montar_metadados <- function(projeto, base, uf, periodo, criterios, n_total,
                             tempo_total_segundos, checksums_sha256, pacotes) {
  list(
    projeto = projeto,
    base = base,
    pacote = "microdatasus",
    uf = uf,
    periodo = periodo,
    criterios = criterios,
    n_total = n_total,
    tempo_total_segundos = tempo_total_segundos,
    checksums_sha256 = checksums_sha256,
    versoes_pacotes = vapply(pacotes, function(p) as.character(utils::packageVersion(p)), character(1)),
    r_version = R.version.string,
    plataforma = R.version$platform,
    session_info = utils::capture.output(utils::sessionInfo()),
    data_execucao = as.character(Sys.time())
  )
}
