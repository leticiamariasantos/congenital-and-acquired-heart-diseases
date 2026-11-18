# Resultados e discussão — análises de sensibilidade

## Resultados

A associação principal (umidade × internações, Q20–Q26) foi reestimada sob diferentes especificações, com o seguinte resultado:

| Sensibilidade | IRR (por IQR) | IC 95% | p | Significativo |
|---|---|---|---|---|
| Base (Q20–Q26, spline df = 7) | 0,58 | 0,41–0,83 | 0,002 | Sim |
| (i) Desfecho ampliado (Q20–Q28) | 0,63 | 0,46–0,86 | 0,004 | Sim |
| (ii) Spline df = 3 | 0,59 | 0,42–0,84 | 0,003 | Sim |
| (ii) Spline df = 4 | 0,61 | 0,42–0,88 | 0,007 | Sim |
| (ii) Spline df = 6 | 0,64 | 0,44–0,92 | 0,017 | Sim |
| (iii) Exclusão do período pandêmico | 0,57 | 0,37–0,88 | 0,011 | Sim |
| (iv) Umidade mínima absoluta (extremo) | 0,78 | 0,51–1,22 | 0,278 | Não |
| (v) Binomial Negativa | 0,58 | 0,38–0,89 | 0,012 | Sim |

## Discussão

A associação mostrou-se **robusta na quase totalidade das especificações**. O efeito manteve o **mesmo sentido** (IRR < 1, indicando proteção) e a **significância estatística** — com magnitude estável, entre 0,57 e 0,64 — quando: o desfecho foi ampliado para Q20–Q28 (i); a tendência foi especificada com 3, 4 ou 6 graus de liberdade (ii); o período pandêmico foi excluído (iii); e o modelo foi reajustado sob distribuição Binomial Negativa (v). Em particular, a **exclusão do período pandêmico não alterou o resultado**, indicando que a associação não é um artefato das alterações assistenciais e ambientais da COVID-19.

A única especificação em que a significância se perdeu foi a **(iv), quando a exposição foi expressa pela umidade mínima absoluta mensal (extremo) em lugar da média**: o efeito atenuou-se (IRR de 0,58 para 0,78) e deixou de ser significativo (p = 0,278), embora o **sentido tenha sido preservado**. Esse comportamento é informativo e biologicamente coerente: a associação parece ser conduzida pela **umidade média**, que representa o grau de ressecamento ambiental sustentado ao longo do mês — condição que favorece cumulativamente a sobrevivência e a transmissão de vírus respiratórios —, e não por episódios extremos isolados de baixa umidade, demasiado pontuais para capturar esse mecanismo.

Em síntese, o achado de associação negativa entre umidade e internações é **robusto a variações de definição de caso, de especificação temporal, de período (com e sem pandemia) e de distribuição do erro**, sendo sensível apenas à troca da **média pelo extremo mínimo** da exposição — o que, antes de enfraquecer, reforça a plausibilidade mecanicista do resultado: o que importa é a **secura média do ambiente**, não o valor extremo de um único dia.
