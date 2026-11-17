# =============================================================================
# 05_poisson_ajustado.R
# Modelos de Poisson AJUSTADOS por sazonalidade e tendência temporal
# (modelo principal enxuto) e comparação com os modelos BRUTOS.
#
#   Bruto:    log(E[y]) = β0 + β1·exposições + log(nascidos)
#   Ajustado: log(E[y]) = β0 + β1·exposições + s·sin(2πm/12) + c·cos(2πm/12)
#                          + τ·t + log(nascidos)
#
# Ajusta as três famílias (Poisson, Quasi-Poisson e Binomial Negativa) para os
# dois desfechos, reporta bruto e ajustado lado a lado e GERA UM TEXTO DE
# LEITURA/CONCLUSÃO honesto. Não altera nenhum resultado anterior.
#
# Saídas em results/08_poisson_ajustado/.
#
# Uso (a partir da raiz do repositório):
#   Rscript analysis/05_poisson_ajustado.R
# =============================================================================

options(stringsAsFactors = FALSE)
Sys.setenv(TZ = "America/Sao_Paulo")

for (p in c("dplyr", "tidyr", "readr", "ggplot2", "lubridate", "MASS")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
}
invisible(lapply(c("dplyr", "tidyr", "readr", "ggplot2", "lubridate", "MASS"),
                 library, character.only = TRUE))

source("src/00_config.R")
source("src/01_utils.R")
garantir_diretorios()

# -----------------------------------------------------------------------------
# 1. Dados mensais: contagens, denominador, exposições
# -----------------------------------------------------------------------------
base <- readr::read_csv(file.path(CONFIG$dirs$descritiva, "taxas_mensais_10000.csv"),
                        show_col_types = FALSE) %>%
  dplyr::select(mes_ano, ano, mes, casos_sinasc, internacoes, nascidos)

pm25 <- readRDS(file.path(CONFIG$dirs$dados, "pm25_campos_2020_2024.rds")) %>%
  dplyr::select(mes_ano, pm25)

ler_inmet <- function(caminho) {
  d <- read.csv(caminho, skip = 8, fileEncoding = "UTF-8", stringsAsFactors = FALSE,
                check.names = FALSE, na.strings = c("", "NA", "-9999"))
  names(d) <- c("data", "hora", "precip", "pres", "presmax", "presmin", "rad",
                "temp", "temp_orv", "tmax", "tmin", "torvmax", "torvmin",
                "umax", "umin", "umid", "vdir", "vraj", "vvel")
  num <- function(x) {
    x <- as.character(x); x <- trimws(x)
    x[x %in% c("", "NA", "-9999")] <- NA
    suppressWarnings(as.numeric(sub(",", ".", x, fixed = TRUE)))
  }
  d %>% dplyr::mutate(data = as.Date(data, format = "%Y/%m/%d"),
                      dplyr::across(c(temp, umid, precip), num))
}
clima <- dplyr::bind_rows(lapply(CONFIG$anos, function(a) {
  ler_inmet(file.path("data/raw/inmet", sprintf("inmet_campos_goytacazes_%d.csv", a)))
})) %>%
  dplyr::mutate(mes_ano = as.Date(sprintf("%04d-%02d-01",
                                          lubridate::year(data), lubridate::month(data)))) %>%
  dplyr::group_by(mes_ano) %>%
  dplyr::summarise(temp_media_c = mean(temp, na.rm = TRUE),
                   precip_total_mm = sum(precip, na.rm = TRUE),
                   umid_media_pct = mean(umid, na.rm = TRUE), .groups = "drop")

dados <- base %>%
  dplyr::left_join(pm25, by = "mes_ano") %>%
  dplyr::left_join(clima, by = "mes_ano") %>%
  dplyr::arrange(mes_ano) %>%
  dplyr::mutate(t = dplyr::row_number(),
                saz_sin = sin(2 * pi * mes / 12),
                saz_cos = cos(2 * pi * mes / 12))

exposicoes <- c("temp_media_c", "precip_total_mm", "umid_media_pct", "pm25")
rot <- c(temp_media_c = "Temperatura", precip_total_mm = "Precipitação",
         umid_media_pct = "Umidade", pm25 = "MP2,5")
familias <- c("Poisson", "Quasi-Poisson", "Binomial Negativa")

