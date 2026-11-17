# =============================================================================
# run_vigiar_indicadores.R
# Download dos indicadores ambientais e de saúde do VIGIAR (Ministério da Saúde)
# para Campos dos Goytacazes (RJ) e para o estado do Rio de Janeiro.
#
# Complementa src/run_vigiar.R (que baixa o PM2.5 mensal, `df_mensal`).
#
# Tabelas baixadas:
#   df_anual ............ PM2.5 anual + categorias OMS/CONAMA (municipal)
#   df_dias ............. dias acima dos limites OMS/CONAMA (municipal/mensal)
#   pop ................. população por faixa/categoria (municipal/anual)
#   tb_muni ............. indicadores de saúde atribuíveis ao PM2.5 (municipal)
#   df_indoor ........... exposição indoor a combustíveis sólidos (estadual)
#   df_indoor_desfecho .. desfechos de saúde da exposição indoor (estadual)
#   tb_fracao ........... fração atribuível (municipal; filtrado em R)
#   tb_brasil / tb_uf ... fração atribuível agregada (Brasil / UF)
#
# IMPORTANTE — filtro no servidor:
#   O endpoint Power BI "Publish to Web" limita a resposta a ~30.000 linhas.
#   As tabelas nacionais são truncadas pelo download padrão. Por isso montamos
#   consultas com cláusula WHERE (literal Int64 com sufixo "L") usando a sessão
#   ativa do vigiar.
#
# Saídas (em data/raw/vigiar/):
#   vigiar_df_anual_campos.csv, vigiar_df_dias_campos.csv, ...
#
# Uso (a partir da raiz do repositório):
#   Rscript src/run_vigiar_indicadores.R
# =============================================================================

options(stringsAsFactors = FALSE)
Sys.setenv(TZ = "America/Sao_Paulo")

# -----------------------------------------------------------------------------
# 1. Dependências
# -----------------------------------------------------------------------------
if (!requireNamespace("vigiar", quietly = TRUE)) {
  if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
  remotes::install_github("santosry/vigiar", upgrade = "never")
}
for (p in c("dplyr", "readr")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
}
invisible(lapply(c("vigiar", "dplyr", "readr"), library, character.only = TRUE))

