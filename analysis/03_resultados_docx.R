# =============================================================================
# 03_resultados_docx.R
# Gera a seção de RESULTADOS (figura + tabelas) e atualiza o PRÉ-PROJETO.docx.
#
# - 5 elementos no total: 1 figura + 4 tabelas.
# - Sem discussão: apenas títulos, tabelas/figuras e notas de fonte.
#
# Uso (a partir da raiz do repositório):
#   Rscript analysis/03_resultados_docx.R
# =============================================================================

options(stringsAsFactors = FALSE)
Sys.setenv(TZ = "America/Sao_Paulo")

for (p in c("dplyr", "tidyr", "readr", "ggplot2", "officer", "flextable",
            "lubridate")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
}
invisible(lapply(c("dplyr", "tidyr", "readr", "ggplot2", "officer",
                   "flextable", "lubridate"), library, character.only = TRUE))

source("src/00_config.R")
source("src/01_utils.R")
garantir_diretorios()

DOCX <- "PRÉ-PROJETO.docx"

# -----------------------------------------------------------------------------
# 1. Dados
# -----------------------------------------------------------------------------
# Desfechos anuais e mensais
sinasc <- readRDS(CONFIG$arquivos$sinasc_rds)
sih <- readRDS(CONFIG$arquivos$sih_rds)

sinasc <- sinasc %>% dplyr::mutate(
  DTNASC = as.Date(DTNASC),
  ano = lubridate::year(DTNASC),
  mes = lubridate::month(DTNASC),
  mes_ano = as.Date(sprintf("%04d-%02d-01", ano, mes))
)
sih <- sih %>% dplyr::mutate(
  ano = as.integer(ANO_CMPT), mes = as.integer(MES_CMPT),
  mes_ano = as.Date(sprintf("%04d-%02d-01", ano, mes))
)
grade <- data.frame(mes_ano = seq(as.Date("2020-01-01"), as.Date("2024-12-01"), by = "month"))

sinasc_mes <- sinasc %>% dplyr::count(mes_ano, name = "casos_sinasc") %>%
  dplyr::right_join(grade, by = "mes_ano") %>%
  tidyr::replace_na(list(casos_sinasc = 0L)) %>% dplyr::arrange(mes_ano)
sih_mes <- sih %>% dplyr::count(mes_ano, name = "internacoes_sih") %>%
  dplyr::right_join(grade, by = "mes_ano") %>%
  tidyr::replace_na(list(internacoes_sih = 0L)) %>% dplyr::arrange(mes_ano)

sinasc_ano <- sinasc %>% dplyr::count(ano, name = "nascidos") %>% dplyr::arrange(ano)
sih_ano <- sih %>% dplyr::count(ano, name = "internacoes") %>% dplyr::arrange(ano)

# PM2.5 mensal (VIGIAR) e anual
pm25_mes <- readRDS(file.path(CONFIG$dirs$dados, "pm25_campos_2020_2024.rds")) %>%
  dplyr::select(mes_ano, pm25)
pm25_ano <- readr::read_csv(file.path(CONFIG$dirs$raw_vigiar, "vigiar_df_anual_campos.csv"),
                            show_col_types = FALSE) %>%
  dplyr::filter(ano %in% CONFIG$anos) %>%
  dplyr::select(ano, pm25_anual = Media_pm25)

dias_oms <- readr::read_csv(file.path(CONFIG$dirs$raw_vigiar, "vigiar_df_dias_campos.csv"),
                            show_col_types = FALSE) %>%
  dplyr::filter(ano %in% CONFIG$anos) %>%
  dplyr::group_by(ano) %>%
  dplyr::summarise(dias_acima_oms = sum(n_dias_oms, na.rm = TRUE), .groups = "drop")

# Temperatura média mensal (INMET A607)
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
  dplyr::summarise(temp_media_c = mean(temp, na.rm = TRUE), .groups = "drop")

# Tabelas de resultados da análise inferencial
mk <- readr::read_csv(file.path(CONFIG$dirs$mann_kendall, "resumo_mann_kendall.csv"), show_col_types = FALSE)
spr <- readr::read_csv(file.path(CONFIG$dirs$spearman, "resumo_spearman.csv"), show_col_types = FALSE)
spr_taxas <- readr::read_csv(file.path(CONFIG$dirs$spearman, "resumo_spearman_taxas.csv"),
                             show_col_types = FALSE)
poa <- readr::read_csv(file.path(CONFIG$dirs$poisson_ajustado, "poisson_bruto_vs_ajustado.csv"),
                       show_col_types = FALSE)
dlnm_tab <- readr::read_csv(file.path(CONFIG$dirs$dlnm, "resumo_dlnm.csv"),
                            show_col_types = FALSE)
sens_num <- readr::read_csv(file.path(CONFIG$dirs$sensibilidade, "modelos_extremos.csv"),
                            show_col_types = FALSE)
poi <- readr::read_csv(file.path(CONFIG$dirs$poisson, "resumo_familias_contagem.csv"), show_col_types = FALSE)
tb_muni <- readr::read_csv(file.path(CONFIG$dirs$raw_vigiar, "vigiar_tb_muni_campos.csv"),
                           show_col_types = FALSE)

# Séries temporais — taxas, tendência e sazonalidade (analysis/04)
tax_anual <- readr::read_csv(file.path(CONFIG$dirs$descritiva, "taxas_anuais_10000.csv"),
                             show_col_types = FALSE)
tend <- readr::read_csv(file.path(CONFIG$dirs$descritiva, "tendencia_mann_kendall.csv"),
                        show_col_types = FALSE)
sazon <- readr::read_csv(file.path(CONFIG$dirs$descritiva, "sazonalidade_mensal.csv"),
                         show_col_types = FALSE)
test_saz <- readr::read_csv(file.path(CONFIG$dirs$descritiva, "testes_sazonalidade.csv"),
                            show_col_types = FALSE)

