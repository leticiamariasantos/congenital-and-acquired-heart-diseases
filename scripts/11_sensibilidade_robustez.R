# =============================================================================
# 11_sensibilidade_robustez.R
# Análises de sensibilidade da associação principal (umidade × internações SIH,
# Q20–Q26), avaliando estabilidade diante de escolhas metodológicas:
#   (i)   desfecho ampliado (Q20–Q28);
#   (ii)  spline da tendência com 3, 4 e 6 graus de liberdade;
#   (iii) exclusão do período pandêmico (fev/2020–abr/2022);
#   (iv)  exposição por extremo mensal (umidade mínima absoluta);
#   (v)   modelos de Binomial Negativa.
#
# Critério de robustez: mesmo sentido e significância, com magnitude semelhante.
#
# Saídas:
#   results/tables/sensibilidade_robustez.csv
#   results/text/discussao_sensibilidade_robustez.md
#
# Uso: Rscript scripts/11_sensibilidade_robustez.R  (ou via run_all.R)
# =============================================================================

if (basename(getwd()) == "scripts" && file.exists("00_config.R")) setwd("..")
stopifnot(file.exists("scripts/00_config.R"))
source("scripts/00_config.R")
source("scripts/00_utils.R")
source("scripts/03_funcoes_analise.R")   # interpolar_na
source("scripts/02_funcoes_exposicoes.R") # ler_inmet
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
  dplyr::left_join(contar(sih_q26) %>% dplyr::rename(sih_q26 = n), by = c("ano", "mes")) %>%
  dplyr::left_join(contar(sih_q28) %>% dplyr::rename(sih_q28 = n), by = c("ano", "mes")) %>%
  dplyr::left_join(totais %>% dplyr::select(ano, mes, n_nascidos), by = c("ano", "mes")) %>%
  dplyr::mutate(
    sih_q26 = tidyr::replace_na(sih_q26, 0L),
    sih_q28 = tidyr::replace_na(sih_q28, 0L),
    n_nascidos = as.numeric(n_nascidos)
  )

# Exposições médias (imputação dos meses INMET < 80%)
expo <- grade %>%
  dplyr::left_join(
    temp_umid %>% dplyr::transmute(mes_ano,
                                   temp = ifelse(qualidade_ok, temp_media_c, NA_real_),
                                   umid = ifelse(qualidade_ok, umidade_media_pct, NA_real_)),
    by = "mes_ano") %>%
  dplyr::left_join(pm25 %>% dplyr::select(mes_ano, pm25), by = "mes_ano")
expo$temp <- interpolar_na(expo$temp)
expo$umid <- interpolar_na(expo$umid)

# -----------------------------------------------------------------------------
# 2. Termos temporais e offset
# -----------------------------------------------------------------------------
t <- seq_len(nrow(dados))
time <- 2010 + (t - 1) / 12
pandemia <- as.integer(dados$mes_ano >= as.Date("2020-02-01") &
                       dados$mes_ano <= as.Date("2022-04-01"))
sin1 <- sin(2 * pi * t / 12); cos1 <- cos(2 * pi * t / 12)
sin2 <- sin(4 * pi * t / 12); cos2 <- cos(4 * pi * t / 12)

soma_rolante <- as.numeric(stats::filter(dados$n_nascidos, rep(1, 12), sides = 1))
offset_sih <- log(soma_rolante)

janela_media <- function(x, lags) {
  comps <- lapply(lags, function(l) dplyr::lag(x, l))
  Reduce(`+`, comps) / length(lags)
}
lag0_3 <- function(x) janela_media(x, 0:3)

# -----------------------------------------------------------------------------
# 3. Montagem da base do modelo (SIH, conjunto)
# -----------------------------------------------------------------------------
montar_base <- function(y, ex_temp, ex_umid, ex_pm25) {
  ex <- data.frame(temp = ex_temp, umid = ex_umid, pm25 = ex_pm25)
  iqr <- vapply(ex, function(v) stats::IQR(v, na.rm = TRUE), numeric(1))
  ex_sc <- as.data.frame(lapply(names(ex), function(nm) ex[[nm]] / iqr[nm]))
  names(ex_sc) <- names(ex)
  d <- data.frame(y = y, off = offset_sih, ex_sc,
                  sin1 = sin1, cos1 = cos1, sin2 = sin2, cos2 = cos2,
                  pandemia = pandemia, time = time)
  d[stats::complete.cases(d), ]
}