# -----------------------------------------------------------------------------
# 2. Ajuste dos modelos (bruto e ajustado) nas três famílias
# -----------------------------------------------------------------------------
ajustar <- function(desfecho, ajuste = character(0), nome_desfecho,
                    rotulo, familia) {
  termos <- c(exposicoes, ajuste)
  f <- stats::as.formula(paste(desfecho, "~", paste(termos, collapse = " + "),
                               "+ offset(log(nascidos))"))
  m <- switch(familia,
    "Poisson"           = stats::glm(f, family = stats::poisson, data = dados),
    "Quasi-Poisson"     = stats::glm(f, family = stats::quasipoisson, data = dados),
    "Binomial Negativa" = suppressWarnings(MASS::glm.nb(f, data = dados))
  )
  disp <- sum(stats::residuals(m, type = "pearson")^2) / stats::df.residual(m)
  s <- summary(m)$coefficients
  ci <- tryCatch(stats::confint(m), error = function(e) stats::confint.default(m))
  data.frame(
    desfecho = nome_desfecho, familia = familia, modelo = rotulo,
    dispersao = disp, termo = rownames(s),
    irr = exp(s[, 1]), ic_inf = exp(ci[, 1]), ic_sup = exp(ci[, 2]),
    p_valor = s[, ncol(s)], stringsAsFactors = FALSE
  )
}

ajuste_saz <- c("saz_sin", "saz_cos", "t")
desfechos <- c("casos_sinasc" = "SINASC (casos mensais Q20-Q28)",
               "internacoes" = "SIH-RD (internações mensais Q20-Q28)")

modelar <- function(rotulo, ajuste) {
  dplyr::bind_rows(lapply(familias, function(fa) {
    dplyr::bind_rows(lapply(names(desfechos), function(dd) {
      ajustar(dd, ajuste, desfechos[[dd]], rotulo, fa)
    }))
  }))
}
res_bruto <- modelar("Bruto", character(0))
res_ajust <- modelar("Ajustado", ajuste_saz)

todos <- dplyr::bind_rows(res_bruto, res_ajust)
readr::write_csv(todos, file.path(CONFIG$dirs$poisson_ajustado,
                                  "poisson_bruto_vs_ajustado.csv"), na = "")

# -----------------------------------------------------------------------------
# 3. Tabela comparativa (IRR bruto × ajustado) — todas as famílias
# -----------------------------------------------------------------------------
fmt_irr <- function(irr, lo, hi, p) sprintf("%.3f (%.3f–%.3f); %.3f", irr, lo, hi, p)
comparacao <- dplyr::bind_rows(lapply(names(desfechos), function(dd) {
  dplyr::bind_rows(lapply(familias, function(fa) {
    dplyr::bind_rows(lapply(exposicoes, function(term) {
      b <- res_bruto[res_bruto$desfecho == desfechos[[dd]] & res_bruto$familia == fa &
                     res_bruto$termo == term, ]
      a <- res_ajust[res_ajust$desfecho == desfechos[[dd]] & res_ajust$familia == fa &
                     res_ajust$termo == term, ]
      data.frame(Desfecho = desfechos[[dd]], Família = fa, Exposição = rot[term],
                 `Bruto — IRR (IC95%); p` = fmt_irr(b$irr, b$ic_inf, b$ic_sup, b$p_valor),
                 `Ajustado — IRR (IC95%); p` = fmt_irr(a$irr, a$ic_inf, a$ic_sup, a$p_valor),
                 bruto_sig = b$p_valor < 0.05, ajust_sig = a$p_valor < 0.05,
                 check.names = FALSE)
    }))
  }))
}))
readr::write_csv(comparacao, file.path(CONFIG$dirs$poisson_ajustado,
                                       "comparacao_bruto_ajustado.csv"), na = "")

# -----------------------------------------------------------------------------
# 4. Figura comparativa (Poisson — modelo principal)
# -----------------------------------------------------------------------------
grafico <- todos %>%
  dplyr::filter(termo %in% exposicoes, familia == "Poisson") %>%
  dplyr::mutate(exposicao = factor(rot[termo], levels = unname(rot)),
                modelo = factor(modelo, levels = c("Bruto", "Ajustado")),
                desfecho = ifelse(grepl("^SINASC", desfecho),
                                  "SINASC (nascidos vivos)", "SIH-RD (internações)"))

