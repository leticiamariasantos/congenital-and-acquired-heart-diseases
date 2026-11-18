# =============================================================================
# 10_poisson_quasi.R
# Terceira etapa: modelos de regressão de Poisson (Quasi-Poisson) para estimar
# razões de taxas (IRR) por incremento de IQR de cada exposição.
#
#   - Desfechos modelados separadamente: SINASC e SIH-RD (Q20-Q26 e Q20-Q28).
#   - Offset: SINASC = log(nascidos do mês); SIH = log(soma de 12 meses de
#     nascidos que termina no mês corrente).
#   - Ajuste temporal: 2 pares de Fourier + spline natural (df=7) + indicador
#     pandêmico (fev/2020–abr/2022).
#   - Defasagem: nascidos vivos = 6–9 meses; internações = 0–3 meses.
#   - Modelos isolados (cada exposição) e conjunto (as três) com VIF.
#   - IRRs por incremento de IQR; IC e p com erros robustos Newey-West (HAC).
#
# Saídas:
#   results/tables/irr_poisson_quasi.csv
#   results/tables/vif_poisson_quasi.csv
#
# Uso: Rscript scripts/10_poisson_quasi.R  (ou via run_all.R)
# =============================================================================

if (basename(getwd()) == "scripts" && file.exists("00_config.R")) setwd("..")
stopifnot(file.exists("scripts/00_config.R"))
source("scripts/00_config.R")
source("scripts/00_utils.R")
source("scripts/03_funcoes_analise.R")   # interpolar_na
garantir_diretorios()

