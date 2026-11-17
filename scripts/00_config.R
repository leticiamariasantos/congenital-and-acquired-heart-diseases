# =============================================================================
# 00_config.R
# Configurações centrais do pipeline (Etapa 1) — 2010–2019
#
# Cardiopatias congênitas e adquiridas — Campos dos Goytacazes (RJ)
#   Desfechos   : SINASC e SIH-RD (DATASUS, via pacote microdatasus)
#   Exposições  : INMET estação A607 (temperatura e umidade) e VIGIAR/MS (PM2.5)
#
# Este arquivo é a fonte única de parâmetros do pipeline. Todos os scripts o
# carregam via source("scripts/00_config.R").
# =============================================================================

CONFIG <- list(
  # ---------------------------------------------------------------------------
  # Período de análise
  # ---------------------------------------------------------------------------
  ano_inicio = 2010L,
  ano_fim    = 2019L,
  anos       = 2010:2019,
  meses      = 1:12,

  # ---------------------------------------------------------------------------
  # Abrangência geográfica
  # ---------------------------------------------------------------------------
  uf = "RJ",
  municipio_nome      = "Campos dos Goytacazes",
  municipio_codigo_7  = "3301009",   # código IBGE completo (com dígito verificador)
  municipio_codigo_6  = "330100",    # código IBGE sem dígito verificador

  # Estação meteorológica automática do INMET em Campos dos Goytacazes
  estacao_inmet = "A607",

  # ---------------------------------------------------------------------------
  # Critérios científicos (ver README.md)
  # ---------------------------------------------------------------------------
  criterios = list(
    # CID-10 — malformações congênitas do aparelho circulatório
    cid_q20_q26_regex = "^Q2[0-6]",   # desfecho principal (cardíacas congênitas)
    cid_q20_q28_regex = "^Q2[0-8]",   # análise de sensibilidade

    # Idade: "menor de 1 ano" => 0 a 364 dias de vida
    idade_menor_1_ano_max_dias = 364L,

    # Qualidade dos dados horários do INMET: manter apenas meses cuja fração de
    # dias com registro (temperatura OU umidade) seja >= 80%.
    cobertura_minima_inmet = 0.80,

    # Conversões aproximadas para o fallback por COD_IDADE (SIH)
    dias_por_mes = 30L,
    dias_por_ano = 365L
  ),

  # ---------------------------------------------------------------------------
  # Diretórios do repositório (relativos à raiz)
  # ---------------------------------------------------------------------------
  dirs = list(
    cache_raw        = "data/cache/raw",
    cache_processado = "data/cache/processed",
    dados            = "data/processed",
    raw_inmet        = "data/raw/inmet",
    raw_vigiar       = "data/raw/vigiar",
    tabelas          = "results/tables",
    figuras          = "results/figures",
    texto            = "results/text"
  ),

  # ---------------------------------------------------------------------------
  # Arquivos de saída (data/processed)
  # ---------------------------------------------------------------------------
  arquivos = list(
    internacoes_q20q26            = "data/processed/internacoes_q20q26_campos.csv",
    internacoes_q20q28            = "data/processed/internacoes_q20q28_campos.csv",
    nascidos_malformacao_q20q26   = "data/processed/nascidos_malformacao_q20q26_campos.csv",
    nascidos_malformacao_q20q28   = "data/processed/nascidos_malformacao_q20q28_campos.csv",
    nascidos_totais               = "data/processed/nascidos_totais_campos.csv",
    temp_umidade_mensal           = "data/processed/temp_umidade_mensal_A607_2010_2019.csv",
    temp_umidade_exclusoes        = "data/processed/temp_umidade_mensal_A607_2010_2019_exclusoes.csv",
    pm25_mensal                   = "data/processed/pm25_mensal_campos_2010_2019.csv",

    # VIGIAR bruto (fonte, caso já exista localmente)
    vigiar_pm25_bruto             = "data/raw/vigiar/vigiar_pm25_campos_mensal.csv"
  ),

  # ---------------------------------------------------------------------------
  # Arquivos de saída (results/tables)
  # ---------------------------------------------------------------------------
  tabelas = list(
    prevalencias_anuais       = "results/tables/prevalencias_anuais.csv",
    prevalencias_trimestrais  = "results/tables/prevalencias_trimestrais.csv",
    prevalencias_mensais      = "results/tables/prevalencias_mensais.csv",
    razoes_anuais             = "results/tables/razoes_internacao_anuais.csv",
    razoes_trimestrais        = "results/tables/razoes_internacao_trimestrais.csv",
    razoes_mensais            = "results/tables/razoes_internacao_mensais.csv",
    testes_tendencia          = "results/tables/testes_tendencia.csv",
    testes_sazonalidade       = "results/tables/testes_sazonalidade.csv"
  ),

  # Arquivo de texto para Resultados e Discussão (Etapa 1)
  texto_resultados = "results/text/resultados_discussao_etapa1.md",

  # ---------------------------------------------------------------------------
  # Colunas do SIH-RD removidas por conterem dados pessoais / identificadores
  # ---------------------------------------------------------------------------
  colunas_sensiveis_sih = c(
    "CPF_AUT", "GESTOR_CPF", "GESTOR_DT", "IDENT", "N_AIH"
  )
)

# -----------------------------------------------------------------------------
# Garante que todos os diretórios do pipeline existam.
# -----------------------------------------------------------------------------
garantir_diretorios <- function(dirs = CONFIG$dirs) {
  for (d in unlist(dirs, use.names = FALSE)) {
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
  }
  invisible(TRUE)
}
