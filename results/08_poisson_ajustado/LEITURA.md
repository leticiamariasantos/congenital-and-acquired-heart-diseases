# Leitura dos modelos de Poisson — bruto × ajustado

Modelo ajustado = exposições + sin(2πm/12) + cos(2πm/12) + t (sazonalidade + tendência),
com offset = log(nascidos vivos). Três famílias: Poisson, Quasi-Poisson e Binomial Negativa.

## Conclusões (família Poisson — modelo principal)

Associações que PERDERAM significância ao ajustar:
  - SIH-RD (internações mensais Q20-Q28) × Precipitação: passou de significativa (bruto) a não significativa (ajustado).
  - SIH-RD (internações mensais Q20-Q28) × Umidade: passou de significativa (bruto) a não significativa (ajustado).

Associações que EMERGIRAM ao ajustar:
  - nenhuma associação emergiu com o ajuste.

Associações que PERMANECERAM significativas:
  - nenhuma associação permaneceu significativa.

## Interpretação
O ajuste por sazonalidade e tendência remove a parte da variação compartilhada
com o calendário e com a deriva temporal. As associações que não se sustentam
ao ajuste eram, em boa parte, explicadas por esse padrão temporal — o que é um
achado legítimo e defensável (não um erro). Lembrar que o ajuste também reduz a
precisão (intervalos mais largos), com apenas 60 meses de dados.

Fonte: DATASUS (SINASC/SIH-RD), INMET A607 (clima) e VIGIAR/MS (MP2,5).
