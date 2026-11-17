# =============================================================================
# 06_sensibilidade_extremos.R
# Análise de sensibilidade: exposições em EXTREMOS (máxima/mínima absoluta do
# mês) em comparação com as MÉDIAS mensais (modelo principal).
#
# Estratégia "troca um de cada vez" (evita colinearidade): cada modelo mantém as
# demais exposições na forma de média e substitui apenas a exposição-alvo.
#
#   Temperatura : média  ×  máxima absoluta  ×  mínima absoluta
#   Umidade     : média  ×  mínima absoluta  ×  máxima absoluta
#   MP2,5       : média  ×  dias > limite OMS  ×  dias > limite CONAMA
#
# Ajusta nas duas especificações: BRUTO e AJUSTADO (sazonalidade + tendência).
# Não altera nenhum resultado anterior. Saídas em results/09_sensibilidade_extremos/.
#
# Uso (a partir da raiz do repositório):
#   Rscript analysis/06_sensibilidade_extremos.R
# =============================================================================

options(stringsAsFactors = FALSE)
Sys.setenv(TZ = "America/Sao_Paulo")

for (p in c("dplyr", "tidyr", "readr", "ggplot2", "lubridate")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
}
invisible(lapply(c("dplyr", "tidyr", "readr", "ggplot2", "lubridate"),
                 library, character.only = TRUE))

source("src/00_config.R")
source("src/01_utils.R")
garantir_diretorios()

# -----------------------------------------------------------------------------
# 1. Dados
# -----------------------------------------------------------------------------
base <- readr::read_csv(file.path(CONFIG$dirs$descritiva, "taxas_mensais_10000.csv"),
                        show_col_types = FALSE) %>%
  dplyr::select(mes_ano, ano, mes, casos_sinasc, internacoes, nascidos)

pm25 <- readRDS(file.path(CONFIG$dirs$dados, "pm25_campos_2020_2024.rds")) %>%
  dplyr::select(mes_ano, pm25)

dias <- readr::read_csv(file.path(CONFIG$dirs$raw_vigiar, "vigiar_df_dias_campos.csv"),
                        show_col_types = FALSE) %>%
  dplyr::filter(ano %in% CONFIG$anos) %>%
  dplyr::transmute(mes_ano = as.Date(sprintf("%04d-%02d-01", ano, mes)),
                   n_dias_oms, n_dias_conama)

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
  dplyr::summarise(
    temp_media = mean(temp, na.rm = TRUE),
    temp_max_abs = max(temp, na.rm = TRUE),
    temp_min_abs = min(temp, na.rm = TRUE),
    precip_total_mm = sum(precip, na.rm = TRUE),
    umid_media = mean(umid, na.rm = TRUE),
    umid_min_abs = min(umid, na.rm = TRUE),
    umid_max_abs = max(umid, na.rm = TRUE),
    .groups = "drop"
  )

dados <- base %>%
  dplyr::left_join(pm25, by = "mes_ano") %>%
  dplyr::left_join(dias, by = "mes_ano") %>%
  dplyr::left_join(clima, by = "mes_ano") %>%
  dplyr::arrange(mes_ano) %>%
  dplyr::mutate(t = dplyr::row_number(),
                saz_sin = sin(2 * pi * mes / 12),
                saz_cos = cos(2 * pi * mes / 12))

desfechos <- c("casos_sinasc" = "SINASC (casos mensais Q20-Q28)",
               "internacoes" = "SIH-RD (internações mensais Q20-Q28)")

# -----------------------------------------------------------------------------
# 2. Modelos: média (principal) × versões em extremo (troca um por vez)
# -----------------------------------------------------------------------------
media <- c("temp_media", "precip_total_mm", "umid_media", "pm25")
modelos <- list(
  "Média (principal)"            = media,
  "Temperatura máxima absoluta"  = c("temp_max_abs", "precip_total_mm", "umid_media", "pm25"),
  "Temperatura mínima absoluta"  = c("temp_min_abs", "precip_total_mm", "umid_media", "pm25"),
  "Umidade mínima absoluta"      = c("temp_media", "precip_total_mm", "umid_min_abs", "pm25"),
  "Umidade máxima absoluta"      = c("temp_media", "precip_total_mm", "umid_max_abs", "pm25"),
  "MP2,5 — dias > OMS"           = c("temp_media", "precip_total_mm", "umid_media", "n_dias_oms"),
  "MP2,5 — dias > CONAMA"        = c("temp_media", "precip_total_mm", "umid_media", "n_dias_conama")
)

