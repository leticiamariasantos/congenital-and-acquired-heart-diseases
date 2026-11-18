# Tabela-síntese e discussão — associação umidade × internações

## Tabela de resultados (desfecho principal Q20–Q26)

| Desfecho | Exposição | Modelo | IRR (por IQR) | IC 95% | p | Classificação |
|---|---|---|---|---|---|---|
| Nascidos vivos (SINASC) | Temperatura (°C) | Isolado | 2,98 | 0,49–18,10 | 0,235 | Não significativo |
| Nascidos vivos (SINASC) | Umidade relativa (%) | Isolado | 0,64 | 0,39–1,04 | 0,073 | Não significativo |
| Nascidos vivos (SINASC) | MP2,5 (µg/m³) | Isolado | 1,19 | 0,63–2,22 | 0,594 | Não significativo |
| Nascidos vivos (SINASC) | Temperatura (°C) | Conjunto | 1,41 | 0,14–13,92 | 0,770 | Não significativo |
| Nascidos vivos (SINASC) | Umidade relativa (%) | Conjunto | 0,67 | 0,37–1,21 | 0,180 | Não significativo |
| Nascidos vivos (SINASC) | MP2,5 (µg/m³) | Conjunto | 1,18 | 0,64–2,17 | 0,600 | Não significativo |
| Internações (SIH-RD) | Temperatura (°C) | Isolado | 1,00 | 0,31–3,26 | 0,997 | Não significativo |
| Internações (SIH-RD) | **Umidade relativa (%)** | Isolado | **0,68** | **0,51–0,90** | **0,006** | **Significativo** |
| Internações (SIH-RD) | MP2,5 (µg/m³) | Isolado | 0,85 | 0,59–1,22 | 0,389 | Não significativo |
| Internações (SIH-RD) | Temperatura (°C) | Conjunto | 0,31 | 0,08–1,29 | 0,108 | Não significativo |
| Internações (SIH-RD) | **Umidade relativa (%)** | Conjunto | **0,58** | **0,41–0,83** | **0,002** | **Significativo** |
| Internações (SIH-RD) | MP2,5 (µg/m³) | Conjunto | 0,76 | 0,53–1,08 | 0,125 | Não significativo |

*Nota:* IQR da umidade ≈ 3,35 pontos percentuais. A associação umidade × internações manteve-se significativa no conjunto de sensibilidade Q20–Q28 (IRR = 0,63 no modelo conjunto; IC 95% 0,46–0,86; p = 0,004). A tabela completa (24 combinações) está em `results/tables/tabela_irr_sintese.csv`.

---

## Discussão: o significado da associação negativa entre umidade e internações

A associação negativa encontrada indica que, ao longo dos 180 meses analisados, **meses com menor umidade relativa associaram-se a maior taxa de internações** de menores de um ano por **cardiopatias congênitas (Q20–Q26, com sensibilidade Q20–Q28)**. A umidade foi tratada como **variável contínua** — sem ponto de corte arbitrário que separasse meses "secos" de "úmidos" —, de modo que o IRR expressa um **gradiente**: cada incremento de ≈ 3,3 pontos percentuais na umidade média correspondeu a uma redução de 32% a 42% na taxa de internações (IRR = 0,68 no modelo isolado e 0,58 no conjunto).

O mecanismo é biologicamente coerente com a literatura recente sobre umidade e infecções respiratórias. A baixa umidade relativa resseca a mucosa das vias aéreas, prejudica o *clearance* mucociliar e modula a resposta imune local, ao mesmo tempo em que favorece a estabilidade e a transmissão de vírus respiratórios (Guarnieri et al., 2023). Em nível populacional, a umidade relativa ambiente tem sido associada à ocorrência de infecções pelo vírus sincicial respiratório (Lu et al., 2025). Lactentes com **cardiopatia congênita** constituem grupo de alto risco para formas graves dessas infecções, que frequentemente precipitam descompensação clínica e hospitalização (Kilinc et al., 2020).

É importante notar que as internações foram selecionadas por diagnóstico **principal ou secundário** em Q20–Q26/Q20–Q28 — ou seja, incluem hospitalizações de crianças cardiopatas cujo motivo imediato pode ser, por exemplo, um quadro respiratório. Isso torna a cadeia "ar seco → infecção respiratória → descompensação no lactente cardiopata → internação" ainda mais plausível, e explica por que o efeito se manifesta nas **internações** (desfecho clínico pós-natal) e **não** nos nascidos vivos com malformação (desfecho congênito, definido na vida intrauterina).

Deve-se, contudo, interpretar o resultado com cautela. Trata-se de estudo ecológico, e a umidade correlaciona-se com o calendário sazonal e com comportamentos associados (maior permanência em ambientes fechados, menor ventilação), podendo atuar como **marcador de fatores de inverno** e não como causa direta. Embora o modelo conjunto tenha ajustado por temperatura e MP2,5 — mantendo o efeito da umidade —, o confundimento residual não pode ser excluído, e a baixa frequência de desfechos limita a precisão. Ainda assim, a direção e a consistência do achado (presente nos modelos isolado e conjunto e nas duas definições de caso) alinham-se à literatura sobre transmissão de vírus respiratórios em ambientes secos.

**Referências**

1. Guarnieri G, Olivieri B, Senna G, Vianello A. Relative humidity and its impact on the immune system and infections. *Int J Mol Sci*. 2023;24(11):9456. DOI:10.3390/ijms24119456.
2. Lu Y, Ren S, Shao X, et al. Association of ambient temperature and relative humidity with respiratory syncytial virus infections among hospitalized children. *GeoHealth*. 2025;9. DOI:10.1029/2025gh001353.
3. Kilinc A, Aygun C, Sungur M, Baysal K. Respiratory syncytial virus and effect of palivizumab prophylaxis in patients with congenital heart disease. *Annals of Medical Research*. 2020;27. DOI:10.5455/annalsmedres.2020.03.260.
