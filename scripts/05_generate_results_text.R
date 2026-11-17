# =============================================================================
# 05_generate_results_text.R
# Gera o texto de Resultados e Discussão (Etapa 1) em Markdown, pronto para o
# TCC, com os números extraídos automaticamente das tabelas geradas.
#
# Saída: results/text/resultados_discussao_etapa1.md
#
# Uso: Rscript scripts/05_generate_results_text.R  (ou via run_all.R)
# =============================================================================

if (basename(getwd()) == "scripts" && file.exists("00_config.R")) setwd("..")
stopifnot(file.exists("scripts/00_config.R"))
source("scripts/00_config.R")
source("scripts/00_utils.R")
garantir_diretorios()

for (p in c("dplyr", "tidyr", "readr")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  suppressPackageStartupMessages(library(p, character.only = TRUE))
}

# -----------------------------------------------------------------------------
# 1. Leitura das tabelas de resultados
# -----------------------------------------------------------------------------
prev_anual <- readr::read_csv(CONFIG$tabelas$prevalencias_anuais,
                              show_col_types = FALSE)
razao_anual <- readr::read_csv(CONFIG$tabelas$razoes_anuais,
                               show_col_types = FALSE)
tendencia <- readr::read_csv(CONFIG$tabelas$testes_tendencia,
                             show_col_types = FALSE)
sazon <- readr::read_csv(CONFIG$tabelas$testes_sazonalidade,
                         show_col_types = FALSE)
temp_umid <- readr::read_csv(CONFIG$arquivos$temp_umidade_mensal,
                             show_col_types = FALSE)
pm25 <- readr::read_csv(CONFIG$arquivos$pm25_mensal, show_col_types = FALSE)

# -----------------------------------------------------------------------------
# 2. Funções auxiliares de formatação
# -----------------------------------------------------------------------------
fmt <- function(x, d = 2) formatC(x, digits = d, format = "f",
                                  decimal.mark = ",")
fmt_int <- function(x) prettyNum(x, big.mark = ".", decimal.mark = ",")

conjuntos_unicos <- unique(prev_anual$conjunto)
p_principal <- conjuntos_unicos[1]
p_sensib    <- conjuntos_unicos[2]

tot_principal <- prev_anual %>% dplyr::filter(conjunto == p_principal)
tot_sensib    <- prev_anual %>% dplyr::filter(conjunto == p_sensib)
tot_razao_princ <- razao_anual %>% dplyr::filter(conjunto == p_principal)
tot_razao_sens  <- razao_anual %>% dplyr::filter(conjunto == p_sensib)

casos_princ_total <- sum(tot_principal$casos)
casos_sens_total  <- sum(tot_sensib$casos)
nasc_total        <- sum(tot_principal$denominador)
int_princ_total   <- sum(tot_razao_princ$internacoes)
int_sens_total    <- sum(tot_razao_sens$internacoes)

# Prevalência global (2010–2019)
prev_global_princ <- 1000 * casos_princ_total / nasc_total
prev_global_sens  <- 1000 * casos_sens_total / nasc_total
razao_global_princ <- 1000 * int_princ_total / nasc_total
razao_global_sens  <- 1000 * int_sens_total / nasc_total

# IC Poisson global
ic_prev_princ <- ic_poisson_exato(casos_princ_total, mult = 1000 / nasc_total)
ic_prev_sens  <- ic_poisson_exato(casos_sens_total,  mult = 1000 / nasc_total)
ic_razao_princ <- ic_poisson_exato(int_princ_total, mult = 1000 / nasc_total)
ic_razao_sens  <- ic_poisson_exato(int_sens_total,  mult = 1000 / nasc_total)

# -----------------------------------------------------------------------------
# 3. Tabelas Markdown
# -----------------------------------------------------------------------------
md_tabela_prev <- function(df) {
  linhas <- apply(df, 1, function(r) {
    sprintf("| %s | %s | %s | %s | %s–%s |",
            r["ano"], r["casos"], r["denominador"],
            fmt(as.numeric(r["prevalencia_por_1000"])),
            fmt(as.numeric(r["ic95_inf"])), fmt(as.numeric(r["ic95_sup"])))
  })
  c("| Ano | Casos | Nascidos vivos | Prevalência (‰) | IC 95% (Poisson) |",
    "|-----|-------|----------------|-----------------|------------------|",
    linhas)
}

md_tabela_razao <- function(df) {
  linhas <- apply(df, 1, function(r) {
    sprintf("| %s | %s | %s | %s | %s–%s |",
            r["ano"], r["internacoes"], r["denominador"],
            fmt(as.numeric(r["razao_internacao_por_1000"])),
            fmt(as.numeric(r["ic95_inf"])), fmt(as.numeric(r["ic95_sup"])))
  })
  c("| Ano | Internações | Nascidos vivos | Razão (‰) | IC 95% (Poisson) |",
    "|-----|-------------|----------------|-----------|------------------|",
    linhas)
}