# -----------------------------------------------------------------------------
# 2. FIGURA 1 — séries temporais mensais
# -----------------------------------------------------------------------------
painel <- grade %>%
  dplyr::left_join(sinasc_mes, by = "mes_ano") %>%
  dplyr::left_join(sih_mes, by = "mes_ano") %>%
  dplyr::left_join(pm25_mes, by = "mes_ano") %>%
  dplyr::left_join(clima, by = "mes_ano") %>%
  tidyr::pivot_longer(-mes_ano, names_to = "variavel", values_to = "valor") %>%
  dplyr::mutate(variavel = factor(variavel,
    levels = c("casos_sinasc", "internacoes_sih", "pm25", "temp_media_c"),
    labels = c("A   Nascidos vivos Q20-Q28 (SINASC)",
               "B   Internações Q20-Q28 <1 ano (SIH-RD)",
               "C   PM2,5 (µg/m³)", "D   Temperatura média (°C)")))

fig1 <- ggplot(painel, aes(x = mes_ano, y = valor, color = variavel)) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1.3) +
  facet_wrap(~ variavel, ncol = 2, scales = "free_y") +
  scale_color_viridis_d(end = 0.85) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  labs(x = "Ano", y = NULL,
       title = "Séries temporais mensais — desfechos e exposições ambientais",
       subtitle = "Campos dos Goytacazes (RJ), 2020–2024") +
  theme_cellpress(base_size = 8) +
  theme(legend.position = "none")

fig1_path <- file.path(CONFIG$dirs$descritiva, "fig_resultados_series_temporais.png")
fig2_path <- file.path(CONFIG$dirs$descritiva, "fig_taxas_mensais.png")
fig3_path <- file.path(CONFIG$dirs$descritiva, "fig_sazonalidade_mensal.png")
fig4_path <- file.path(CONFIG$dirs$descritiva, "fig_decomposicao_stl.png")
fig5_path <- file.path(CONFIG$dirs$spearman, "fig_matriz_correlacao_spearman_taxas.png")
fig6_path <- file.path(CONFIG$dirs$poisson_ajustado, "fig_irr_bruto_vs_ajustado.png")
fig7_path <- file.path(CONFIG$dirs$dlnm, "fig_dlnm_temperatura.png")
fig8_path <- file.path(CONFIG$dirs$sensibilidade, "fig_sensibilidade_media_vs_extremos.png")
ggsave(fig1_path, fig1, width = 8, height = 6, dpi = 300)

# -----------------------------------------------------------------------------
# 3. TABELAS
# -----------------------------------------------------------------------------
# Tabela 1 — descritiva anual
tab1 <- data.frame(ano = CONFIG$anos) %>%
  dplyr::left_join(sinasc_ano, by = "ano") %>%
  dplyr::left_join(sih_ano, by = "ano") %>%
  dplyr::left_join(pm25_ano, by = "ano") %>%
  dplyr::left_join(dias_oms, by = "ano") %>%
  tidyr::replace_na(list(nascidos = 0L, internacoes = 0L, dias_acima_oms = 0L)) %>%
  dplyr::mutate(
    `Nascidos vivos (SINASC)` = nascidos,
    `Internações <1 ano (SIH-RD)` = internacoes,
    `PM2,5 anual (µg/m³)` = round(pm25_anual, 2),
    `Dias acima do limite OMS` = dias_acima_oms
  ) %>%
  dplyr::select(Ano = ano, `Nascidos vivos (SINASC)`, `Internações <1 ano (SIH-RD)`,
                `PM2,5 anual (µg/m³)`, `Dias acima do limite OMS`) %>%
  dplyr::mutate(Ano = as.character(Ano))
tab1 <- dplyr::bind_rows(tab1, data.frame(
  Ano = "Total",
  `Nascidos vivos (SINASC)` = sum(tab1$`Nascidos vivos (SINASC)`),
  `Internações <1 ano (SIH-RD)` = sum(tab1$`Internações <1 ano (SIH-RD)`),
  `PM2,5 anual (µg/m³)` = round(mean(tab1$`PM2,5 anual (µg/m³)`), 2),
  `Dias acima do limite OMS` = sum(tab1$`Dias acima do limite OMS`),
  check.names = FALSE))

# Tabela 2 — Spearman (exposição x desfecho), formato largo
mk_sin <- mk$tau[mk$serie == "SINASC — nascidos vivos Q20-Q28 (anual)"]
mk_sih <- mk$tau[mk$serie == "SIH-RD — internações Q20-Q28 <1 ano (anual)"]
p_sin <- mk$p_valor[mk$serie == "SINASC — nascidos vivos Q20-Q28 (anual)"]
p_sih <- mk$p_valor[mk$serie == "SIH-RD — internações Q20-Q28 <1 ano (anual)"]

fmt_rho <- function(rho, p) sprintf("%.2f (%.3f)", rho, p)
get_rho <- function(v1, v2) {
  i <- which((spr$variavel_1 == v1 & spr$variavel_2 == v2) |
             (spr$variavel_1 == v2 & spr$variavel_2 == v1))
  c(rho = spr$rho[i], p = spr$p_valor[i])
}
exposicoes <- c("Temperatura média (°C)" = "Temperatura média (°C)",
                "Precipitação total (mm)" = "Precipitação total (mm)",
                "Umidade relativa (%)" = "Umidade relativa (%)",
                "PM2,5 (µg/m³)" = "PM2.5 (µg/m³)")
tab2 <- dplyr::bind_rows(lapply(names(exposicoes), function(ex) {
  s <- get_rho("Casos SINASC (Q20-Q28)", exposicoes[[ex]])
  i <- get_rho("Internações SIH-RD (<1 ano)", exposicoes[[ex]])
  data.frame(Exposição = ex,
             `SINASC rho (p)` = fmt_rho(s["rho"], s["p"]),
             `SIH-RD rho (p)` = fmt_rho(i["rho"], i["p"]),
             check.names = FALSE)
}))