coefs_modelo <- function(expos, var, ajuste, espec, rotulo, nome_desfecho) {
  f <- stats::as.formula(paste(var, "~", paste(c(expos, ajuste), collapse = " + "),
                               "+ offset(log(nascidos))"))
  m <- stats::glm(f, family = stats::poisson, data = dados)
  s <- summary(m)$coefficients
  ci <- stats::confint.default(m)
  data.frame(especificacao = espec, desfecho = nome_desfecho, modelo = rotulo,
             termo = rownames(s), irr = exp(s[, 1]),
             ic_inf = exp(ci[, 1]), ic_sup = exp(ci[, 2]),
             p_valor = s[, ncol(s)], stringsAsFactors = FALSE)
}
ajuste_saz <- c("saz_sin", "saz_cos", "t")
ajustes <- dplyr::bind_rows(lapply(c("Bruto", "Ajustado"), function(espec) {
  aj <- if (espec == "Ajustado") ajuste_saz else character(0)
  dplyr::bind_rows(lapply(names(modelos), function(mo) {
    dplyr::bind_rows(lapply(names(desfechos), function(dd) {
      coefs_modelo(modelos[[mo]], dd, aj, espec, mo, desfechos[[dd]])
    }))
  }))
}))
readr::write_csv(ajustes, file.path(CONFIG$dirs$sensibilidade, "modelos_extremos.csv"), na = "")

# Mapa Variável × Versão → (modelo, termo)
mapa <- data.frame(
  variavel = c("Temperatura", "Temperatura", "Temperatura", "Umidade", "Umidade",
               "Umidade", "Precipitação", "MP2,5", "MP2,5", "MP2,5"),
  versao = c("Média", "Máxima absoluta", "Mínima absoluta", "Média", "Mínima absoluta",
             "Máxima absoluta", "Total mensal", "Média", "Dias > OMS", "Dias > CONAMA"),
  modelo = c("Média (principal)", "Temperatura máxima absoluta",
             "Temperatura mínima absoluta", "Média (principal)", "Umidade mínima absoluta",
             "Umidade máxima absoluta", "Média (principal)", "Média (principal)",
             "MP2,5 — dias > OMS", "MP2,5 — dias > CONAMA"),
  termo = c("temp_media", "temp_max_abs", "temp_min_abs", "umid_media", "umid_min_abs",
            "umid_max_abs", "precip_total_mm", "pm25", "n_dias_oms", "n_dias_conama"),
  stringsAsFactors = FALSE
)

fmt <- function(irr, lo, hi, p) sprintf("%.3f (%.3f–%.3f); %.3f", irr, lo, hi, p)
pegar <- function(espec, dd, mo, te) {
  r <- ajustes[ajustes$especificacao == espec & ajustes$desfecho == dd &
                 ajustes$modelo == mo & ajustes$termo == te, ]
  if (nrow(r) == 0) return(NULL)
  r
}
sens <- dplyr::bind_rows(lapply(seq_len(nrow(mapa)), function(i) {
  f <- function(espec, dd) {
    r <- pegar(espec, desfechos[[dd]], mapa$modelo[i], mapa$termo[i])
    fmt(r$irr, r$ic_inf, r$ic_sup, r$p_valor)
  }
  data.frame(Variável = mapa$variavel[i], Versão = mapa$versao[i],
             `SINASC — Bruto` = f("Bruto", "casos_sinasc"),
             `SINASC — Ajustado` = f("Ajustado", "casos_sinasc"),
             `SIH-RD — Bruto` = f("Bruto", "internacoes"),
             `SIH-RD — Ajustado` = f("Ajustado", "internacoes"),
             check.names = FALSE)
}))
readr::write_csv(sens, file.path(CONFIG$dirs$sensibilidade, "sensibilidade_media_vs_extremos.csv"), na = "")

