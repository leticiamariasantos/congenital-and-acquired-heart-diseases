# =============================================================================
# 01_analise_exploratoria.R
# Análise descritiva dos casos de cardiopatias congênitas (CID-10 Q20-Q28).
#
# Gera figuras e tabelas de resumo a partir dos dados já extraídos.
# Uso (a partir da raiz do repositório):
#   Rscript analysis/01_analise_exploratoria.R
#
# Saídas:
#   results/figures/*.png
#   results/resumo_anual_casos.csv
# =============================================================================

options(stringsAsFactors = FALSE)
Sys.setenv(TZ = "America/Sao_Paulo")

pacotes <- c("dplyr", "tidyr", "ggplot2", "scales", "readr", "lubridate", "stringr")
faltantes <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltantes) > 0L) install.packages(faltantes)
invisible(lapply(pacotes, library, character.only = TRUE))

source("src/00_config.R")
garantir_diretorios()
dir.create("results", recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# Carregamento dos dados
# -----------------------------------------------------------------------------
sinasc <- readRDS(CONFIG$arquivos$sinasc_rds)
sih <- readRDS(CONFIG$arquivos$sih_rds)

sinasc <- sinasc %>%
  mutate(
    DTNASC = as.Date(DTNASC),
    IDADEMAE = as.numeric(IDADEMAE),
    ano = as.integer(format(DTNASC, "%Y")),
    mes_ano = as.Date(format(DTNASC, "%Y-%m-01"))
  )

sih <- sih %>%
  mutate(
    VAL_TOT = as.numeric(VAL_TOT),
    mes_ano = as.Date(sprintf("%04d-%02d-01", as.integer(ANO_CMPT), as.integer(MES_CMPT)))
  )

cor_bordo <- "#800020"  # cor institucional usada nas figuras

salvar_figura <- function(plot, nome, largura = 8, altura = 5) {
  ggsave(file.path(CONFIG$dirs$figuras, nome), plot = plot,
         width = largura, height = altura, dpi = 300)
  invisible(plot)
}

# -----------------------------------------------------------------------------
# SINASC — série temporal mensal (completando meses sem casos com zero)
# -----------------------------------------------------------------------------
grade_meses <- data.frame(
  mes_ano = seq(as.Date("2020-01-01"), as.Date("2024-12-01"), by = "month")
)

sinasc_mes <- sinasc %>%
  count(mes_ano, name = "n") %>%
  right_join(grade_meses, by = "mes_ano") %>%
  replace_na(list(n = 0L))

fig_sinasc_temporal <- ggplot(sinasc_mes, aes(x = mes_ano, y = n)) +
  geom_col(fill = cor_bordo, width = 25) +
  labs(
    title = "Casos de cardiopatia congênita (Q20-Q28) — SINASC",
    subtitle = "Campos dos Goytacazes (RJ), 2020–2024",
    x = "Ano", y = "Número de nascidos vivos"
  ) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y",
               expand = expansion(mult = c(0.02, 0.02))) +
  scale_y_continuous(breaks = 0:max(sinasc_mes$n)) +
  theme_bw() +
  theme(plot.title = element_text(face = "bold", hjust = 0.5),
        panel.grid.minor = element_blank())

salvar_figura(fig_sinasc_temporal, "sinasc_casos_serie_temporal_mensal.png")

# -----------------------------------------------------------------------------
# SINASC — sexo e raça/cor
# -----------------------------------------------------------------------------
fig_sinasc_sexo_raca <- sinasc %>%
  count(SEXO, RACACOR) %>%
  ggplot(aes(x = RACACOR, y = n, fill = SEXO)) +
  geom_col(position = "dodge") +
  labs(title = "Casos por raça/cor e sexo (SINASC)",
       x = "Raça/cor", y = "Número de casos", fill = "Sexo") +
  theme_bw() +
  theme(plot.title = element_text(face = "bold", hjust = 0.5))

salvar_figura(fig_sinasc_sexo_raca, "sinasc_casos_por_raca_sexo.png")

