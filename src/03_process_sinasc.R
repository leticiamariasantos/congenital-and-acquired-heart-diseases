# =============================================================================
# 03_process_sinasc.R
# Pipeline SINASC: processamento, auditoria e extração dos casos Q20-Q28.
#
# SINASC = Sistema de Informações sobre Nascidos Vivos.
# Filtros aplicados:
#   1. Município de residência da mãe = Campos dos Goytacazes (CODMUNRES).
#   2. Presença de anomalia congênita (IDANOMAL em {"1", "Sim"}).
#   3. Qualquer código CID-10 Q20-Q28 em CODANOMAL.
# =============================================================================

# Lê o cache processado ou processa os dados brutos de um ano do SINASC.
carregar_sinasc_processado <- function(ano) {
  arquivo_processado <- file.path(
    CONFIG$dirs$cache_processado,
    sprintf("SINASC_%s_%04d_processado.rds", CONFIG$uf, ano)
  )

  if (file.exists(arquivo_processado)) {
    return(readRDS(arquivo_processado))
  }

  bruto <- baixar_sinasc_ano(ano)
  processado <- microdatasus::process_sinasc(bruto, municipality_data = TRUE)
  saveRDS(processado, arquivo_processado)
  processado
}

# Aplica os critérios de inclusão e retorna uma lista com:
#   dados    : data frame filtrado (apenas linhas aprovadas).
#   auditoria: tibble com os totais do ano (para o arquivo de auditoria).
processar_sinasc_ano <- function(ano) {
  sinasc <- carregar_sinasc_processado(ano)

  verificar_colunas(
    sinasc,
    c("CODMUNRES", "IDANOMAL", "CODANOMAL", "DTNASC"),
    sprintf("SINASC %04d", ano)
  )

  sinasc_auditado <- sinasc %>%
    dplyr::mutate(
      audit_ano_execucao = ano,
      codanomal_norm = normalizar_cid(CODANOMAL),
      audit_residente_campos =
        substr(as.character(CODMUNRES), 1, 6) == CONFIG$municipio_residencia_codigo,
      audit_anomalia_identificada = as.character(IDANOMAL) %in% c("1", "Sim"),
      audit_q20_q28 = tem_cid_q20_q28(CODANOMAL)
    ) %>%
    dplyr::mutate(
      audit_linha_aprovada =
        audit_residente_campos & audit_anomalia_identificada & audit_q20_q28
    )

  auditoria_ano <- tibble::tibble(
    ano = ano,
    n_linhas_processadas = nrow(sinasc_auditado),
    n_residentes_campos = sum(sinasc_auditado$audit_residente_campos, na.rm = TRUE),
    n_anomalia_identificada = sum(sinasc_auditado$audit_anomalia_identificada, na.rm = TRUE),
    n_q20_q28 = sum(sinasc_auditado$audit_q20_q28, na.rm = TRUE),
    n_final_ano = sum(sinasc_auditado$audit_linha_aprovada, na.rm = TRUE),
    data_execucao = as.character(Sys.time())
  )

  list(
    dados = dplyr::filter(sinasc_auditado, audit_linha_aprovada),
    auditoria = auditoria_ano
  )
}
