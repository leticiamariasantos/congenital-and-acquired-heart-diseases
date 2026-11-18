# =============================================================================
# 09_exploratoria_spearman.R
# Etapa exploratória: correlação de Spearman entre exposições e desfechos
# após pré-branqueamento (remoção dos padrões temporais compartilhados).
#
#   - Desfechos: Poisson com offset = log(nascidos vivos), ajustado por dois
#     pares de harmônicos de Fourier, spline natural do tempo (df = 7) e
#     indicador pandêmico (fev/2020–abr/2022); extrai resíduos de deviance.
#   - Exposições: regressão linear contra os mesmos termos; extrai resíduos.
#   - Defasagem: nascidos vivos = média 6–9 meses antes do parto;
#     internações = média 0–3 meses antes.
#   - Spearman + Holm (6 combinações) + interpretação Mukaka (2012).
#
# Saídas:
#   results/tables/correlacao_spearman_residuos.csv
#   results/text/discussao_exploratoria_spearman.md
#
# Uso: Rscript scripts/09_exploratoria_spearman.R  (ou via run_all.R)
# =============================================================================

if (basename(getwd()) == "scripts" && file.exists("00_config.R")) setwd("..")
stopifnot(file.exists("scripts/00_config.R"))
source("scripts/00_config.R")
source("scripts/00_utils.R")
source("scripts/03_funcoes_analise.R")   # interpolar_na, paleta, theme_cellpress
garantir_diretorios()

for (p in c("dplyr", "tidyr", "readr", "lubridate", "splines")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  suppressPackageStartupMessages(library(p, character.only = TRUE))
}

anos <- 2010:2024
ler <- function(caminho) readr::read_csv(caminho, show_col_types = FALSE)

# -----------------------------------------------------------------------------
# 1. Dados (série completa 2010–2024)
# -----------------------------------------------------------------------------
totais    <- ler(CONFIG$arquivos_2010_2024$nascidos_totais)
sin_q26   <- ler(CONFIG$arquivos_2010_2024$nascidos_malformacao_q20q26)
sin_q28   <- ler(CONFIG$arquivos_2010_2024$nascidos_malformacao_q20q28)
sih_q26   <- ler(CONFIG$arquivos_2010_2024$internacoes_q20q26)
sih_q28   <- ler(CONFIG$arquivos_2010_2024$internacoes_q20q28)
temp_umid <- ler(CONFIG$arquivos_2010_2024$temp_umidade_mensal)
pm25      <- ler(CONFIG$arquivos_2010_2024$pm25_mensal)

# Grade mensal completa
grade <- expand.grid(ano = anos, mes = CONFIG$meses) %>%
  dplyr::mutate(mes_ano = as.Date(sprintf("%04d-%02d-01", ano, mes))) %>%
  dplyr::arrange(mes_ano)

contar <- function(d) d %>% dplyr::count(ano, mes, name = "n")

dados <- grade %>%
  dplyr::left_join(contar(sin_q26) %>% dplyr::rename(sinasc_q26 = n),
                   by = c("ano", "mes")) %>%
  dplyr::left_join(contar(sih_q26) %>% dplyr::rename(sih_q26 = n),
                   by = c("ano", "mes")) %>%
  dplyr::left_join(contar(sin_q28) %>% dplyr::rename(sinasc_q28 = n),
                   by = c("ano", "mes")) %>%
  dplyr::left_join(contar(sih_q28) %>% dplyr::rename(sih_q28 = n),
                   by = c("ano", "mes")) %>%
  dplyr::left_join(totais %>% dplyr::select(ano, mes, n_nascidos),
                   by = c("ano", "mes")) %>%
  dplyr::mutate(
    dplyr::across(dplyr::starts_with(c("sinasc", "sih")),
                  ~ tidyr::replace_na(.x, 0L)),
    n_nascidos = as.numeric(n_nascidos)
  )

# -----------------------------------------------------------------------------
# 2. Exposições (com imputação dos meses INMET de baixa cobertura)
# -----------------------------------------------------------------------------
expo <- grade %>%
  dplyr::left_join(
    temp_umid %>%
      dplyr::transmute(
        mes_ano,
        temp = ifelse(qualidade_ok, temp_media_c, NA_real_),
        umid = ifelse(qualidade_ok, umidade_media_pct, NA_real_)
      ),
    by = "mes_ano"
  ) %>%
  dplyr::left_join(pm25 %>% dplyr::select(mes_ano, pm25), by = "mes_ano")

expo$temp <- interpolar_na(expo$temp)
expo$umid <- interpolar_na(expo$umid)

# -----------------------------------------------------------------------------
# 3. Termos temporais compartilhados
# -----------------------------------------------------------------------------
t <- seq_len(nrow(dados))
time <- 2010 + (t - 1) / 12
pandemia <- as.integer(dados$mes_ano >= as.Date("2020-02-01") &
                       dados$mes_ano <= as.Date("2022-04-01"))
sin1 <- sin(2 * pi * t / 12); cos1 <- cos(2 * pi * t / 12)
sin2 <- sin(4 * pi * t / 12); cos2 <- cos(4 * pi * t / 12)
ns_basis <- splines::ns(time, df = 7)