# -----------------------------------------------------------------------------
# 3. Figura: média × extremo (modelo ajustado)
# -----------------------------------------------------------------------------
graf <- ajustes %>%
  dplyr::filter(especificacao == "Ajustado") %>%
  dplyr::mutate(chave = paste(modelo, termo),
                Variável = mapa$variavel[match(chave, paste(mapa$modelo, mapa$termo))],
                Versão = mapa$versao[match(chave, paste(mapa$modelo, mapa$termo))]) %>%
  dplyr::filter(!is.na(Variável)) %>%
  dplyr::mutate(desfecho = ifelse(grepl("^SINASC", desfecho),
                                  "SINASC (nascidos vivos)", "SIH-RD (internações)"))
fig <- ggplot(graf, aes(x = irr, y = Versão, color = Variável)) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "grey60") +
  geom_errorbarh(aes(xmin = ic_inf, xmax = ic_sup), height = 0.2) +
  geom_point(size = 2) +
  facet_wrap(~ desfecho, ncol = 1, scales = "free_x") +
  scale_color_viridis_d(end = 0.85) +
  labs(title = "Análise de sensibilidade — média × extremos (modelo ajustado)",
       subtitle = "IRR (IC 95%) — Poisson com offset, ajustado por sazonalidade e tendência",
       x = "IRR (IC 95%)", y = NULL, color = "Variável") +
  theme_cellpress() +
  theme(legend.position = "bottom")
ggsave(file.path(CONFIG$dirs$sensibilidade, "fig_sensibilidade_media_vs_extremos.png"),
       fig, width = 9, height = 6.5, dpi = 300)

# -----------------------------------------------------------------------------
# 4. Texto de leitura
# -----------------------------------------------------------------------------
texto <- c(
  "# Análise de sensibilidade — exposições em extremos × médias",
  "",
  "Objetivo: verificar se a escolha da métrica de exposição (média mensal vs.",
  "extremos do mês) muda a direção/significância das associações.",
  "Modelos de Poisson com offset = log(nascidos vivos), trocando UMA exposição por vez,",
  "nas duas especificações (bruto e ajustado por sazonalidade + tendência).",
  "",
  "## O que a sensibilidade acrescenta",
  "1. ROBUSTEZ: se o resultado é o mesmo sob métricas diferentes, ganha credibilidade;",
  "   se muda, revela que a conclusão depende da escolha da exposição.",
  "2. ESPECIFICIDADE DA EXPOSIÇÃO: distingue efeito de exposição média (crônica)",
  "   de efeito de picos (agudo), o que ajuda a discutir o mecanismo biológico.",
  "3. TRANSPARÊNCIA: evita a crítica de que o achado é 'resultado de conveniência'",
  "   de uma única métrica escolhida.",
  "",
  "## Limitações",
  "Cada variante extra reduz o poder e aumenta o número de testes (múltiplas",
  "comparações). Os IRR têm unidades diferentes (por 1 °C; por 1 %; por 1 dia acima",
  "do limite), então comparar magnitudes exige cautela — o foco é a direção e a",
  "significância. Para MP2,5 não há máximo/mínimo mensal na fonte VIGIAR; o",
  "'extremo' disponível são os dias acima dos limites.",
  "",
  "Fonte: DATASUS (SINASC/SIH-RD), INMET A607 (clima) e VIGIAR/MS (MP2,5).")
writeLines(texto, file.path(CONFIG$dirs$sensibilidade, "LEITURA.md"))

# -----------------------------------------------------------------------------
# 5. Resumo no console
# -----------------------------------------------------------------------------
cat("\n===== SENSIBILIDADE: MÉDIA × EXTREMOS =====\n\n")
print(sens, row.names = FALSE)
cat("\nSaídas em:", CONFIG$dirs$sensibilidade, "\n")