for (p in c("dplyr", "tidyr", "readr", "lubridate", "splines", "sandwich",
            "lmtest", "MASS")) {
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

grade <- expand.grid(ano = anos, mes = CONFIG$meses) %>%
  dplyr::mutate(mes_ano = as.Date(sprintf("%04d-%02d-01", ano, mes))) %>%
  dplyr::arrange(mes_ano)

contar <- function(d) d %>% dplyr::count(ano, mes, name = "n")

dados <- grade %>%
  dplyr::left_join(contar(sin_q26) %>% dplyr::rename(sinasc_q26 = n), by = c("ano", "mes")) %>%
  dplyr::left_join(contar(sih_q26) %>% dplyr::rename(sih_q26 = n), by = c("ano", "mes")) %>%
  dplyr::left_join(contar(sin_q28) %>% dplyr::rename(sinasc_q28 = n), by = c("ano", "mes")) %>%
  dplyr::left_join(contar(sih_q28) %>% dplyr::rename(sih_q28 = n), by = c("ano", "mes")) %>%
  dplyr::left_join(totais %>% dplyr::select(ano, mes, n_nascidos), by = c("ano", "mes")) %>%
  dplyr::mutate(
    dplyr::across(dplyr::starts_with(c("sinasc", "sih")), ~ tidyr::replace_na(.x, 0L)),
    n_nascidos = as.numeric(n_nascidos)
  )

# -----------------------------------------------------------------------------
# 2. Exposições (imputação dos meses INMET < 80%)
# -----------------------------------------------------------------------------
expo <- grade %>%
  dplyr::left_join(
    temp_umid %>%
      dplyr::transmute(mes_ano,
                       temp = ifelse(qualidade_ok, temp_media_c, NA_real_),
                       umid = ifelse(qualidade_ok, umidade_media_pct, NA_real_)),
    by = "mes_ano") %>%
  dplyr::left_join(pm25 %>% dplyr::select(mes_ano, pm25), by = "mes_ano")

expo$temp <- interpolar_na(expo$temp)
expo$umid <- interpolar_na(expo$umid)

# -----------------------------------------------------------------------------
# 3. Termos temporais
# -----------------------------------------------------------------------------
t <- seq_len(nrow(dados))
time <- 2010 + (t - 1) / 12
pandemia <- as.integer(dados$mes_ano >= as.Date("2020-02-01") &
                       dados$mes_ano <= as.Date("2022-04-01"))
sin1 <- sin(2 * pi * t / 12); cos1 <- cos(2 * pi * t / 12)
sin2 <- sin(4 * pi * t / 12); cos2 <- cos(4 * pi * t / 12)

# -----------------------------------------------------------------------------
# 4. Offsets
# -----------------------------------------------------------------------------
offset_sinasc <- log(dados$n_nascidos)
# soma rolante de 12 meses terminando no mês corrente
soma_rolante <- as.numeric(stats::filter(dados$n_nascidos, rep(1, 12), sides = 1))
offset_sih <- log(soma_rolante)

# -----------------------------------------------------------------------------
# 5. Defasagem das exposições
# -----------------------------------------------------------------------------
janela_media <- function(x, lags) {
  comps <- lapply(lags, function(l) dplyr::lag(x, l))
  Reduce(`+`, comps) / length(lags)
}
lag_expo <- list(
  temp_sinasc = janela_media(expo$temp, 6:9),
  umid_sinasc = janela_media(expo$umid, 6:9),
  pm25_sinasc = janela_media(expo$pm25, 6:9),
  temp_sih    = janela_media(expo$temp, 0:3),
  umid_sih    = janela_media(expo$umid, 0:3),
  pm25_sih    = janela_media(expo$pm25, 0:3)
)

# -----------------------------------------------------------------------------
# 6. Funções auxiliares
# -----------------------------------------------------------------------------
vif_manual <- function(df) {
  vapply(names(df), function(var) {
    r2 <- summary(stats::lm(stats::as.formula(paste(var, "~ .")), data = df))$r.squared
    1 / (1 - r2)
  }, numeric(1))
}

extrair_irr <- function(m, termo) {
  ct <- tryCatch(
    lmtest::coeftest(m, vcov = sandwich::NeweyWest(m, lag = 1, prewhite = FALSE)),
    error = function(e) lmtest::coeftest(m))
  est <- ct[termo, "Estimate"]
  se  <- ct[termo, "Std. Error"]
  p   <- ct[termo, "Pr(>|z|)"]
  data.frame(IRR = exp(est),
             IC95_inf = exp(est - 1.96 * se),
             IC95_sup = exp(est + 1.96 * se),
             p_valor = p)
}

acf1_residuos <- function(m) {
  r <- stats::residuals(m, type = "pearson")
  r <- r[!is.na(r)]
  if (length(r) < 3) return(NA_real_)
  stats::acf(r, plot = FALSE, lag.max = 1)$acf[2]
}

# -----------------------------------------------------------------------------
# 7. Ajuste dos modelos
# -----------------------------------------------------------------------------
expo_nomes <- c(temp = "Temperatura (°C)", umid = "Umidade relativa (%)",
                pm25 = "PM2,5 (µg/m³)")
desf_nomes <- c(sinasc = "Nascidos vivos (SINASC)", sih = "Internações (SIH-RD)")

resultados <- list()
vif_tabela <- list()

for (conj in c("Q20-Q26 (principal)", "Q20-Q28 (sensibilidade)")) {
  sufixo <- if (conj == "Q20-Q26 (principal)") "q26" else "q28"
  y_sin <- dados[[paste0("sinasc_", sufixo)]]
  y_sih <- dados[[paste0("sih_", sufixo)]]

  for (desf in c("sinasc", "sih")) {
    y      <- if (desf == "sinasc") y_sin else y_sih
    off    <- if (desf == "sinasc") offset_sinasc else offset_sih
    # exposições defasadas (escala original)
    ex <- data.frame(
      temp = lag_expo[[paste0("temp_", desf)]],
      umid = lag_expo[[paste0("umid_", desf)]],
      pm25 = lag_expo[[paste0("pm25_", desf)]]
    )

    # IQR de cada exposição (na amostra válida) e escalonamento
    iqr_vals <- vapply(ex, function(v) stats::IQR(v, na.rm = TRUE), numeric(1))
    ex_scaled <- as.data.frame(lapply(names(ex), function(nm) ex[[nm]] / iqr_vals[nm]))
    names(ex_scaled) <- names(ex)

    base <- data.frame(y = y, offset = off, ex_scaled, time = time,
                       sin1 = sin1, cos1 = cos1, sin2 = sin2, cos2 = cos2,
                       pandemia = pandemia)
    base <- base[stats::complete.cases(base), ]

    # --- modelos isolados ---
    for (expo_col in names(ex)) {
      m <- stats::glm(stats::as.formula(paste(
        "y ~", expo_col, "+ splines::ns(time, df = 7) + sin1 + cos1 + sin2 + cos2 + pandemia")),
        family = quasipoisson, offset = offset, data = base)
      irr <- extrair_irr(m, expo_col)
      resultados[[length(resultados) + 1]] <- data.frame(
        conjunto = conj, desfecho = desf_nomes[desf], modelo = "Isolado",
        exposicao = expo_nomes[expo_col],
        IQR = iqr_vals[expo_col], irr, acf1 = acf1_residuos(m))
    }

    # --- modelo conjunto ---
    m_join <- stats::glm(stats::as.formula(paste(
      "y ~ temp + umid + pm25 + splines::ns(time, df = 7) + sin1 + cos1 + sin2 + cos2 + pandemia")),
      family = quasipoisson, offset = offset, data = base)
    for (expo_col in names(ex)) {
      irr <- extrair_irr(m_join, expo_col)
      resultados[[length(resultados) + 1]] <- data.frame(
        conjunto = conj, desfecho = desf_nomes[desf], modelo = "Conjunto",
        exposicao = expo_nomes[expo_col],
        IQR = iqr_vals[expo_col], irr, acf1 = acf1_residuos(m_join))
    }

    # VIF das exposições (colinearidade)
    vif_expo <- vif_manual(base[, c("temp", "umid", "pm25")])
    vif_tabela[[length(vif_tabela) + 1]] <- data.frame(
      conjunto = conj, desfecho = desf_nomes[desf],
      t(vif_expo))
  }
}

tabela_irr <- dplyr::bind_rows(resultados) %>%
  dplyr::relocate(acf1, .after = p_valor)
tabela_vif <- dplyr::bind_rows(vif_tabela)

readr::write_csv(tabela_irr, "results/tables/irr_poisson_quasi.csv", na = "")
readr::write_csv(tabela_vif, "results/tables/vif_poisson_quasi.csv", na = "")

# -----------------------------------------------------------------------------
# 8. Resumo no console
# -----------------------------------------------------------------------------
cat("\n========== MODELOS QUASI-POISSON — CONCLUÍDOS ==========\n")
print(as.data.frame(tabela_irr %>%
        dplyr::mutate(dplyr::across(c(IRR, IC95_inf, IC95_sup, p_valor, acf1),
                                    ~ round(.x, 3)))))
cat("\nVIF (modelos conjuntos):\n")
print(as.data.frame(tabela_vif %>% dplyr::mutate(dplyr::across(3:5, ~ round(.x, 2)))))
cat("=========================================================\n")
