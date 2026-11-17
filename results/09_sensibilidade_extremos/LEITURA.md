# Análise de sensibilidade — exposições em extremos × médias

Objetivo: verificar se a escolha da métrica de exposição (média mensal vs.
extremos do mês) muda a direção/significância das associações.
Modelos de Poisson com offset = log(nascidos vivos), trocando UMA exposição por vez,
nas duas especificações (bruto e ajustado por sazonalidade + tendência).

## O que a sensibilidade acrescenta
1. ROBUSTEZ: se o resultado é o mesmo sob métricas diferentes, ganha credibilidade;
   se muda, revela que a conclusão depende da escolha da exposição.
2. ESPECIFICIDADE DA EXPOSIÇÃO: distingue efeito de exposição média (crônica)
   de efeito de picos (agudo), o que ajuda a discutir o mecanismo biológico.
3. TRANSPARÊNCIA: evita a crítica de que o achado é 'resultado de conveniência'
   de uma única métrica escolhida.

## Limitações
Cada variante extra reduz o poder e aumenta o número de testes (múltiplas
comparações). Os IRR têm unidades diferentes (por 1 °C; por 1 %; por 1 dia acima
do limite), então comparar magnitudes exige cautela — o foco é a direção e a
significância. Para MP2,5 não há máximo/mínimo mensal na fonte VIGIAR; o
'extremo' disponível são os dias acima dos limites.

Fonte: DATASUS (SINASC/SIH-RD), INMET A607 (clima) e VIGIAR/MS (MP2,5).
