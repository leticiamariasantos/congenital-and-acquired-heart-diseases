# Resultados e discussão — etapa exploratória (correlação de Spearman)

## Resultados

Após o pré-branqueamento das séries — remoção da tendência secular, da sazonalidade (dois pares de harmônicos de Fourier) e do período pandêmico —, as correlações de Spearman entre as exposições ambientais e os desfechos foram, em sua totalidade, de **magnitude desprezível** e **sem significância estatística após o ajuste de Holm** (Tabela). No conjunto principal (Q20–Q26), os coeficientes variaram entre ρ = −0,17 e ρ = 0,02, com valores de p ajustados sempre superiores a 0,05.

| Desfecho | Exposição | Defasagem | ρ | p (Holm) | Magnitude |
|---|---|---|---|---|---|
| Nascidos vivos (SINASC) | Temperatura (°C) | 6–9 meses | 0,02 | 1,000 | desprezível |
| Nascidos vivos (SINASC) | Umidade relativa (%) | 6–9 meses | −0,10 | 0,945 | desprezível |
| Nascidos vivos (SINASC) | MP2,5 (µg/m³) | 6–9 meses | −0,04 | 1,000 | desprezível |
| Internações (SIH-RD) | Temperatura (°C) | 0–3 meses | −0,06 | 1,000 | desprezível |
| Internações (SIH-RD) | Umidade relativa (%) | 0–3 meses | −0,17 | 0,139 | desprezível |
| Internações (SIH-RD) | MP2,5 (µg/m³) | 0–3 meses | 0,01 | 1,000 | desprezível |

Os resultados do conjunto de sensibilidade (Q20–Q28) foram equivalentes (ρ entre −0,16 e 0,06; todos com p ajustado > 0,05).

## Discussão

O **pré-branqueamento** constitui o cerne interpretativo desta etapa: ao subtrair de todas as séries os padrões temporais compartilhados (tendência, estações do ano e pandemia), a correlação residual passa a medir, essencialmente, se as **flutuações inesperadas** de uma variável acompanham as de outra. Assim, o achado de coeficientes próximos de zero indica que, fora da variação temporal comum, **as exposições não acrescentam informação sobre os desfechos** — isto é, a marcante sazonalidade da temperatura, da umidade e do MP2,5, e a tendência de aumento dos casos no SINASC, não se traduzem em associação entre as variáveis quando esses padrões são removidos.

A **defasagem de 6 a 9 meses** aplicada aos nascidos vivos situa a exposição na janela periconcepcional e do primeiro trimestre, período da cardiogênese. Os coeficientes obtidos nessa janela (ρ entre −0,10 e 0,02) sugerem que a exposição ambiental média nesse período gestacional **não se correlaciona, nesta escala ecológica, com a ocorrência de malformações cardíacas congênitas registradas no SINASC**. Já a **defasagem de 0 a 3 meses** das internações representa a exposição recente; o único sinal numericamente mais expressivo — e ainda assim fraco e não significativo — foi a associação **negativa** entre internações e umidade relativa (ρ = −0,17; p de Holm = 0,14), consistente entre Q20–Q26 e Q20–Q28, que poderia sugerir leve aumento das internações em meses mais secos, mas que não ultrapassa o limiar de significância e deve ser tratado apenas como hipótese a ser reexaminada em etapa inferencial.

A interpretação dos coeficientes seguiu os limiares de Mukaka (2012), aplicados ao ρ de Spearman como aproximação, e o **ajuste de Holm** controlou a multiplicidade das seis comparações principais — procedimento que, de fato, elevou os dois menores valores de p brutos (internações × umidade) para patamares não significativos. Reconhece-se, ainda, que o pré-branqueamento consome graus de liberdade e que a **baixa frequência mensal dos desfechos** — sobretudo o SINASC (56 casos no Q20–Q26 em 180 meses; as internações somam 173) — limita o poder estatístico desta etapa.

Em síntese, a etapa exploratória **não evidenciou associação** entre as exposições ambientais e os desfechos após a remoção dos padrões temporais compartilhados. Esse resultado é coerente com a natureza predominantemente congênita e estrutural das cardiopatias e orienta a próxima etapa: a avaliação formal de associação por modelos de regressão (Poisson com defasagens distribuídas), na qual eventuais efeitos de curto prazo poderão ser testados com maior sensibilidade e controle de confundimento.