formula_temporal <- function(lado_esq, df_termos) {
  stats::as.formula(paste(lado_esq,
    "~ ns_basis + sin1 + cos1 + sin2 + cos2 + pandemia"))
}

# -----------------------------------------------------------------------------
# 4. Pré-branqueamento
# -----------------------------------------------------------------------------
# Desfechos -> resíduos de deviance do Poisson
res_poisson <- function(y, offset) {
  m <- stats::glm(y ~ ns_basis + sin1 + cos1 + sin2 + cos2 + pandemia,
                  family = poisson, offset = offset)
  stats::residuals(m, type = "deviance")
}

res_linear <- function(x) {
  m <- stats::lm(x ~ ns_basis + sin1 + cos1 + sin2 + cos2 + pandemia)
  stats::residuals(m)
}

res_sin_q26 <- res_poisson(dados$sinasc_q26, log(dados$n_nascidos))
res_sih_q26 <- res_poisson(dados$sih_q26,   log(dados$n_nascidos))
res_sin_q28 <- res_poisson(dados$sinasc_q28, log(dados$n_nascidos))
res_sih_q28 <- res_poisson(dados$sih_q28,   log(dados$n_nascidos))

res_temp <- res_linear(expo$temp)
res_umid <- res_linear(expo$umid)
res_pm25 <- res_linear(expo$pm25)

# -----------------------------------------------------------------------------
# 5. Defasagem (média móvel dos resíduos das exposições)
# -----------------------------------------------------------------------------
janela_media <- function(x, lags) {
  comps <- lapply(lags, function(l) dplyr::lag(x, l))
  Reduce(`+`, comps) / length(lags)
}
lags_sinasc <- 6:9     # periconcepção + 1º trimestre
lags_sih    <- 0:3     # exposição recente

expo_lag <- function(x, desfecho) {
  if (desfecho == "sinasc") janela_media(x, lags_sinasc) else janela_media(x, lags_sih)
}

# -----------------------------------------------------------------------------
# 6. Spearman + Holm
# -----------------------------------------------------------------------------
cor_spearman <- function(y, x) {
  d <- data.frame(y = as.numeric(y), x = as.numeric(x))
  d <- d[stats::complete.cases(d), ]
  cc <- suppressWarnings(stats::cor.test(d$y, d$x, method = "spearman",
                                         exact = FALSE))
  data.frame(rho = as.numeric(cc$estimate), p_valor = cc$p.value)
}

magnitude_mukaka <- function(rho) {
  a <- abs(rho)
  dplyr::case_when(
    a < 0.30 ~ "desprezível",
    a < 0.50 ~ "fraca",
    a < 0.70 ~ "moderada",
    a < 0.90 ~ "forte",
    TRUE     ~ "muito forte"
  )
}

expo_nomes <- c(temp = "Temperatura (°C)", umid = "Umidade relativa (%)",
                pm25 = "PM2,5 (µg/m³)")
desf_nomes <- c(sinasc = "Nascidos vivos (SINASC)", sih = "Internações (SIH-RD)")

rodar <- function(conjunto, res_sin, res_sih) {
  combos <- expand.grid(expo = c("temp", "umid", "pm25"),
                        desf = c("sinasc", "sih"), stringsAsFactors = FALSE)
  res <- list()
  for (i in seq_len(nrow(combos))) {
    ex <- combos$expo[i]; df <- combos$desf[i]
    res_expo <- switch(ex, temp = res_temp, umid = res_umid, pm25 = res_pm25)
    res_desf <- if (df == "sinasc") res_sin else res_sih
    cc <- cor_spearman(res_desf, expo_lag(res_expo, df))
    res[[i]] <- data.frame(
      conjunto = conjunto,
      desfecho = desf_nomes[df],
      exposicao = expo_nomes[ex],
      lag_meses = if (df == "sinasc") "6–9" else "0–3",
      rho = cc$rho, p_valor = cc$p_valor
    )
  }
  d <- dplyr::bind_rows(res)
  d$p_holm <- stats::p.adjust(d$p_valor, method = "holm")
  d$magnitude <- magnitude_mukaka(d$rho)
  dplyr::relocate(d, lag_meses, .after = exposicao)
}

tab_q26 <- rodar("Q20-Q26 (principal)", res_sin_q26, res_sih_q26)
tab_q28 <- rodar("Q20-Q28 (sensibilidade)", res_sin_q28, res_sih_q28)
tabela <- dplyr::bind_rows(tab_q26, tab_q28)

readr::write_csv(tabela, "results/tables/correlacao_spearman_residuos.csv", na = "")

# -----------------------------------------------------------------------------
# 7. Resumo no console
# -----------------------------------------------------------------------------
fmt <- function(x, d = 3) formatC(x, digits = d, format = "f", decimal.mark = ",")
cat("\n========== CORRELAÇÃO DE SPEARMAN (RESÍDUOS) — CONCLUÍDA ==========\n")
print(as.data.frame(tabela %>%
        dplyr::mutate(dplyr::across(c(rho, p_valor, p_holm),
                                    ~ round(.x, 4)))))
cat("===================================================================\n")
