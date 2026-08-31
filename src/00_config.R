# =============================================================================
# 00_config.R
# Configurações centrais do projeto.
#
# Cardiopatias Congênitas e Adquiridas — Campos dos Goytacazes (RJ)
# Fontes: SINASC/DATASUS, SIH-RD/DATASUS (via pacote microdatasus) e INMET.
# =============================================================================

CONFIG <- list(
  # Período de análise
  anos = 2020:2024,
  meses = 1:12,

  # Abrangência geográfica
  uf = "RJ",
  municipio_residencia_codigo = "330100",   # Campos dos Goytacazes
  municipio_residencia_nome = "Campos dos Goytacazes",

  # Diretórios do repositório (caminhos relativos à raiz do projeto)
  dirs = list(
    cache_raw       = "data/cache/raw",
    cache_processado = "data/cache/processed",
    dados           = "data/processed",
    resultados      = "results",
    auditoria       = "results/auditoria",
    figuras         = "results/figures"
  ),

  # Critérios científicos (ver docs/METODOLOGIA.md)
  criterios = list(
    # Malformações congênitas do aparelho circulatório (CID-10 Q20–Q28)
    cid_q20_q28_regex = "^Q2[0-8]",
    # Idade neonatal (dias) e infantil (menor de 1 ano)
    idade_neonato_max_dias = 28L,
    idade_lactente_min_dias = 29L,
    idade_menor_1_ano_max_dias = 364L,
    # Fatores de conversão aproximados usados no fallback por COD_IDADE
    dias_por_mes = 30L,
    dias_por_ano = 365L
  ),

  # Colunas do SIH-RD removidas da publicação por conterem dados pessoais
  # ou identificadores únicos (privacidade). Ver docs/METODOLOGIA.md.
  colunas_sensiveis_sih = c(
    "CPF_AUT",     # CPF do profissional autorizador (dado pessoal)
    "GESTOR_CPF",  # CPF do gestor (dado pessoal)
    "GESTOR_DT",   # data do gestor (não necessária à análise)
    "IDENT",       # identificador do paciente (dado pessoal)
    "N_AIH"        # número da AIH (identificador único da internação)
  ),

  # Nomes de arquivos de saída
  arquivos = list(
    sinasc_rds = "data/processed/sinasc_rj_campos_q20_q28_2020_2024_completo.rds",
    sinasc_csv = "results/sinasc_rj_campos_q20_q28_2020_2024_completo.csv",
    sinasc_auditoria = "results/auditoria/auditoria_anual_sinasc_rj_campos_q20_q28_2020_2024.csv",
    sinasc_metadados = "results/auditoria/metadados_sinasc_rj_campos_q20_q28_2020_2024.json",
    sih_rds = "data/processed/sih_rd_rj_campos_q20_q28_menor_1ano_2020_2024_completo.rds",
    sih_csv = "results/sih_rd_rj_campos_q20_q28_menor_1ano_2020_2024_completo.csv",
    sih_auditoria = "results/auditoria/auditoria_mensal_sih_rd_rj_campos_q20_q28_2020_2024.csv",
    sih_metadados = "results/auditoria/metadados_sih_rd_rj_campos_q20_q28_2020_2024.json"
  )
)

garantir_diretorios <- function(dirs = CONFIG$dirs) {
  for (d in unlist(dirs, use.names = FALSE)) {
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
  }
  invisible(TRUE)
}
