# Resultados e discussão — terceira etapa (modelos Quasi-Poisson)

## Resultados

Os modelos de Quasi-Poisson, ajustados por dois pares de harmônicos de Fourier, spline natural do tempo (df = 7) e indicador pandêmico (fev/2020–abr/2022), com *offset* adequado a cada desfecho e exposições defasadas (6–9 meses para o SINASC; 0–3 meses para o SIH), revelaram **associação significativa entre a umidade relativa e as internações** de menores de um ano, no conjunto principal Q20–Q26 (Tabela). Para cada incremento de um intervalo interquartil (IQR ≈ 3,3 pontos percentuais) na umidade relativa média, a taxa de internações reduziu-se em **32% no modelo isolado** (IRR = 0,68; IC 95%: 0,51–0,90; p = 0,006) e em **42% no modelo conjunto** (IRR = 0,58; IC 95%: 0,41–0,83; p = 0,002). O achado manteve-se na análise de sensibilidade Q20–Q28 (IRR = 0,63; IC 95%: 0,46–0,86; p = 0,004, no modelo conjunto).

| Desfecho | Exposição | Modelo | IQR | IRR | IC 95% | p |
|---|---|---|---|---|---|---|
| Internações (SIH) | Umidade relativa (%) | Isolado | 3,35 | 0,68 | 0,51–0,90 | 0,006 |
| Internações (SIH) | Umidade relativa (%) | Conjunto | 3,35 | 0,58 | 0,41–0,83 | 0,002 |
| Internações (SIH) | Temperatura (°C) | Conjunto | 3,16 | 0,31 | 0,08–1,29 | 0,108 |
| Internações (SIH) | MP2,5 (µg/m³) | Conjunto | 1,31 | 0,76 | 0,53–1,08 | 0,125 |
| Nascidos vivos (SINASC) | Umidade relativa (%) | Isolado | 3,34 | 0,64 | 0,39–1,04 | 0,073 |
| Nascidos vivos (SINASC) | Temperatura (°C) | Isolado | 3,25 | 2,98 | 0,49–18,10 | 0,235 |

As demais associações não foram estatisticamente significativas. Não se observou colinearidade relevante entre as exposições (VIF < 2 em todos os modelos conjuntos), e a autocorrelação residual foi mínima (|ACF lag 1| < 0,10), indicando que o ajuste temporal controlou adequadamente os padrões compartilhados.

## Discussão

A associação **negativa entre umidade relativa e internações** — meses mais secos associados a maior taxa de internações de menores de um ano por cardiopatias — foi o único efeito consistente e significativo desta etapa, presente nos modelos isolado e conjunto e nas duas definições de caso (Q20–Q26 e Q20–Q28). Esse resultado é biologicamente plausível: o ar mais seco é reconhecido por ressecar mucosas e favorecer quadros respiratórios e descompensações clínicas que podem precipitar internações, inclusive em lactentes cardiopatas. Contudo, em um estudo ecológico com contagens baixas, esse achado deve ser interpretado como **sinal exploratório** a ser confirmado, e não como relação causal.

As demais exposições — temperatura e MP2,5 — não apresentaram associação significativa com nenhum desfecho, e nenhuma exposição se associou aos nascidos vivos com malformação. Este último resultado é coerente com a natureza **congênita e estrutural** das cardiopatias: a ocorrência registrada no SINASC reflete, sobretudo, a cardiogênese intrauterina, pouco sensível às flutuações mensais das exposições na escala ecológica aqui analisada.

## Diferença entre esta etapa e a etapa exploratória

As duas etapas investigam a mesma pergunta — "as exposições se associam aos desfechos?" —, mas com métodos e sensibilidade distintos.

| Aspecto | Etapa exploratória (Spearman) | Terceira etapa (Quasi-Poisson) |
|---|---|---|
| Natureza | Descritiva | Regressão formal |
| Medida | ρ (correlação de postos) | IRR (razão de taxas) por IQR |
| Modelagem do desfecho | Resíduos correlacionados | Contagem com *offset* e distribuição Poisson |
| Interpretação | Direção e força (sem magnitude clínica direta) | Efeito multiplicativo interpretável |
| Sensibilidade | Menor (usa postos; ignora a estrutura de contagem) | Maior (usa toda a informação da contagem) |
| Correção | Holm | Erros robustos (HAC) + VIF |

A etapa exploratória **não encontrou correlação significativa**, mas apontou a umidade × internações como o sinal mais forte (ρ = −0,17; não significativo após Holm). A terceira etapa, mais potente e adequada à natureza dos dados, **confirmou e quantificou esse mesmo sinal**, agora estatisticamente significativo: cada IQR de aumento da umidade associou-se a uma redução de 32% a 42% na taxa de internações. Ou seja, o achado que a etapa exploratória apenas **sugeriu**, a regressão **estabeleceu** em termos de efeito e significância — ilustrando o papel complementar das duas abordagens: a primeira gera hipóteses; a segunda as testa.