# -----------------------------------------------------------------------------
# SINASC — distribuição da idade materna
# -----------------------------------------------------------------------------
fig_sinasc_idade_mae <- ggplot(sinasc, aes(x = IDADEMAE)) +
  geom_histogram(binwidth = 2, fill = cor_bordo, color = "white") +
  labs(title = "Distribuição da idade materna (SINASC)",
       x = "Idade materna (anos)", y = "Frequência") +
  theme_bw() +
  theme(plot.title = element_text(face = "bold", hjust = 0.5))

salvar_figura(fig_sinasc_idade_mae, "sinasc_distribuicao_idade_materna.png")

# -----------------------------------------------------------------------------
# SIH — série temporal mensal de internações
# -----------------------------------------------------------------------------
sih_mes <- sih %>%
  count(mes_ano, name = "n") %>%
  right_join(grade_meses, by = "mes_ano") %>%
  replace_na(list(n = 0L))

fig_sih_temporal <- ggplot(sih_mes, aes(x = mes_ano, y = n)) +
  geom_line(color = cor_bordo, linewidth = 1) +
  geom_point(color = cor_bordo, size = 2.2) +
  labs(
    title = "Internações por cardiopatia congênita (Q20-Q28) — SIH-RD",
    subtitle = "Menores de 1 ano — Campos dos Goytacazes (RJ), 2020–2024",
    x = "Ano", y = "Número de internações"
  ) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y",
               expand = expansion(mult = c(0.02, 0.02))) +
  theme_bw() +
  theme(plot.title = element_text(face = "bold", hjust = 0.5),
        panel.grid.minor = element_blank())

salvar_figura(fig_sih_temporal, "sih_internacoes_serie_temporal_mensal.png")

# -----------------------------------------------------------------------------
# SIH — classe etária (Neonato x Lactente)
# -----------------------------------------------------------------------------
fig_sih_classe <- sih %>%
  count(classe_idade) %>%
  ggplot(aes(x = classe_idade, y = n, fill = classe_idade)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = n), vjust = -0.3) +
  labs(title = "Internações por faixa etária (SIH-RD)",
       x = "Faixa etária", y = "Número de internações") +
  scale_fill_manual(values = c("Neonato" = "#800020", "Lactente" = "#b3566b")) +
  theme_bw() +
  theme(plot.title = element_text(face = "bold", hjust = 0.5),
        legend.position = "none")

salvar_figura(fig_sih_classe, "sih_internacoes_por_classe_etaria.png")

# -----------------------------------------------------------------------------
# SIH — distribuição do custo total (VAL_TOT) por faixa etária
# -----------------------------------------------------------------------------
fig_sih_custo <- sih %>%
  filter(!is.na(VAL_TOT)) %>%
  ggplot(aes(x = classe_idade, y = VAL_TOT, fill = classe_idade)) +
  geom_boxplot() +
  scale_y_continuous(labels = scales::label_number(scale = 1e-3, suffix = " mil")) +
  labs(title = "Custo total da internação por faixa etária (SIH-RD)",
       x = "Faixa etária", y = "Valor total (R$)") +
  scale_fill_manual(values = c("Neonato" = "#800020", "Lactente" = "#b3566b")) +
  theme_bw() +
  theme(plot.title = element_text(face = "bold", hjust = 0.5),
        legend.position = "none")

salvar_figura(fig_sih_custo, "sih_custo_total_por_classe_etaria.png")

# -----------------------------------------------------------------------------
# Tabela-resumo anual (casos SINASC x internações SIH-RD)
# -----------------------------------------------------------------------------
resumo_anual <- full_join(
  sinasc %>% count(ano, name = "nascidos_vivos_q20_q28"),
  sih %>% mutate(ANO_CMPT = as.integer(ANO_CMPT)) %>%
    count(ANO_CMPT, name = "internacoes_q20_q28_menor_1ano"),
  by = c("ano" = "ANO_CMPT")
) %>%
  replace_na(list(nascidos_vivos_q20_q28 = 0L, internacoes_q20_q28_menor_1ano = 0L))

readr::write_csv(resumo_anual, "results/resumo_anual_casos.csv", na = "")

cat("\n========== ANÁLISE EXPLORATÓRIA — FINAL ==========\n")
cat("Figuras geradas em:", CONFIG$dirs$figuras, "\n")
cat("Resumo anual:", normalizePath("results/resumo_anual_casos.csv", winslash = "/"), "\n")
print(resumo_anual)