extrair_umidade <- function(d, df_spline = 7, familia = "quasipoisson",
                            incluir_pandemia = TRUE) {
  termos <- paste0("temp + umid + pm25 + splines::ns(time, df = ", df_spline,
                   ") + sin1 + cos1 + sin2 + cos2")
  if (incluir_pandemia) termos <- paste(termos, "+ pandemia")
  f <- stats::as.formula(paste0("y ~ ", termos, " + offset(off)"))

  if (familia == "quasipoisson") {
    m <- stats::glm(f, family = quasipoisson, data = d)
    ct <- tryCatch(
      lmtest::coeftest(m, vcov = sandwich::NeweyWest(m, lag = 1, prewhite = FALSE)),
      error = function(e) lmtest::coeftest(m))
  } else {
    m <- MASS::glm.nb(f, data = d)
    ct <- lmtest::coeftest(m)
  }
  est <- ct["umid", "Estimate"]; se <- ct["umid", "Std. Error"]
  p   <- ct["umid", "Pr(>|z|)"]
  data.frame(IRR = exp(est), IC95_inf = exp(est - 1.96 * se),
             IC95_sup = exp(est + 1.96 * se), p_valor = p)
}

# Exposições médias defasadas (0–3 meses)
ex_m <- data.frame(temp = lag0_3(expo$temp), umid = lag0_3(expo$umid),
                   pm25 = lag0_3(expo$pm25))

d_base <- montar_base(dados$sih_q26, ex_m$temp, ex_m$umid, ex_m$pm25)
d_q28  <- montar_base(dados$sih_q28, ex_m$temp, ex_m$umid, ex_m$pm25)

# -----------------------------------------------------------------------------
# 4. Sensibilidades
# -----------------------------------------------------------------------------
# (iv) umidade mínima absoluta mensal (a partir dos dados horários INMET)
umid_min_mensal <- dplyr::bind_rows(lapply(anos, function(a) {
  ler_inmet(file.path(CONFIG$dirs$raw_inmet,
                      sprintf("inmet_campos_goytacazes_%04d.csv", a)))
})) %>%
  dplyr::filter(!is.na(data)) %>%
  dplyr::mutate(ano = lubridate::year(data), mes = lubridate::month(data)) %>%
  dplyr::group_by(ano, mes) %>%
  dplyr::summarise(umid_min_abs = min(umid_pct, na.rm = TRUE), .groups = "drop")

# alinha à grade mensal, converte Inf (meses sem dado) em NA e imputa
umid_min_df <- grade %>%
  dplyr::left_join(umid_min_mensal, by = c("ano", "mes")) %>%
  dplyr::mutate(umid_min_abs = ifelse(is.infinite(umid_min_abs), NA_real_, umid_min_abs))
umid_min_df$umid_min_abs <- interpolar_na(umid_min_df$umid_min_abs)

ex_umid_min <- lag0_3(umid_min_df$umid_min_abs)
d_ext <- montar_base(dados$sih_q26, ex_m$temp, ex_umid_min, ex_m$pm25)

resultados <- list()
add <- function(nome, df_res) cbind(data.frame(sensibilidade = nome), df_res)

resultados[[1]] <- add("Base (Q20–Q26, spline df = 7)",
                       extrair_umidade(d_base, 7, "quasipoisson", TRUE))
resultados[[2]] <- add("(i) Desfecho Q20–Q28",
                       extrair_umidade(d_q28, 7, "quasipoisson", TRUE))
resultados[[3]] <- add("(ii) Spline df = 3",
                       extrair_umidade(d_base, 3, "quasipoisson", TRUE))
resultados[[4]] <- add("(ii) Spline df = 4",
                       extrair_umidade(d_base, 4, "quasipoisson", TRUE))
resultados[[5]] <- add("(ii) Spline df = 6",
                       extrair_umidade(d_base, 6, "quasipoisson", TRUE))
resultados[[6]] <- add("(iii) Exclui pandemia",
                       extrair_umidade(d_base[d_base$pandemia == 0, ], 7,
                                       "quasipoisson", FALSE))
resultados[[7]] <- add("(iv) Umidade mínima absoluta",
                       extrair_umidade(d_ext, 7, "quasipoisson", TRUE))
resultados[[8]] <- add("(v) Binomial Negativa",
                       extrair_umidade(d_base, 7, "nb", TRUE))

tabela <- dplyr::bind_rows(resultados) %>%
  dplyr::mutate(
    significativo = ifelse(p_valor < 0.05, "Sim", "Não"),
    IRR = round(IRR, 2),
    IC95 = sprintf("%.2f–%.2f", IC95_inf, IC95_sup),
    p_valor = round(p_valor, 3)
  ) %>%
  dplyr::select(sensibilidade, IRR, IC95, p_valor, significativo)

readr::write_csv(tabela, "results/tables/sensibilidade_robustez.csv", na = "")

cat("\n========== SENSIBILIDADE — CONCLUÍDA ==========\n")
print(as.data.frame(tabela))
cat("===============================================\n")