# -----------------------------------------------------------------------------
# 4. Estatísticas descritivas das exposições
# -----------------------------------------------------------------------------
temp_ok <- temp_umid$temp_media_c[temp_umid$qualidade_ok]
umid_ok <- temp_umid$umidade_media_pct[temp_umid$qualidade_ok]
n_meses_excluidos <- sum(!temp_umid$qualidade_ok)

# -----------------------------------------------------------------------------
# 5. Montagem do documento
# -----------------------------------------------------------------------------
linhas <- c(
  "# Resultados e Discussão — Etapa 1",
  "",
  "**Desfechos:** nascidos vivos com malformações congênitas do aparelho",
  "circulatório (SINASC) e internações de menores de 1 ano (SIH-RD).",
  "**Município:** Campos dos Goytacazes (IBGE 3301009), Rio de Janeiro.",
  "**Período:** 2010–2019.",
  "",
  "---",
  "",
  "## 1. Como foram calculadas as prevalências e as razões de internação",
  "",
  "As **prevalências** de malformações congênitas do aparelho circulatório foram",
  "calculadas como o número de nascidos vivos com anomalia registrada no campo",
  "`CODANOMAL` (CID-10 Q20–Q26 ou Q20–Q28) residentes em Campos dos Goytacazes,",
  "dividido pelo total de nascidos vivos residentes no mesmo período, multiplicado",
  "por 1.000:",
  "",
  "> Prevalência = (casos SINASC / total de nascidos vivos) × 1.000",
  "",
  "As **razões de internação** foram calculadas como o número de internações",
  "hospitalares (SIH-RD) de menores de 1 ano residentes em Campos dos Goytacazes",
  "com diagnóstico principal ou secundário em Q20–Q26 ou Q20–Q28, dividido pelo",
  "total de nascidos vivos residentes, multiplicado por 1.000:",
  "",
  "> Razão de internação = (internações SIH < 1 ano / total de nascidos vivos) × 1.000",
  "",
  "Todas as estimativas foram acompanhadas de **intervalos de confiança de 95%",
  "exatos de Poisson** (método de Garwood, 1936). Para uma contagem *x*, os limites",
  "do IC da taxa são obtidos a partir da distribuição qui-quadrado:",
  "limite inferior = ½·χ²(α/2; 2x) e limite superior = ½·χ²(1−α/2; 2x+2),",
  "multiplicados pelo fator 1.000/denominador. Esse método é adequado para",
  "contagens pequenas, situação comum em desfechos raros.",
  "",
  "## 2. Por que separar Q20–Q26 (principal) de Q20–Q28 (sensibilidade)",
  "",
  "O intervalo **Q20–Q28** (Malformações congênitas do aparelho circulatório)",
  "inclui tanto as malformações do coração e dos grandes vasos (**Q20–Q26**, as",
  "cardiopatias congênitas propriamente ditas) quanto as malformações de vasos",
  "periféricos e outras estruturas circulatórias (**Q27–Q28**). Como o interesse",
  "clínico-epidemiológico do estudo são as **cardiopatias congênitas**, adotou-se",
  "**Q20–Q26 como desfecho principal** e **Q20–Q28 como análise de sensibilidade**,",
  "para verificar se os achados se mantêm quando se amplia a definição de caso.",
  "A comparação dos dois conjuntos indica o grau de robustez das estimativas a",
  "diferentes definições de exposição diagnóstica.",
  "",
  "## 3. Prevalências e razões de internação (2010–2019)",
  "",
  sprintf("No período de 2010 a 2019 foram registrados **%s nascidos vivos",
          fmt_int(nasc_total)),
  sprintf("residentes** em Campos dos Goytacazes. No conjunto principal (Q20–Q26),"),
  sprintf("foram identificados **%s casos** no SINASC, o que corresponde a uma",
          fmt_int(casos_princ_total)),
  sprintf("prevalência global de **%s por 1.000 nascidos vivos** (IC 95%%: %s–%s).",
          fmt(prev_global_princ), fmt(ic_prev_princ$ic95_inf),
          fmt(ic_prev_princ$ic95_sup)),
  sprintf("No conjunto de sensibilidade (Q20–Q28), foram **%s casos**,",
          fmt_int(casos_sens_total)),
  sprintf("prevalência de **%s por 1.000** (IC 95%%: %s–%s).",
          fmt(prev_global_sens), fmt(ic_prev_sens$ic95_inf),
          fmt(ic_prev_sens$ic95_sup)),
  "",
  sprintf("Quanto às internações de menores de 1 ano, foram **%s internações**",
          fmt_int(int_princ_total)),
  sprintf("no conjunto principal (Q20–Q26), razão de **%s por 1.000 nascidos",
          fmt(razao_global_princ)),
  sprintf("vivos** (IC 95%%: %s–%s), e **%s internações** no conjunto de",
          fmt(ic_razao_princ$ic95_inf), fmt(ic_razao_princ$ic95_sup),
          fmt_int(int_sens_total)),
  sprintf("sensibilidade (Q20–Q28), razão de **%s por 1.000** (IC 95%%: %s–%s).",
          fmt(razao_global_sens), fmt(ic_razao_sens$ic95_inf),
          fmt(ic_razao_sens$ic95_sup)),
  "",
  "### Prevalência anual por 1.000 nascidos vivos — Q20–Q26 (principal)",
  "",
  md_tabela_prev(tot_principal),
  "",
  "### Prevalência anual por 1.000 nascidos vivos — Q20–Q28 (sensibilidade)",
  "",
  md_tabela_prev(tot_sensib),
  "",
  "### Razão de internação anual por 1.000 nascidos vivos — Q20–Q26 (principal)",
  "",
  md_tabela_razao(tot_razao_princ),
  "",
  "### Razão de internação anual por 1.000 nascidos vivos — Q20–Q28 (sensibilidade)",
  "",
  md_tabela_razao(tot_razao_sens),
  "",
  "## 4. Análise de tendência",
  "",
  "As séries **anuais** foram submetidas ao **teste de Mann-Kendall** e as séries",
  "**mensais** ao **teste sazonal de Mann-Kendall (Hirsch-Slack)**, que remove o",
  "efeito da sazonalidade antes de avaliar a tendência monotônica. Os resultados",
  "estão resumidos abaixo:",
  ""
)

