# Metodologia, critérios e limiares (thresholds)

Este documento descreve os critérios de inclusão, os limiares de classificação
e as decisões metodológicas adotadas, de forma a garantir reprodutibilidade e
rastreabilidade.

## 1. Definições clínicas e critérios de inclusão

### 1.1 Cardiopatias congênitas (CID-10 Q20–Q28)

- **Critério diagnóstico:** presença de **qualquer** código CID-10 no intervalo
  **Q20–Q28** (Malformações congênitas do aparelho circulatório).
- **SINASC:** campo `CODANOMAL`, que pode conter múltiplos códigos concatenados
  (ex.: `Q224Q233Q253Q891`). Um registro é incluído quando **ao menos um** dos
  códigos pertence a Q20–Q28, independentemente da posição na concatenação.
- **SIH-RD:** campo `DIAG_PRINC` (diagnóstico principal), código único Q20–Q28.

> **Correção importante:** a versão anterior do código usava
> `grepl("^Q2[0-8]", x)`, que avaliava apenas o **primeiro** código da
> concatenação no SINASC. Registros como `Q031Q248` (primeiro código não
> cardíaco) eram descartados indevidamente. A correção recuperou 6 casos.

### 1.2 Município de residência

- **Código IBGE:** `330100` — Campos dos Goytacazes (RJ).
- **SINASC:** campo `CODMUNRES` (município de residência da mãe).
- **SIH-RD:** campo `MUNIC_RES` (município de residência do paciente).
- Observação: o município de **ocorrência** (nascimento/internação) pode
  diferir do de residência; o critério adotado é sempre **residência**.

### 1.3 Presença de anomalia (apenas SINASC)

- Campo `IDANOMAL` igual a `"1"` ou `"Sim"`.

## 2. Classificação etária (apenas SIH-RD)

| Faixa     | Idade (dias) | Justificativa |
|-----------|--------------|---------------|
| Neonato   | 0–28         | Período neonatal (primeiros 28 dias de vida), definição padrão da OMS. |
| Lactente  | 29–364       | Do 29º dia até o dia anterior a completar 1 ano. |
| Menor de 1 ano | 0–364    | Critério de inclusão do estudo (< 365 dias). |

- A idade é calculada preferencialmente por **datas**:
  `idade_dias = DT_INTER − NASC`.
- Quando as datas são inválidas/ausentes, usa-se o fallback por
  `COD_IDADE`/`IDADE` (Horas/Dias/Meses/Anos/Centena de anos), com as
  conversões aproximadas:
  - 1 mês = 30 dias
  - 1 ano = 365 dias
  - centena de anos = (100 + idade) × 365 dias
  - horas → dias (÷ 24)

> **Correção importante:** o microdatasus retorna `COD_IDADE` como **rótulo**
> (`"Horas"`, `"Dias"`, `"Meses"`, `"Anos"`, `"Centena de anos (100 + idade)"`),
> não como código numérico (`"1"`..`"5"`). A versão anterior comparava com
> `"2"/"3"/"4"`, tornando o fallback inoperante. A correção aceita ambos os
> formatos e todos os rótulos emitidos pelo microdatasus.

## 3. Limiares (thresholds) e benchmarks

### 3.1 Limiares de classificação

| Parâmetro | Valor | Fonte/justificativa |
|-----------|-------|---------------------|
| Corte idade neonatal | ≤ 28 dias | Definição OMS de período neonatal. |
| Corte "menor de 1 ano" | < 365 dias | Critério clínico do estudo. |
| Regex CID Q20–Q28 | `^Q2[0-8]` | Intervalo CID-10 de malformações congênitas do aparelho circulatório. |
| Conversão mês→dias (fallback) | 30 dias | Aproximação convencional. |
| Conversão ano→dias (fallback) | 365 dias | Aproximação convencional. |

### 3.2 Benchmarks / valores de referência

- **Não há modelo preditivo** neste repositório; portanto, não há thresholds de
  probabilidade/risco a calibrar.
- A comparação com a literatura (incidência de cardiopatias congênitas, perfil
  de morbidade hospitalar etc.) deverá ser feita na etapa de **análise** e
  **discussão** do TCC, citando referências apropriadas (ex.: incidência global
  estimada de ~8–10 por 1.000 nascidos vivos — van der Linde et al., 2011;
  Hoffman & Kaplan, 2002). Esses valores servem como referência externa e devem
  ser interpretados com cautela, pois o presente recorte é municipal e
  restrito a Q20–Q28.

## 4. Privacidade e remoção de dados sensíveis

As seguintes colunas do SIH-RD são **removidas antes da publicação** por
conterem dados pessoais ou identificadores únicos (definidas em
`src/00_config.R` → `CONFIG$colunas_sensiveis_sih`):

| Coluna | Motivo |
|--------|--------|
| `CPF_AUT` | CPF do profissional autorizador (dado pessoal). |
| `GESTOR_CPF` | CPF do gestor (dado pessoal). |
| `GESTOR_DT` | Data do gestor (desnecessária à análise). |
| `IDENT` | Identificador do paciente (dado pessoal). |
| `N_AIH` | Número da AIH (identificador único da internação). |

Os códigos institucionais públicos (`CNES`, `CNPJ_MANT`, `CGC_HOSP`) são
mantidos, pois identificam estabelecimentos (não pessoas).

## 5. Padronização e ambiguidades resolvidas

| Ambiguidade | Decisão adotada |
|-------------|-----------------|
| `CODANOMAL` com múltiplos códigos | Incluir se **qualquer** código for Q20–Q28. |
| `COD_IDADE` em rótulo vs código numérico | Aceitar ambos. |
| Idade por data vs por código | Preferir data; usar código apenas como fallback. |
| Município de residência vs ocorrência | Usar **residência**. |
| Diagnóstico principal vs secundário (SIH) | Usar **principal** (`DIAG_PRINC`). |