# Tabela 3 — Poisson (IRR, IC95%, p)
poi_pois <- poi %>% dplyr::filter(modelo == "Poisson")
rotulos <- c(temp_media_c = "Temperatura média (°C)",
             precip_total_mm = "Precipitação total (mm)",
             umid_media_pct = "Umidade relativa (%)",
             pm25 = "PM2,5 (µg/m³)")
fmt_irr <- function(irr, lo, hi, p) sprintf("%.3f (%.3f–%.3f); %.3f", irr, lo, hi, p)
tab3 <- dplyr::bind_rows(lapply(names(rotulos), function(term) {
  s <- poi_pois[poi_pois$desfecho == "SINASC (casos mensais Q20-Q28)" &
                poi_pois$termo == term, ]
  i <- poi_pois[poi_pois$desfecho == "SIH-RD (internações mensais Q20-Q28)" &
                poi_pois$termo == term, ]
  data.frame(Exposição = rotulos[[term]],
             `SINASC IRR (IC95%); p` = fmt_irr(s$irr, s$ic95_inf, s$ic95_sup, s$p_valor),
             `SIH-RD IRR (IC95%); p` = fmt_irr(i$irr, i$ic95_inf, i$ic95_sup, i$p_valor),
             check.names = FALSE)
}))

# Tabela 4 — óbitos atribuíveis ao PM2.5 (VIGIAR), por causa e triênio
tri <- c("2020-2022", "2023-2025")
tb4 <- tb_muni %>%
  dplyr::filter(Indicador == "Número estimado de óbitos atribuíveis", ano %in% tri) %>%
  dplyr::select(desfecho, ano, est, low, high)
fmt_ob <- function(est, low, high) sprintf("%.0f (%.0f–%.0f)", est, low, high)
tab4 <- dplyr::bind_rows(lapply(unique(tb4$desfecho), function(dd) {
  a <- tb4[tb4$desfecho == dd & tb4$ano == tri[1], ]
  b <- tb4[tb4$desfecho == dd & tb4$ano == tri[2], ]
  data.frame(`Grupo de causas` = dd,
             `2020–2022 (IC95%)` = fmt_ob(a$est, a$low, a$high),
             `2023–2025 (IC95%)` = fmt_ob(b$est, b$low, b$high),
             check.names = FALSE)
}))
tab4 <- tab4[order(tab4$`Grupo de causas`), ]

# --- Tabelas da 1ª etapa metodológica: taxas, tendência e sazonalidade ---
br_num <- function(x, dig = 1) {
  ifelse(is.na(x), "—", formatC(x, format = "f", digits = dig, decimal.mark = ","))
}
fmt_ic <- function(x, lo, hi, dig = 1) {
  sprintf("%s (%s–%s)", br_num(x, dig), br_num(lo, dig), br_num(hi, dig))
}
fmt_p <- function(p) {
  ifelse(is.na(p), "—", ifelse(p < 0.001, "< 0,001", br_num(p, 3)))
}
rot_desf <- c("SINASC (nascidos vivos Q20-Q28)" = "SINASC",
              "SIH-RD (internações Q20-Q28 <1 ano)" = "SIH-RD")

# Tabela 5 — taxas anuais por 10.000 nascidos vivos (IC 95%)
tab5 <- tax_anual %>%
  dplyr::transmute(Ano = as.character(ano),
                   `Nascidos vivos` = format(nascidos, scientific = FALSE, big.mark = ""),
                   `SINASC — taxa (IC95%)` = fmt_ic(taxa_sinasc, sinasc_inf, sinasc_sup),
                   `SIH-RD — taxa (IC95%)` = fmt_ic(taxa_sih, sih_inf, sih_sup))

# Tabela 6 — testes de tendência
tab6 <- tend %>%
  dplyr::transmute(Desfecho = rot_desf[desfecho], Nível = nivel, Teste = teste,
                   tau = br_num(tau, 2), S = as.character(S),
                   `p-valor` = fmt_p(p_valor))

# Tabela 7 — taxa por mês-calendário (IC 95%)
tab7 <- sazon %>%
  dplyr::transmute(Mês = mes_nome,
                   `SINASC — taxa (IC95%)` = fmt_ic(taxa_sinasc, sinasc_inf, sinasc_sup),
                   `SIH-RD — taxa (IC95%)` = fmt_ic(taxa_sih, sih_inf, sih_sup))

# Tabela 8 — testes de sazonalidade
tab8 <- test_saz %>%
  dplyr::transmute(Desfecho = rot_desf[desfecho], Teste = teste,
                   Estatística = br_num(estatistica, 2), gl = as.character(gl),
                   `p-valor` = fmt_p(p_valor))

# Tabela 9 — Spearman sobre as TAXAS mensais (por 10.000 NV)
get_rho_taxa <- function(v1, v2) {
  i <- which((spr_taxas$variavel_1 == v1 & spr_taxas$variavel_2 == v2) |
             (spr_taxas$variavel_1 == v2 & spr_taxas$variavel_2 == v1))
  c(rho = spr_taxas$rho[i], p = spr_taxas$p_valor[i])
}
exposicoes_taxa <- c("Temperatura média (°C)", "Precipitação total (mm)",
                     "Umidade relativa (%)", "PM2.5 (µg/m³)")
tab9 <- dplyr::bind_rows(lapply(exposicoes_taxa, function(ex) {
  s <- get_rho_taxa("Taxa SINASC (por 10.000 NV)", ex)
  i <- get_rho_taxa("Taxa SIH-RD (por 10.000 NV)", ex)
  data.frame(Exposição = ex,
             `Taxa SINASC — rho (p)` = sprintf("%s (%s)", br_num(s["rho"], 2), fmt_p(s["p"])),
             `Taxa SIH-RD — rho (p)` = sprintf("%s (%s)", br_num(i["rho"], 2), fmt_p(i["p"])),
             check.names = FALSE)
}))

# Tabelas 10 e 11 — Poisson bruto × ajustado nas 3 famílias
rot_expo <- c(temp_media_c = "Temperatura", precip_total_mm = "Precipitação",
              umid_media_pct = "Umidade", pm25 = "MP2,5")