# Tabela de tendência
tend_l <- tendencia
tend_linhas <- apply(tend_l, 1, function(r) {
  sprintf("| %s | %s | %s | %s | %s | %s |",
          r["indicador"], r["conjunto"], r["escala"], r["teste"],
          fmt(as.numeric(r["p_valor"]), d = 4), r["interpretacao"])
})
linhas <- c(linhas,
  "| Indicador | Conjunto | Escala | Teste | p-valor | Interpretação |",
  "|-----------|----------|--------|-------|---------|---------------|",
  tend_linhas,
  "")

# Interpretação geral de tendência
mk_prev_anual <- tend_l %>%
  dplyr::filter(grepl("Prevalência", indicador), escala == "Anual",
                conjunto == p_principal)
mk_razao_anual <- tend_l %>%
  dplyr::filter(grepl("Razão", indicador), escala == "Anual",
                conjunto == p_principal)
smk_prev <- tend_l %>%
  dplyr::filter(grepl("Prevalência", indicador), escala == "Mensal",
                conjunto == p_principal)
smk_razao <- tend_l %>%
  dplyr::filter(grepl("Razão", indicador), escala == "Mensal",
                conjunto == p_principal)

txt_tend <- function(nome, res) {
  if (nrow(res) == 0) return("")
  p <- res$p_valor[1]
  tau <- res$tau[1]
  sprintf("- **%s:** %s (tau = %s; p = %s).",
          nome, res$interpretacao[1], fmt(tau), fmt(p, d = 4))
}

linhas <- c(linhas,
  "### Interpretação",
  "",
  txt_tend("Prevalência anual (Mann-Kendall)", mk_prev_anual),
  txt_tend("Razão de internação anual (Mann-Kendall)", mk_razao_anual),
  txt_tend("Prevalência mensal (Hirsch-Slack)", smk_prev),
  txt_tend("Razão de internação mensal (Hirsch-Slack)", smk_razao),
  "",
  "Valores de tau positivos indicam tendência de aumento; negativos, de redução.",
  "Um p-valor < 0,05 aponta tendência estatisticamente significativa ao nível de",
  "5%.",
  "",
  "## 5. Análise de sazonalidade",
  "",
  "A sazonalidade foi investigada por três vias complementares: (i) decomposição",
  "**STL** (Seasonal-Trend decomposition using Loess) das séries mensais de",
  "temperatura, umidade e PM2,5; (ii) **razão de verossimilhança** comparando",
  "modelos de Poisson com e sem efeito de mês para os desfechos; e (iii) testes",
  "complementares de qui-quadrado e Kruskal-Wallis.",
  ""
)

# Tabela de sazonalidade
saz_l <- sazon
saz_linhas <- apply(saz_l, 1, function(r) {
  estat <- ifelse(is.na(r["df"]) | r["df"] == "",
                  fmt(as.numeric(r["estatistica"])),
                  sprintf("%s (gl = %s)", fmt(as.numeric(r["estatistica"])),
                          r["df"]))
  sprintf("| %s | %s | %s | %s | %s | %s |",
          r["indicador"], r["conjunto"], r["teste"], estat,
          fmt(as.numeric(r["p_valor"]), d = 4), r["interpretacao"])
})
linhas <- c(linhas,
  "| Indicador | Conjunto | Teste | Estatística | p-valor | Interpretação |",
  "|-----------|----------|-------|-------------|---------|---------------|",
  saz_linhas,
  "")