source("src/00_config.R")
source("src/01_utils.R")
garantir_diretorios()
dir.create(CONFIG$dirs$raw_vigiar, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 2. Conexão
# -----------------------------------------------------------------------------
vigiar_conectar()
status <- vigiar_status()
if (!isTRUE(status$tables_ok)) {
  stop("Dashboard VIGIAR indisponível ou esquema inconsistente.")
}

# -----------------------------------------------------------------------------
# 3. Consulta com filtro no servidor
# -----------------------------------------------------------------------------
baixar_onde <- function(tabela, colunas, col_filtro, valor_literal, top = 50000L) {
  sessao <- vigiar:::.vigiar_env$sessao
  selects <- lapply(colunas, function(p) {
    list(Column = list(Expression = list(SourceRef = list(Source = tabela)), Property = p),
         Name = p)
  })
  n <- length(colunas)
  query_cmd <- list(
    SemanticQueryDataShapeCommand = list(
      Query = list(
        Version = 2L,
        From = list(list(Name = tabela, Entity = tabela)),
        Select = selects,
        Where = list(list(Condition = list(In = list(
          Expressions = list(list(Column = list(
            Expression = list(SourceRef = list(Source = tabela)),
            Property = col_filtro
          ))),
          Values = list(list(list(Literal = list(Value = valor_literal))))
        )))),
        Top = top
      ),
      Binding = list(
        Primary = list(Groupings = list(list(Projections = 0:(n - 1L)))),
        Version = 1L
      )
    )
  )
  corpo <- list(
    version = 1L, cancelQueries = list(),
    queries = list(list(
      Query = list(Commands = list(query_cmd)), CacheKey = "", QueryId = "",
      ApplicationContext = list(Sources = list(), DatasetId = as.character(sessao$model_id))
    )),
    modelId = sessao$model_id
  )
  vigiar:::.vigiar_parse_dados(vigiar:::.vigiar_executar_query(sessao, corpo, timeout = 180), tabela)
}

salvar <- function(dados, nome) {
  caminho <- file.path(CONFIG$dirs$raw_vigiar, nome)
  readr::write_csv(dados, caminho, na = "")
  cat(sprintf("  -> %d x %d salvo em %s\n", nrow(dados), ncol(dados), caminho))
  invisible(dados)
}

COD <- as.integer(CONFIG$municipio_residencia_codigo)  # 330100
UF_RJ <- 33L                                           # prefixo IBGE do RJ

cat("\n===== Indicadores VIGIAR =====\n")

# -- df_anual: PM2.5 anual + categorias OMS/CONAMA (municipal)
cat("\n[1/8] df_anual (Campos)\n")
df_anual <- baixar_onde(
  "df_anual",
  c("UF", "ano", "Media_pm25", "Categoria_pm25", "Categoria_pm25_conama", "muni"),
  "muni", sprintf("%dL", COD)
)
salvar(df_anual, "vigiar_df_anual_campos.csv")

# -- df_dias: dias acima dos limites OMS/CONAMA (municipal/mensal)
cat("\n[2/8] df_dias (Campos)\n")
df_dias <- baixar_onde(
  "df_dias",
  c("ID_MUNI", "t_dias", "mes", "ano", "n_dias_conama", "n_dias_oms"),
  "ID_MUNI", sprintf("%dL", COD)
)
salvar(df_dias, "vigiar_df_dias_campos.csv")

# -- pop: população por categoria (municipal/anual)
cat("\n[3/8] pop (Campos)\n")
pop <- baixar_onde(
  "pop",
  c("muni", "ano", "pop", "categoria", "UF"),
  "muni", sprintf("%dL", COD)
)
salvar(pop, "vigiar_pop_campos.csv")

# -- tb_muni: indicadores de saúde atribuíveis ao PM2.5 (municipal)
cat("\n[4/8] tb_muni (Campos)\n")
tb_muni <- baixar_onde(
  "tb_muni",
  c("Indicador", "est", "low", "high", "desfecho", "ano", "loc",
    "Alerta", "cod_mun", "populacao_2025", "habitantes"),
  "cod_mun", sprintf("%dL", COD)
)
salvar(tb_muni, "vigiar_tb_muni_campos.csv")

# -- df_indoor: exposição indoor a combustíveis sólidos (estadual)
cat("\n[5/8] df_indoor (RJ)\n")
df_indoor <- baixar_onde(
  "df_indoor",
  c("Code", "Ano", "comb_sol", "pop_exposta", "percent_comb",
    "cor_comb", "cor_pop", "Quartis", "CV", "cor_CV"),
  "Code", sprintf("%dL", UF_RJ)
)
salvar(df_indoor, "vigiar_df_indoor_rj.csv")

# -- df_indoor_desfecho: desfechos da exposição indoor (estadual)
cat("\n[6/8] df_indoor_desfecho (RJ)\n")
df_indoor_desfecho <- baixar_onde(
  "df_indoor_desfecho",
  c("Code", "State.x", "Ano", "parametro", "sexo", "pop", "comb_sol_perc",
    "comb_sol", "CV_comb_sol_perc", "Classifc_CV", "indicador", "est", "low",
    "up", "cor_est", "Quartis", "Q1", "Q2", "Q3"),
  "Code", sprintf("%dL", UF_RJ)
)
salvar(df_indoor_desfecho, "vigiar_df_indoor_desfecho_rj.csv")

# -- tb_fracao: fração atribuível (municipal; baixa tudo e filtra em R)
cat("\n[7/8] tb_fracao (filtro em R: Campos dos Goytacazes)\n")
tb_fracao_full <- tryCatch(
  vigiar_baixar("tb_fracao", uf = NULL, timeout = 180),
  error = function(e) { warning("Falha em tb_fracao: ", conditionMessage(e)); NULL }
)
if (!is.null(tb_fracao_full)) {
  salvar(tb_fracao_full, "vigiar_tb_fracao_brasil.csv")
  tb_fracao_campos <- tb_fracao_full[grepl("Campos dos Goytacazes", tb_fracao_full$n,
                                           ignore.case = TRUE), ]
  if (nrow(tb_fracao_campos) > 0) salvar(tb_fracao_campos, "vigiar_tb_fracao_campos.csv")
}

# -- tb_brasil / tb_uf: fração atribuível agregada (contexto)
cat("\n[8/8] tb_brasil / tb_uf (contexto)\n")
tb_brasil <- tryCatch(vigiar_baixar("tb_brasil", uf = NULL, timeout = 180),
                      error = function(e) NULL)
if (!is.null(tb_brasil)) salvar(tb_brasil, "vigiar_tb_brasil.csv")
tb_uf <- tryCatch(vigiar_baixar("tb_uf", uf = NULL, timeout = 180),
                  error = function(e) NULL)
if (!is.null(tb_uf)) {
  salvar(tb_uf, "vigiar_tb_uf.csv")
  tb_uf_rj <- tb_uf[grepl("Rio de Janeiro|RJ", tb_uf$loc), ]
  if (nrow(tb_uf_rj) > 0) salvar(tb_uf_rj, "vigiar_tb_uf_rj.csv")
}

cat("\n===== Download de indicadores VIGIAR concluído =====\n")
cat("Arquivos em:", CONFIG$dirs$raw_vigiar, "\n")