niv_fam <- c("Poisson", "Quasi-Poisson", "Binomial Negativa")
fmt_irma <- function(irr, lo, hi, p) sprintf("%s (%s–%s); %s", br_num(irr, 3),
                                             br_num(lo, 3), br_num(hi, 3), fmt_p(p))
tab_comp <- poa %>%
  dplyr::filter(termo %in% names(rot_expo)) %>%
  dplyr::mutate(Exposição = rot_expo[termo], Família = familia,
                valor = fmt_irma(irr, ic_inf, ic_sup, p_valor)) %>%
  dplyr::select(desfecho, Exposição, Família, modelo, valor) %>%
  tidyr::pivot_wider(names_from = modelo, values_from = valor) %>%
  dplyr::rename(`Bruto — IRR (IC95%); p` = Bruto,
                `Ajustado — IRR (IC95%); p` = Ajustado) %>%
  dplyr::mutate(Exposição = factor(Exposição, levels = unname(rot_expo)),
                Família = factor(Família, levels = niv_fam)) %>%
  dplyr::arrange(Exposição, Família) %>%
  dplyr::mutate(Exposição = as.character(Exposição), Família = as.character(Família))
slim <- function(dd) tab_comp %>%
  dplyr::filter(desfecho == dd) %>%
  dplyr::select(Exposição, Família, `Bruto — IRR (IC95%); p`, `Ajustado — IRR (IC95%); p`)
tab10 <- slim("SINASC (casos mensais Q20-Q28)")
tab11 <- slim("SIH-RD (internações mensais Q20-Q28)")

# Tabela 12 — DLNM: RR cumulativo da temperatura (por desfecho)
tab12 <- dlnm_tab %>%
  dplyr::mutate(Desfecho = ifelse(grepl("^SINASC", desfecho), "SINASC", "SIH-RD"),
                valor = sprintf("%s (%s–%s)", br_num(rr, 2), br_num(ic95_inf, 2),
                                br_num(ic95_sup, 2))) %>%
  dplyr::select(temperatura_c, Desfecho, valor) %>%
  tidyr::pivot_wider(names_from = Desfecho, values_from = valor) %>%
  dplyr::rename(`Temperatura (°C)` = temperatura_c) %>%
  dplyr::mutate(`Temperatura (°C)` = as.character(`Temperatura (°C)`))