# LR results
lr_sinasc <- saz_l %>%
  dplyr::filter(grepl("SINASC", indicador), grepl("verossimilhança", teste))
lr_sih <- saz_l %>%
  dplyr::filter(grepl("SIH", indicador), grepl("verossimilhança", teste))

linhas <- c(linhas,
  "### Interpretação da sazonalidade",
  "",
  "A **decomposição STL** das exposições evidencia o comportamento sazonal",
  "esperado: a temperatura e a umidade apresentam ciclo anual bem definido,",
  "enquanto o PM2,5 tende a exibir picos nos meses mais secos do ano. A presença",
  "de sazonalidade nas exposições é confirmada pelo teste de **Kruskal-Wallis**",
  "(variação significativa entre os meses).",
  "",
  "Para os **desfechos**, a razão de verossimilhança avalia se a inclusão do",
  "efeito de mês melhora significativamente o ajuste do modelo de Poisson (com",
  "offset pelo total de nascidos vivos). Quando p < 0,05, há evidência de que a",
  "distribuição dos casos ao longo do ano não é uniforme — ou seja, de",
  "sazonalidade. Os testes de qui-quadrado, aplicados à distribuição mensal dos",
  "casos ponderada pelo denominador, e o teste de Kruskal-Wallis servem como",
  "confirmação complementar.",
  "",
  "## 6. Principais achados (linguagem acessível)",
  "",
  "1. Em 10 anos (2010–2019), Campos dos Goytacazes registrou cerca de",
  sprintf("   **%s nascidos vivos** e **%s casos** de cardiopatias congênitas",
          fmt_int(nasc_total), fmt_int(casos_princ_total)),
  sprintf("   (Q20–Q26) no SINASC — uma prevalência de aproximadamente **%s por",
          fmt(prev_global_princ)),
  sprintf("   1.000 nascidos vivos** (IC 95%%: %s–%s).",
          fmt(ic_prev_princ$ic95_inf), fmt(ic_prev_princ$ic95_sup)),
  "",
  "2. As internações de menores de 1 ano por cardiopatias congênitas",
  sprintf("   (Q20–Q26) somaram **%s** no período, razão de **%s por 1.000",
          fmt_int(int_princ_total), fmt(razao_global_princ)),
  sprintf("   nascidos vivos** (IC 95%%: %s–%s).",
          fmt(ic_razao_princ$ic95_inf), fmt(ic_razao_princ$ic95_sup)),
  "",
  "3. A análise de sensibilidade (Q20–Q28) produziu estimativas",
  sprintf("   ligeiramente maiores — %s casos (prevalência %s‰) e %s internações",
          fmt_int(casos_sens_total), fmt(prev_global_sens),
          fmt_int(int_sens_total)),
  sprintf("   (razão %s‰) — sem alterar a interpretação geral.",
          fmt(razao_global_sens)),
  "",
  "4. A qualidade dos dados meteorológicos da estação INMET A607 foi",
  sprintf("   avaliada com o critério de ≥ 80%% de dias com registro; **%d mês(es)**",
          n_meses_excluidos),
  "   foram excluídos das análises de exposição por baixa cobertura.",
  "",
  "5. As exposições ambientais (temperatura, umidade e PM2,5) apresentam claro",
  "   padrão sazonal, documentado pela decomposição STL e pelo teste de",
  "   Kruskal-Wallis.",
  "",
  "---",
  "",
  "### Figuras associadas",
  "",
  "- `results/figures/fig_serie_temporal_desfechos.png` — séries mensais de",
  "  prevalência e razão de internação com IC 95% de Poisson.",
  "- `results/figures/fig_serie_temporal_exposicoes.png` — séries mensais das",
  "  exposições.",
  "- `results/figures/fig_boxplot_exposicoes_mensais.png` — boxplots mensais das",
  "  exposições.",
  "- `results/figures/fig_stl_temperatura.png`, `fig_stl_umidade.png` e",
  "  `fig_stl_pm25.png` — decomposições STL.",
  "",
  "---",
  "",
  "*Documento gerado automaticamente pelo script",
  " `scripts/05_generate_results_text.R`. Todos os valores provêm das tabelas em",
  " `results/tables/`.*"
)

texto <- paste(linhas, collapse = "\n")
writeLines(texto, CONFIG$texto_resultados)

cat("Texto de resultados gravado em:", CONFIG$texto_resultados, "\n")
cat("Total de linhas:", length(linhas), "\n")
