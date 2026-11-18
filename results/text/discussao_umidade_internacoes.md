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

A associação negativa encontrada indica que **meses mais secos estão associados a maior taxa de internações** de menores de um ano por cardiopatias: cada incremento de um intervalo interquartil (≈ 3,3 pontos percentuais) na umidade relativa média correspondeu a uma redução de 32% a 42% na taxa de internações. Esse achado é biologicamente coerente com a literatura sobre clima e infecções respiratórias, principal via plausível de explicação.

O ar seco (baixa umidade) favorece a **sobrevivência e a transmissão de vírus respiratórios**. Estudos clássicos demonstraram, em modelos animais e em condições controladas, que a transmissão do vírus influenza é fortemente dependente da umidade relativa, sendo máxima em ambientes secos (Lowen et al., 2007), e que a **umidade absoluta modula a sobrevivência, a transmissão e a sazonalidade da influenza** (Shaman & Kohn, 2009). Em populações humanas, **baixas temperaturas combinadas a baixa umidade** foram associadas ao aumento de infecções do trato respiratório (Mäkinen et al., 2009). Além disso, o ar seco resseca as mucosas das vias aéreas e prejudica o clearance mucociliar, reduzindo a primeira barreira de defesa contra patógenos respiratórios.

Nesse contexto, lactentes com **cardiopatia congênita** constituem um grupo particularmente vulnerável: infecções respiratórias virais, como a bronquiolite pelo vírus sincicial respiratório, são reconhecidamente mais graves nesses pacientes e frequentemente precipitam descompensação clínica e hospitalização. Assim, a associação com a umidade faz sentido **não sobre a ocorrência do defeito cardíaco em si, mas sobre o seu desfecho clínico pós-natal** — o que é reforçado pelo fato de o efeito ter sido observado nas internações e **não** nos nascidos vivos com malformação (SINASC). Essa coerência interna (efeito restrito ao desfecho adquirido/decompensação, ausente no desfecho congênito) aumenta a plausibilidade do achado.

Deve-se, contudo, interpretar o resultado com cautela. Trata-se de estudo ecológico, e a umidade correlaciona-se com o calendário sazonal e com comportamentos associados (maior permanência em ambientes fechados, menor ventilação), podendo atuar como **marcador de um conjunto de fatores de inverno** e não apenas como fator causal direto. Embora o modelo conjunto tenha ajustado por temperatura e MP2,5 — mantendo o efeito da umidade —, o confundimento residual não pode ser totalmente excluído, e a baixa frequência de desfechos limita a precisão. Ainda assim, a direção e a consistência do achado (presente nos modelos isolado e conjunto e nas duas definições de caso) alinham-se à literatura sobre transmissão de vírus respiratórios em ambientes secos, sustentando a hipótese de que meses secos contribuam para maior morbidade hospitalar em lactentes cardiopatas.

**Referências**

1. Lowen AC, Mubareka S, Steel J, Palese P. Influenza virus transmission is dependent on relative humidity and temperature. *PLoS Pathog*. 2007;3(10):e151.
2. Shaman J, Kohn M. Absolute humidity modulates influenza survival, transmission, and seasonality. *Proc Natl Acad Sci U S A*. 2009;106(9):3243–3248.
3. Mäkinen TM, Juvonen R, Jokelainen J, et al. Cold temperature and low humidity are associated with increased occurrence of respiratory tract infections. *Respir Med*. 2009;103(3):456–462.
