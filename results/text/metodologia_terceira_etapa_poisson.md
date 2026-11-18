# Terceira etapa — Modelos de regressão de Poisson (Quasi-Poisson)

Para estimar a associação entre as exposições ambientais e cada desfecho, ajustaram-se **modelos lineares generalizados de Poisson com correção de superdispersão pela abordagem Quasi-Poisson**, produzindo **razões de taxas de incidência (IRR)** com intervalos de confiança de 95%, a partir das contagens mensais de cada desfecho.

**Offset.** Para os nascidos vivos, o *offset* foi o logaritmo do número de nascidos vivos do mês, que representa a população sob risco dos nascimentos. Para as internações de menores de um ano, o *offset* foi o logaritmo da soma dos nascidos vivos da **janela de 12 meses que termina no mês corrente** (mês atual e os 11 anteriores), como aproximação da população de menores de um ano sob risco.

**Ajuste temporal.** Todos os modelos incluíram, como covariáveis de controle, dois pares de harmônicos de Fourier (sazonalidade anual e semestral), uma *spline* natural do tempo (com sete graus de liberdade) para a tendência de longo prazo e um indicador binário do período pandêmico (fevereiro de 2020 a abril de 2022; Portarias GM/MS nº 188/2020 e nº 913/2022), de modo a evitar confundimento por padrões temporais compartilhados entre exposições e desfechos.

**Defasagem.** Cada exposição foi incorporada na janela temporal pertinente ao desfecho: para os nascidos vivos, a **média da exposição nos 6 a 9 meses anteriores ao parto** (periconcepção e primeiro trimestre, período da cardiogênese); para as internações, a **média nos 0 a 3 meses anteriores** (exposição recente), em coerência com a etapa exploratória.

**Estratégia de modelagem.** Cada exposição (MP2,5, temperatura e umidade relativa) foi modelada inicialmente de forma isolada e, em seguida, em um modelo conjunto com as três exposições, verificando-se a colinearidade pelo **fator de inflação da variância (VIF)**, com corte de 10. Os IRRs foram expressos **por incremento de um intervalo interquartil (IQR)** de cada exposição, cujos valores foram reportados, de modo a tornar os efeitos comparáveis entre exposições com unidades distintas.

**Autocorrelação residual e multiplicidade.** A autocorrelação das séries mensais foi inspecionada pela função de autocorrelação (ACF) dos resíduos, e utilizaram-se **erros-padrão robustos de Newey-West (HAC)** para evitar a subestimação da variância. Dado o número reduzido de associações pré-especificadas (seis combinações principais — três exposições × dois desfechos), a multiplicidade foi considerada na interpretação, sem correção formal adicional; destaca-se que a associação significativa identificada permaneceu estável, inclusive diante de correção conservadora.

**Limitações.** Reconhece-se a baixa frequência mensal dos desfechos — sobretudo o SINASC (56 casos no Q20–Q26 em 180 meses, com cerca de 60–70% dos meses sem casos; as internações somam 173) —, que limita o poder estatístico e pode tornar instáveis as estimativas pontuais.