# Tabelas 13 e 14 — sensibilidade (média × extremos), bruto e ajustado
mapa_sens <- data.frame(
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
sens_val <- function(espec, dd, mo, te) {
  r <- sens_num[sens_num$especificacao == espec & sens_num$desfecho == dd &
                  sens_num$modelo == mo & sens_num$termo == te, ]
  sprintf("%s (%s–%s); %s", br_num(r$irr, 3), br_num(r$ic_inf, 3),
          br_num(r$ic_sup, 3), fmt_p(r$p_valor))
}
tab_sens <- dplyr::bind_rows(lapply(seq_len(nrow(mapa_sens)), function(i) {
  data.frame(Variável = mapa_sens$variavel[i], Versão = mapa_sens$versao[i],
             `SINASC — Bruto` = sens_val("Bruto", "SINASC (casos mensais Q20-Q28)", mapa_sens$modelo[i], mapa_sens$termo[i]),
             `SIH-RD — Bruto` = sens_val("Bruto", "SIH-RD (internações mensais Q20-Q28)", mapa_sens$modelo[i], mapa_sens$termo[i]),
             `SINASC — Ajustado` = sens_val("Ajustado", "SINASC (casos mensais Q20-Q28)", mapa_sens$modelo[i], mapa_sens$termo[i]),
             `SIH-RD — Ajustado` = sens_val("Ajustado", "SIH-RD (internações mensais Q20-Q28)", mapa_sens$modelo[i], mapa_sens$termo[i]),
             check.names = FALSE)
}))
tab13 <- tab_sens %>%
  dplyr::select(Variável, Versão, `SINASC — Bruto`, `SIH-RD — Bruto`) %>%
  dplyr::rename(`SINASC — IRR (IC95%); p` = `SINASC — Bruto`,
                `SIH-RD — IRR (IC95%); p` = `SIH-RD — Bruto`)
tab14 <- tab_sens %>%
  dplyr::select(Variável, Versão, `SINASC — Ajustado`, `SIH-RD — Ajustado`) %>%
  dplyr::rename(`SINASC — IRR (IC95%); p` = `SINASC — Ajustado`,
                `SIH-RD — IRR (IC95%); p` = `SIH-RD — Ajustado`)

# Salva as tabelas
readr::write_csv(tab1, file.path(CONFIG$dirs$descritiva, "docx_tabela1_anual.csv"), na = "")
readr::write_csv(tab2, file.path(CONFIG$dirs$spearman, "docx_tabela2_spearman.csv"), na = "")
readr::write_csv(tab3, file.path(CONFIG$dirs$poisson, "docx_tabela3_poisson.csv"), na = "")
readr::write_csv(tab4, file.path(CONFIG$dirs$descritiva, "docx_tabela4_vigiar.csv"), na = "")
readr::write_csv(tab5, file.path(CONFIG$dirs$descritiva, "docx_tabela5_taxas_anuais.csv"), na = "")
readr::write_csv(tab6, file.path(CONFIG$dirs$descritiva, "docx_tabela6_tendencia.csv"), na = "")
readr::write_csv(tab7, file.path(CONFIG$dirs$descritiva, "docx_tabela7_sazonalidade.csv"), na = "")
readr::write_csv(tab8, file.path(CONFIG$dirs$descritiva, "docx_tabela8_testes_sazonalidade.csv"), na = "")
readr::write_csv(tab9, file.path(CONFIG$dirs$spearman, "docx_tabela9_spearman_taxas.csv"), na = "")
readr::write_csv(tab10, file.path(CONFIG$dirs$poisson_ajustado, "docx_tabela10_sinasc.csv"), na = "")
readr::write_csv(tab11, file.path(CONFIG$dirs$poisson_ajustado, "docx_tabela11_sih.csv"), na = "")
readr::write_csv(tab12, file.path(CONFIG$dirs$dlnm, "docx_tabela12_dlnm.csv"), na = "")
readr::write_csv(tab13, file.path(CONFIG$dirs$sensibilidade, "docx_tabela13_sens_bruto.csv"), na = "")
readr::write_csv(tab14, file.path(CONFIG$dirs$sensibilidade, "docx_tabela14_sens_ajustado.csv"), na = "")

# -----------------------------------------------------------------------------
# 4. flextables
# -----------------------------------------------------------------------------
ft_style <- function(df) {
  flextable::flextable(df) %>%
    flextable::theme_booktabs() %>%
    flextable::fontsize(size = 8, part = "all") %>%
    flextable::font(fontname = "Calibri", part = "all") %>%
    flextable::bold(part = "header") %>%
    flextable::align(align = "center", part = "all") %>%
    flextable::align(j = 1, align = "left", part = "all") %>%
    flextable::autofit()
}
ft1 <- ft_style(tab1); ft2 <- ft_style(tab2)
ft3 <- ft_style(tab3); ft4 <- ft_style(tab4)
ft5 <- ft_style(tab5); ft6 <- ft_style(tab6)
ft7 <- ft_style(tab7); ft8 <- ft_style(tab8)
ft9 <- ft_style(tab9)
ft10 <- ft_style(tab10); ft11 <- ft_style(tab11); ft12 <- ft_style(tab12)
ft13 <- ft_style(tab13); ft14 <- ft_style(tab14)

# -----------------------------------------------------------------------------
# 5. Atualização do PRÉ-PROJETO.docx
# -----------------------------------------------------------------------------
# Backup de segurança (preserva o documento original). O script sempre parte do
# backup, garantindo reprodutibilidade e evitando duplicar a seção de resultados
# em reexecuções. Nome sem acentos para evitar problemas de codificação de
# caminho no Windows.
BACKUP <- "PRE-PROJETO_original.docx"
if (!file.exists(BACKUP)) file.copy(DOCX, BACKUP, overwrite = FALSE)
doc <- officer::read_docx(BACKUP)

# Proteção: evita duplicar as seções de resultados caso o backup não esteja
# pristino (sem seções de RESULTADOS).
txt_bkp <- tryCatch(paste(officer::docx_summary(doc)$text, collapse = " "),
                    error = function(e) "")
if (grepl("RESULTADOS", txt_bkp)) {
  stop("O backup '", BACKUP, "' já contém seções de RESULTADOS. ",
       "Restaure o Pré-projeto original nesse arquivo antes de reexecutar.")
}

# O documento usa o estilo de nome "normal"; o flextable referencia "Normal".
# Adiciona um alias para que a validação do officer aceite as tabelas.
idx_normal <- which(tolower(doc$styles$style_name) == "normal")[1]
if (!is.na(idx_normal)) {
  alias <- doc$styles[idx_normal, , drop = FALSE]
  alias$style_id <- "Normal"; alias$style_name <- "Normal"
  alias$is_custom <- TRUE; alias$is_default <- FALSE
  doc$styles <- rbind(doc$styles, alias)
}

# 5.1 Atualização da metodologia (2.2): novos indicadores do VIGIAR
txt_22 <- paste0(
  "De forma complementar, os indicadores ambientais e de saúde do VIGIAR ",
  "(Vigilância em Saúde Ambiental, Ministério da Saúde) foram obtidos por meio ",
  "do pacote vigiar (Santos, 2025): concentração de material particulado fino ",
  "(MP2,5) mensal e anual; número de dias com concentração acima dos limites da ",
  "OMS e do CONAMA; população exposta por faixa de concentração; exposição ",
  "domiciliar a combustíveis sólidos; e indicadores de saúde atribuíveis à ",
  "poluição do ar (número e proporção de óbitos atribuíveis ao MP2,5) para ",
  "doenças do aparelho circulatório e respiratório, câncer de pulmão, doença ",
  "pulmonar obstrutiva crônica, infecções das vias aéreas inferiores e ",
  "mortalidade geral."
)
doc <- officer::cursor_reach(doc, "concentrações mensais de material particulado fino")
doc <- officer::body_add_par(doc, txt_22, style = "normal", pos = "after")

# 5.2 Atualização da metodologia (2.3): modelos utilizados
txt_23 <- paste0(
  "Além da regressão de Poisson, foram ajustados modelos de Quasi-Poisson e ",
  "Binomial Negativa para lidar com eventual superdispersão, um modelo de ",
  "defasagem distribuída não linear (DLNM) para a temperatura e modelos de ",
  "Poisson com defasagens (lags) de um a três meses das exposições ambientais ",
  "para os nascidos vivos, janela compatível com o período da cardiogênese."
)
doc <- officer::cursor_reach(doc, "razões de taxas de incidência")
doc <- officer::body_add_par(doc, txt_23, style = "normal", pos = "after")

# 5.3 Seção de RESULTADOS (antes de REFERÊNCIAS)
doc <- officer::cursor_reach(doc, "REFERÊNCIAS")
doc <- officer::body_add_par(doc, "3 RESULTADOS", style = "heading 1", pos = "before")

add_caption <- function(doc, txt) {
  officer::body_add_par(doc, txt, style = "Caption")
}

# Figura 1
doc <- add_caption(doc, paste0(
  "Figura 1 — Séries temporais mensais dos nascidos vivos com Q20-Q28 (SINASC), ",
  "das internações de menores de um ano com Q20-Q28 (SIH-RD), da concentração ",
  "de MP2,5 e da temperatura média. Campos dos Goytacazes (RJ), 2020–2024. ",
  "Fonte: DATASUS (SINASC/SIH-RD); VIGIAR/MS (MP2,5); INMET A607 (temperatura)."))
doc <- officer::body_add_img(doc, src = fig1_path, width = 6, height = 4.5)

# Tabela 1
doc <- add_caption(doc, paste0(
  "Tabela 1 — Nascidos vivos e internações com malformações congênitas do ",
  "aparelho circulatório (CID-10 Q20-Q28), concentração anual de MP2,5 e dias ",
  "acima do limite da OMS. Campos dos Goytacazes (RJ), 2020–2024. ",
  sprintf("Tendência (Mann-Kendall): SINASC tau = %.2f (p = %.3f); SIH-RD tau = %.2f (p = %.3f).",
          mk_sin, p_sin, mk_sih, p_sih)))
doc <- flextable::body_add_flextable(doc, ft1)

# Tabela 2
doc <- add_caption(doc, paste0(
  "Tabela 2 — Correlação de Spearman (rho; p-valor) entre as exposições ",
  "ambientais mensais e os desfechos. Campos dos Goytacazes (RJ), 2020–2024 ",
  "(n = 60 meses)."))
doc <- flextable::body_add_flextable(doc, ft2)

# Tabela 3
doc <- add_caption(doc, paste0(
  "Tabela 3 — Razões de taxas de incidência (IRR), intervalos de confiança de ",
  "95% e p-valores da regressão de Poisson com offset, por desfecho. ",
  "Campos dos Goytacazes (RJ), 2020–2024. Dispersão de Pearson: SINASC 1,19; ",
  "SIH-RD 1,07; Quasi-Poisson e Binomial Negativa produziram estimativas ",
  "consistentes."))
doc <- flextable::body_add_flextable(doc, ft3)

# Tabela 4
doc <- add_caption(doc, paste0(
  "Tabela 4 — Número estimado de óbitos atribuíveis à poluição por MP2,5, por ",
  "grupo de causas e triênio. Campos dos Goytacazes (RJ). ",
  "Fonte: VIGIAR/MS. Estimativas por satélite/modelagem."))
doc <- flextable::body_add_flextable(doc, ft4)

# -----------------------------------------------------------------------------
# 5.4 Seção 4 — 1ª etapa: taxas, tendência e sazonalidade (ADICIONADA, sem
#     alterar a seção "3 RESULTADOS" já existente)
# -----------------------------------------------------------------------------
doc <- officer::body_add_par(
  doc, "4 RESULTADOS — TAXAS, TENDÊNCIA E SAZONALIDADE DAS SÉRIES TEMPORAIS",
  style = "heading 1")

doc <- officer::body_add_par(doc, paste0(
  "Como foi feito (em linguagem simples): para cada mês, calculamos a taxa de casos ",
  "por 10.000 nascidos vivos — ou seja, quantos casos ocorreram para cada 10.000 bebês ",
  "nascidos naquele mês. Em torno de cada taxa, calculamos um intervalo de confiança de ",
  "95% (Garwood, 1936): uma faixa que indica a precisão da estimativa (quanto mais ",
  "estreita, mais precisa; quando não há casos, o limite inferior é zero). Para verificar ",
  "se as taxas aumentaram ou diminuíram ao longo do tempo, aplicamos o teste de ",
  "Mann-Kendall (Mann, 1945) e a inclinação de Sen (Sen, 1968), que indicam, ",
  "respectivamente, se existe tendência e o quanto por ano. Para avaliar o padrão por ",
  "mês do ano (sazonalidade), comparamos as taxas dos 12 meses do calendário ",
  "(qui-quadrado, Kruskal-Wallis e regressão de Poisson com efeito de mês) e ",
  "decompusemos a série em três partes pelo método STL (Cleveland et al., 1990): ",
  "tendência (direção de longo prazo), sazonalidade (o que se repete a cada ano) e ",
  "resíduo (variação aleatória)."),
  style = "normal")

# Figura 2 — taxas mensais por 10.000 nascidos vivos
doc <- add_caption(doc, paste0(
  "Figura 2 — Taxas mensais por 10.000 nascidos vivos (IC 95%) dos nascidos ",
  "vivos com Q20-Q28 (SINASC) e das internações de menores de um ano com ",
  "Q20-Q28 (SIH-RD). Campos dos Goytacazes (RJ), 2020–2024."))
doc <- officer::body_add_img(doc, src = fig2_path, width = 6, height = 4.7)

# Tabela 5 — taxas anuais
doc <- add_caption(doc, paste0(
  "Tabela 5 — Taxas anuais por 10.000 nascidos vivos e intervalos de confiança ",
  "de 95% (exato de Poisson). Campos dos Goytacazes (RJ), 2020–2024."))
doc <- flextable::body_add_flextable(doc, ft5)

# Tabela 6 — testes de tendência
doc <- add_caption(doc, paste0(
  "Tabela 6 — Testes de tendência: Mann-Kendall anual e Mann-Kendall sazonal de ",
  "Hirsch-Slack sobre as séries mensais. Campos dos Goytacazes (RJ), 2020–2024."))
doc <- flextable::body_add_flextable(doc, ft6)

# Tabela 7 — taxa por mês-calendário
doc <- add_caption(doc, paste0(
  "Tabela 7 — Taxa por mês-calendário (agregando os cinco anos) por 10.000 ",
  "nascidos vivos, com IC 95%. Campos dos Goytacazes (RJ), 2020–2024."))
doc <- flextable::body_add_flextable(doc, ft7)

# Figura 3 — sazonalidade
doc <- add_caption(doc, paste0(
  "Figura 3 — Sazonalidade: taxa por mês-calendário por 10.000 nascidos vivos ",
  "(IC 95%). Pontos cinza = taxas de cada ano; pontos coloridos = taxa agrupada."))
doc <- officer::body_add_img(doc, src = fig3_path, width = 6, height = 4.7)

# Tabela 8 — testes de sazonalidade
doc <- add_caption(doc, paste0(
  "Tabela 8 — Testes de sazonalidade: qui-quadrado de uniformidade, ",
  "Kruskal-Wallis e razão de verossimilhança (Poisson com efeito de mês). ",
  "Campos dos Goytacazes (RJ), 2020–2024."))
doc <- flextable::body_add_flextable(doc, ft8)

# Figura 4 — decomposição STL
doc <- add_caption(doc, paste0(
  "Figura 4 — Decomposição STL das taxas mensais por 10.000 nascidos vivos ",
  "(tendência, sazonalidade e resíduo). Campos dos Goytacazes (RJ), 2020–2024."))
doc <- officer::body_add_img(doc, src = fig4_path, width = 6.3, height = 3.8)

# --- 2ª etapa metodológica: correlação de Spearman sobre as TAXAS mensais ---
doc <- officer::body_add_par(
  doc, "Correlação de Spearman — taxas mensais por 10.000 nascidos vivos",
  style = "heading 2")

doc <- officer::body_add_par(doc, paste0(
  "Como foi feito (em linguagem simples): medimos, mês a mês, o quanto cada exposição ",
  "ambiental 'anda junto' com as taxas de casos usando a correlação de Spearman ",
  "(Mukaka, 2012). O coeficiente (rho) varia de −1 a +1: positivo indica que, quando a ",
  "exposição sobe, a taxa tende a subir; negativo, o contrário; zero, ausência de ",
  "relação. Em vez dos valores brutos, a correlação usa a ordem (postos) dos meses, o ",
  "que a torna robusta a valores extremos e a relações não lineares. O p-valor informa ",
  "a chance de observar um resultado assim se não houvesse associação; adotamos o nível ",
  "de significância de 5% (p < 0,05)."), style = "normal")

# Tabela 9 — Spearman (taxas × exposições)
doc <- add_caption(doc, paste0(
  "Tabela 9 — Correlação de Spearman (rho; p-valor) entre as taxas mensais por ",
  "10.000 nascidos vivos e as exposições ambientais, ao nível de significância ",
  "de 5%. Campos dos Goytacazes (RJ), 2020–2024 (n = 60 meses)."))
doc <- flextable::body_add_flextable(doc, ft9)

# Figura 5 — heatmap da correlação das taxas
doc <- add_caption(doc, paste0(
  "Figura 5 — Matriz de correlação de Spearman entre as taxas mensais por ",
  "10.000 nascidos vivos e as exposições ambientais (* p < 0,05). "
))
doc <- officer::body_add_img(doc, src = fig5_path, width = 6, height = 5.2)

# --- 3ª etapa metodológica: Poisson bruto × ajustado (comparativo, 3 famílias) ---
doc <- officer::body_add_par(
  doc, "Regressão de Poisson — bruto × ajustado (sazonalidade + tendência)",
  style = "heading 2")

doc <- officer::body_add_par(doc, paste0(
  "Como foi feito (em linguagem simples): usamos a regressão de Poisson (Frome; ",
  "Checkoway, 1985), adequada para contagens, para estimar razões de taxas de incidência ",
  "(IRR). A IRR mostra quantas vezes a taxa muda a cada aumento de uma unidade da ",
  "exposição (ex.: IRR = 1,05 significa +5% por 1 °C a mais); valores acima de 1 indicam ",
  "aumento, abaixo de 1 indicam redução, e o intervalo de confiança de 95% mostra a ",
  "precisão. Como o número de casos depende de quantas crianças nasceram no mês, ",
  "incluímos esse total como um 'offset' (ajuste que converte a contagem em taxa por ",
  "nascidos vivos). Verificamos se havia superdispersão e, quando presente, usamos ",
  "Quasi-Poisson ou Binomial Negativa (Gardner; Mulvey; Shaw, 1995). Para controlar o ",
  "padrão do calendário e a deriva dos cinco anos, ajustamos os modelos por sazonalidade ",
  "(seno e cosseno do mês) e por tendência temporal."), style = "normal")

doc <- add_caption(doc, paste0(
  "Tabela 10 — Nascidos vivos (SINASC): razões de taxas de incidência (IRR), ",
  "IC 95% e p-valor dos modelos bruto e ajustado, nas famílias Poisson, ",
  "Quasi-Poisson e Binomial Negativa (offset = log nascidos vivos). ",
  "Campos dos Goytacazes (RJ), 2020–2024."))
doc <- flextable::body_add_flextable(doc, ft10)

doc <- add_caption(doc, paste0(
  "Tabela 11 — Internações de menores de um ano (SIH-RD): IRR, IC 95% e p-valor ",
  "dos modelos bruto e ajustado, nas três famílias (offset = log nascidos vivos). ",
  "Campos dos Goytacazes (RJ), 2020–2024. Nota: as associações com precipitação e ",
  "umidade deixam de ser significativas após o ajuste por sazonalidade e tendência."))
doc <- flextable::body_add_flextable(doc, ft11)

doc <- add_caption(doc, paste0(
  "Figura 6 — IRR (IC 95%) bruto × ajustado por sazonalidade e tendência ",
  "(modelo de Poisson com offset), por desfecho e exposição."))
doc <- officer::body_add_img(doc, src = fig6_path, width = 6.2, height = 4.4)

# --- 3ª etapa metodológica (continuação): DLNM ---
doc <- officer::body_add_par(
  doc, "Modelo de defasagem distribuída não linear (DLNM) — temperatura",
  style = "heading 2")

doc <- officer::body_add_par(doc, paste0(
  "Como foi feito (em linguagem simples): o modelo de defasagem distribuída não linear ",
  "(DLNM; Gasparrini; Armstrong; Kenward, 2010) captura dois fenômenos ao mesmo tempo: ",
  "(i) o efeito da temperatura pode não ser linear — valores muito altos ou muito baixos ",
  "podem pesar de forma diferente — e (ii) o efeito pode aparecer com atraso, nos meses ",
  "seguintes. Para isso, a temperatura é representada por uma curva flexível e por vários ",
  "meses de defasagem; o resultado é um risco relativo (RR) cumulativo, comparado à ",
  "temperatura mediana (24,0 °C). As demais exposições (precipitação, umidade e MP2,5) ",
  "entram como ajuste."), style = "normal")

doc <- add_caption(doc, paste0(
  "Tabela 12 — Risco relativo (RR) cumulativo da temperatura sobre os desfechos, ",
  "com IC 95%, obtido por DLNM (base não linear em spline e defasagem distribuída) ",
  "ajustado por precipitação, umidade e MP2,5, com offset = log nascidos vivos. ",
  "Referência = temperatura mediana (24,0 °C). Lag 1–3 meses (SINASC) e 0–3 meses ",
  "(SIH-RD). Campos dos Goytacazes (RJ), 2020–2024."))
doc <- flextable::body_add_flextable(doc, ft12)

doc <- add_caption(doc, paste0(
  "Figura 7 — DLNM: efeito cumulativo da temperatura sobre os nascidos vivos ",
  "(Q20-Q28) e as internações de menores de um ano (Q20-Q28), com IC 95%."))
doc <- officer::body_add_img(doc, src = fig7_path, width = 6.2, height = 3.6)

# --- Análise de sensibilidade: exposições em extremos ---
doc <- officer::body_add_par(
  doc, "Análise de sensibilidade — exposições em extremos", style = "heading 2")

doc <- officer::body_add_par(doc, paste0(
  "Como foi feito (em linguagem simples): a análise de sensibilidade (Greenland, 2001) ",
  "testa se a conclusão depende da forma como medimos a exposição. Em vez da média do ",
  "mês, usamos o valor extremo (máxima e mínima absoluta do mês) e, para o MP2,5, os ",
  "dias acima dos limites da OMS/CONAMA (a métrica de 'pico' disponível). Cada modelo ",
  "troca uma única exposição por vez, mantendo as demais na forma de média, para evitar ",
  "que variáveis muito parecidas 'briguem' entre si. Se o resultado se mantém sob ",
  "métricas diferentes, ganha robustez; se muda, indica que a conclusão depende da ",
  "escolha da exposição."), style = "normal")

doc <- add_caption(doc, paste0(
  "Tabela 13 — Análise de sensibilidade (modelos brutos): IRR, IC 95% e p-valor ",
  "para as versões média e extremos das exposições. Offset = log nascidos vivos. ",
  "Campos dos Goytacazes (RJ), 2020–2024."))
doc <- flextable::body_add_flextable(doc, ft13)

doc <- add_caption(doc, paste0(
  "Tabela 14 — Análise de sensibilidade (modelos ajustados por sazonalidade e ",
  "tendência): IRR, IC 95% e p-valor para as versões média e extremos. ",
  "Campos dos Goytacazes (RJ), 2020–2024. Nota: no SIH-RD, a umidade mínima ",
  "absoluta permanece significativa (p = 0,016), enquanto a umidade média perde ",
  "significância (p = 0,088) após o ajuste."))
doc <- flextable::body_add_flextable(doc, ft14)

doc <- add_caption(doc, paste0(
  "Figura 8 — Análise de sensibilidade: IRR (IC 95%) da média × versões em ",
  "extremos (modelo ajustado por sazonalidade e tendência), por desfecho."))
doc <- officer::body_add_img(doc, src = fig8_path, width = 6.3, height = 4.6)

# -----------------------------------------------------------------------------
# Referências adicionais citadas nas descrições dos métodos (inseridas em ordem
# alfabética na lista de REFERÊNCIAS, sem alterar as demais)
# -----------------------------------------------------------------------------
add_ref <- function(doc, texto, antes_de) {
  doc <- officer::cursor_reach(doc, antes_de)
  officer::body_add_par(doc, texto, style = "normal", pos = "before")
}
doc <- add_ref(doc, paste0("CLEVELAND, R. B.; CLEVELAND, W. S.; McRAE, J. E.; TERPENNING, I. ",
  "STL: a seasonal-trend decomposition procedure based on loess. Journal of Official ",
  "Statistics, v. 6, n. 1, p. 3-73, 1990."), "CRESWELL, J. W.")
doc <- add_ref(doc, paste0("FROME, E. L.; CHECKOWAY, H. Use of Poisson regression models in ",
  "estimating incidence rates and ratios. American Journal of Epidemiology, v. 121, n. 2, ",
  "p. 309-323, 1985."), "KATZNELSON, E.")
doc <- add_ref(doc, paste0("GARDNER, W.; MULVEY, E. P.; SHAW, E. C. Regression analyses of counts ",
  "and rates: Poisson, overdispersed Poisson, and negative binomial models. Psychological ",
  "Bulletin, v. 118, n. 3, p. 392-404, 1995."), "KATZNELSON, E.")
doc <- add_ref(doc, paste0("GARWOOD, F. Fiducial limits for the Poisson distribution. ",
  "Biometrika, v. 28, n. 3-4, p. 437-442, 1936."), "KATZNELSON, E.")
doc <- add_ref(doc, paste0("GASPARRINI, A.; ARMSTRONG, B.; KENWARD, M. G. Distributed lag ",
  "non-linear models. Statistics in Medicine, v. 29, n. 21, p. 2224-2234, 2010."), "KATZNELSON, E.")
doc <- add_ref(doc, paste0("GREENLAND, S. Sensitivity analysis, Monte Carlo risk analysis, and ",
  "Bayesian uncertainty assessment. Risk Analysis, v. 21, n. 4, p. 579-583, 2001."), "KATZNELSON, E.")
doc <- add_ref(doc, paste0("MANN, H. B. Nonparametric tests against trend. Econometrica, v. 13, ",
  "n. 3, p. 245-259, 1945."), "MORGENSTERN, H.")
doc <- add_ref(doc, paste0("SEN, P. K. Estimates of the regression coefficient based on Kendall's ",
  "tau. Journal of the American Statistical Association, v. 63, n. 324, p. 1379-1389, 1968."),
  "SILVA, L. F. M.")

# Salva o documento atualizado
print(doc, target = DOCX)

cat("\n===== PRÉ-PROJETO.docx atualizado =====\n")
cat("Figura:", fig1_path, "\n")
cat("Tabelas CSV salvas nas pastas de cada modelo em results/\n")