fig <- ggplot(grafico, aes(x = irr, y = exposicao, color = modelo)) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "grey60") +
  geom_errorbarh(aes(xmin = ic_inf, xmax = ic_sup), height = 0.18,
                 position = position_dodge(width = 0.5)) +
  geom_point(size = 2, position = position_dodge(width = 0.5)) +
  facet_wrap(~ desfecho, ncol = 1) +
  scale_color_viridis_d(end = 0.75) +
  labs(title = "IRR bruto × ajustado (sazonalidade + tendência)",
       subtitle = "Poisson com offset (log nascidos vivos) — Campos dos Goytacazes (RJ), 2020–2024",
       x = "IRR (IC 95%)", y = NULL, color = "Modelo") +
  theme_cellpress() +
  theme(legend.position = "bottom")
ggsave(file.path(CONFIG$dirs$poisson_ajustado, "fig_irr_bruto_vs_ajustado.png"),
       fig, width = 8.5, height = 6, dpi = 300)

# -----------------------------------------------------------------------------
# 5. Texto de leitura/conclusão (gerado a partir dos resultados)
# -----------------------------------------------------------------------------
pois <- comparacao[comparacao$Família == "Poisson", ]
perderam <- pois[pois$bruto_sig & !pois$ajust_sig, ]
surgiram <- pois[!pois$bruto_sig & pois$ajust_sig, ]
permaneceram <- pois[pois$bruto_sig & pois$ajust_sig, ]

linha_perderam <- if (nrow(perderam) == 0) "  - nenhuma associação perdeu significância." else
  paste0(sprintf("  - %s × %s: passou de significativa (bruto) a não significativa (ajustado).",
                 perderam$Desfecho, perderam$Exposição), collapse = "\n")
linha_surgiram <- if (nrow(surgiram) == 0) "  - nenhuma associação emergiu com o ajuste." else
  paste0(sprintf("  - %s × %s: emergiu como significativa após o ajuste.",
                 surgiram$Desfecho, surgiram$Exposição), collapse = "\n")
linha_permaneceram <- if (nrow(permaneceram) == 0) "  - nenhuma associação permaneceu significativa." else
  paste0(sprintf("  - %s × %s: significativa em ambos os modelos.",
                 permaneceram$Desfecho, permaneceram$Exposição), collapse = "\n")

texto <- c(
  "# Leitura dos modelos de Poisson — bruto × ajustado",
  "",
  "Modelo ajustado = exposições + sin(2πm/12) + cos(2πm/12) + t (sazonalidade + tendência),",
  "com offset = log(nascidos vivos). Três famílias: Poisson, Quasi-Poisson e Binomial Negativa.",
  "",
  "## Conclusões (família Poisson — modelo principal)",
  "",
  "Associações que PERDERAM significância ao ajustar:",
  linha_perderam,
  "",
  "Associações que EMERGIRAM ao ajustar:",
  linha_surgiram,
  "",
  "Associações que PERMANECERAM significativas:",
  linha_permaneceram,
  "",
  "## Interpretação",
  "O ajuste por sazonalidade e tendência remove a parte da variação compartilhada",
  "com o calendário e com a deriva temporal. As associações que não se sustentam",
  "ao ajuste eram, em boa parte, explicadas por esse padrão temporal — o que é um",
  "achado legítimo e defensável (não um erro). Lembrar que o ajuste também reduz a",
  "precisão (intervalos mais largos), com apenas 60 meses de dados.",
  "",
  "Fonte: DATASUS (SINASC/SIH-RD), INMET A607 (clima) e VIGIAR/MS (MP2,5).")
writeLines(texto, file.path(CONFIG$dirs$poisson_ajustado, "LEITURA.md"))

# -----------------------------------------------------------------------------
# 6. Resumo no console
# -----------------------------------------------------------------------------
cat("\n===== POISSON BRUTO × AJUSTADO (modelo principal) =====\n\n")
for (dd in unique(pois$Desfecho)) {
  cat("## ", dd, "\n", sep = "")
  print(pois[pois$Desfecho == dd, c("Exposição", "Bruto — IRR (IC95%); p",
                                    "Ajustado — IRR (IC95%); p")], row.names = FALSE)
  cat("\n")
}
cat("Dispersão de Pearson (Poisson):\n")
print(todos %>% dplyr::filter(familia == "Poisson") %>%
        dplyr::distinct(desfecho, modelo, dispersao), row.names = FALSE)
cat("\n", paste(texto[8:15], collapse = "\n"), "\n", sep = "")
cat("\nSaídas em:", CONFIG$dirs$poisson_ajustado, "\n")
