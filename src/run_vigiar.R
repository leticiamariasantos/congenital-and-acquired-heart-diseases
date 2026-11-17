# =============================================================================
# run_vigiar.R
# Download de material particulado fino (PM2.5) — VIGIAR / Ministério da Saúde
#
# Usa o pacote {vigiar} (https://github.com/santosry/vigiar) para baixar a
# série mensal de PM2.5 de Campos dos Goytacazes (IBGE 330100).
#
# IMPORTANTE — filtro no servidor:
#   A tabela `df_mensal` é nacional (5570 municípios x 12 meses x 16 anos),
#   e o endpoint Power BI "Publish to Web" limita a resposta a ~30.000 linhas.
#   O download padrão do pacote (vigiar_baixar) trunca a tabela e não alcança
#   os municípios do RJ. Por isso, montamos uma consulta própria com cláusula
#   WHERE (muni = 330100L) usando a sessão ativa do vigiar e o mesmo formato
#   SemanticQueryDataShapeCommand que o pacote utiliza.
#
# Saídas:
#   data/raw/vigiar/vigiar_pm25_campos_mensal.csv   (série completa 2010–2025)
#   data/processed/pm25_campos_2020_2024.rds        (série mensal 2020–2024)
#   results/tabelas/pm25_campos_2020_2024.csv       (tabela publicável)
#
# Uso (a partir da raiz do repositório):
#   Rscript src/run_vigiar.R
# =============================================================================

options(stringsAsFactors = FALSE)
Sys.setenv(TZ = "America/Sao_Paulo")

# -----------------------------------------------------------------------------
# 1. Dependências
# -----------------------------------------------------------------------------
# {vigiar} é distribuído pelo GitHub (não está no CRAN).
if (!requireNamespace("vigiar", quietly = TRUE)) {
  if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
  remotes::install_github("santosry/vigiar", upgrade = "never")
}
for (p in c("httr2", "jsonlite", "dplyr", "tidyr", "readr", "lubridate")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
}
invisible(lapply(c("vigiar", "dplyr", "tidyr", "readr", "lubridate"),
                 library, character.only = TRUE))

source("src/00_config.R")
source("src/01_utils.R")
garantir_diretorios()
dir.create(CONFIG$dirs$raw_vigiar, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 2. Conexão e checagem do dashboard VIGIAR
# -----------------------------------------------------------------------------
vigiar_conectar()
status <- vigiar_status()

if (!isTRUE(status$tables_ok)) {
  stop("Dashboard VIGIAR indisponível ou esquema de dados inconsistente. ",
       "Tente novamente mais tarde.")
}

# -----------------------------------------------------------------------------
# 3. Consulta com filtro no servidor (muni = 330100L)
# -----------------------------------------------------------------------------
# Reproduz o formato SemanticQueryDataShapeCommand usado internamente pelo
# pacote, adicionando uma cláusula WHERE. O sufixo "L" indica literal Int64,
# exigido pelo parser do Power BI para colunas inteiras.
baixar_pm25_municipio <- function(codigo_ibge, timeout = 180) {
  sessao <- vigiar:::.vigiar_env$sessao

  coluna <- function(p) {
    list(Column = list(
      Expression = list(SourceRef = list(Source = "df_mensal")),
      Property = p
    ), Name = p)
  }

  selects <- lapply(c("muni", "UF", "ano", "mes", "pm25"), coluna)

  query_cmd <- list(
    SemanticQueryDataShapeCommand = list(
      Query = list(
        Version = 2L,
        From = list(list(Name = "df_mensal", Entity = "df_mensal")),
        Select = selects,
        Where = list(list(Condition = list(In = list(
          Expressions = list(list(Column = list(
            Expression = list(SourceRef = list(Source = "df_mensal")),
            Property = "muni"
          ))),
          Values = list(list(list(Literal = list(
            Value = sprintf("%dL", as.integer(codigo_ibge))
          ))))
        )))),
        OrderBy = list(
          list(Direction = 1L, Expression = list(Column = list(
            Expression = list(SourceRef = list(Source = "df_mensal")),
            Property = "ano"
          ))),
          list(Direction = 1L, Expression = list(Column = list(
            Expression = list(SourceRef = list(Source = "df_mensal")),
            Property = "mes"
          )))
        ),
        Top = 50000L
      ),
      Binding = list(
        Primary = list(Groupings = list(list(Projections = 0:4))),
        Version = 1L
      )
    )
  )

  corpo <- list(
    version       = 1L,
    cancelQueries = list(),
    queries       = list(list(
      Query              = list(Commands = list(query_cmd)),
      CacheKey           = "",
      QueryId            = "",
      ApplicationContext = list(
        Sources   = list(),
        DatasetId = as.character(sessao$model_id)
      )
    )),
    modelId = sessao$model_id
  )

  resposta <- vigiar:::.vigiar_executar_query(sessao, corpo, timeout = timeout)
  vigiar:::.vigiar_parse_dados(resposta, "df_mensal")
}

cat("Baixando PM2.5 mensal de Campos dos Goytacazes (330100)...\n")
pm25_bruto <- baixar_pm25_municipio(CONFIG$municipio_residencia_codigo)

if (nrow(pm25_bruto) == 0L) {
  stop("Nenhum registro retornado para o município ", CONFIG$municipio_residencia_codigo, ".")
}

# -----------------------------------------------------------------------------
# 4. Limpeza e padronização
# -----------------------------------------------------------------------------
pm25 <- pm25_bruto %>%
  dplyr::transmute(
    codigo_ibge = as.integer(muni),
    sigla_uf    = as.character(UF),
    ano         = as.integer(ano),
    mes         = as.integer(mes),
    pm25        = round(as.numeric(pm25), 3),
    mes_ano     = as.Date(sprintf("%04d-%02d-01", ano, mes))
  ) %>%
  dplyr::filter(ano %in% CONFIG$anos) %>%
  dplyr::arrange(mes_ano)

# Valor ausente explícito: se algum mês do período estiver faltando, completa a grade
grade_mensal <- data.frame(
  mes_ano = seq(as.Date("2020-01-01"), as.Date("2024-12-01"), by = "month")
)
pm25 <- grade_mensal %>%
  dplyr::left_join(pm25, by = "mes_ano") %>%
  dplyr::mutate(
    codigo_ibge = CONFIG$municipio_residencia_codigo,
    sigla_uf    = CONFIG$uf,
    ano         = lubridate::year(mes_ano),
    mes         = lubridate::month(mes_ano)
  ) %>%
  dplyr::select(mes_ano, ano, mes, codigo_ibge, sigla_uf, pm25)

# -----------------------------------------------------------------------------
# 5. Exportação
# -----------------------------------------------------------------------------
readr::write_csv(pm25_bruto,
                 file.path(CONFIG$dirs$raw_vigiar, "vigiar_pm25_campos_mensal.csv"),
                 na = "")
saveRDS(pm25, file.path(CONFIG$dirs$dados, "pm25_campos_2020_2024.rds"))
readr::write_csv(pm25,
                 file.path(CONFIG$dirs$descritiva, "pm25_campos_2020_2024.csv"),
                 na = "")

# -----------------------------------------------------------------------------
# 6. Resumo no console
# -----------------------------------------------------------------------------
cat("\n========== DOWNLOAD PM2.5 (VIGIAR) — CONCLUÍDO ==========\n")
cat("Município:", CONFIG$municipio_residencia_nome, "(",
    CONFIG$municipio_residencia_codigo, ")\n")
cat("Período baixado (bruto):", min(pm25_bruto$ano), "a", max(pm25_bruto$ano), "\n")
cat("Linhas brutas:", nrow(pm25_bruto), "\n")
cat("Série processada: 2020–2024,", nrow(pm25), "meses\n")
cat("Valores ausentes de PM2.5:", sum(is.na(pm25$pm25)), "\n")
cat("Resumo PM2.5 2020–2024 (µg/m³):\n")
print(summary(pm25$pm25))
cat("\nArquivos gerados:\n")
cat("  raw:      ", file.path(CONFIG$dirs$raw_vigiar, "vigiar_pm25_campos_mensal.csv"), "\n")
cat("  rds:      ", file.path(CONFIG$dirs$dados, "pm25_campos_2020_2024.rds"), "\n")
cat("  tabela:   ", file.path(CONFIG$dirs$descritiva, "pm25_campos_2020_2024.csv"), "\n")
cat("============================================================\n")
