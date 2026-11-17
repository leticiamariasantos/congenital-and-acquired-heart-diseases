# Cardiopatias Congênitas e Adquiridas — Campos dos Goytacazes (RJ)

Análise de **cardiopatias congênitas (CID-10 Q20–Q26)** e das malformações
congênitas do aparelho circulatório (**Q20–Q28**, análise de sensibilidade) em
nascidos vivos (SINASC) e em internações hospitalares de menores de um ano
(SIH-RD), residentes em **Campos dos Goytacazes (RJ, IBGE 3301009)**, no
período de **2010 a 2019**.

**Autora:** Letícia Maria Santos
**Orientadora:** Francielly da Silva Santos Moreira

> **Repositório:** https://github.com/leticiamariasantos/congenital-and-acquired-heart-diseases

---

## 1. Visão geral do pipeline (Etapa 1)

Este repositório contém um pipeline R **modular, documentado e 100%
reproduzível** que:

1. Extrai e processa os desfechos de saúde (DATASUS — SINASC e SIH-RD);
2. Extrai e processa as exposições ambientais (INMET — temperatura/umidade;
   VIGIAR/MS — PM2,5);
3. Calcula **prevalências** e **razões de internação** (por 1.000) com
   **intervalos de confiança exatos de Poisson (95%)**, nas escalas anual,
   trimestral e mensal;
4. Executa a **análise de tendência** (Mann-Kendall e Seasonal Mann-Kendall /
   Hirsch-Slack) e de **sazonalidade** (decomposição STL, razão de
   verossimilhança de modelos de Poisson, qui-quadrado e Kruskal-Wallis);
5. Gera **tabelas**, **figuras** e **texto** prontos para a seção de
   Resultados e Discussão do TCC.

A execução completa é feita com um único comando (ver seção 4).

---

## 2. Estrutura do repositório

```
scripts/
  00_config.R                      # Parâmetros centrais (período, códigos, critérios, caminhos)
  00_utils.R                       # Funções utilitárias (CID, datas, IC de Poisson, temas)
  01_download_process_datasus.R    # Download + processamento SINASC/SIH-RD (desfechos)
  02_download_process_exposures.R  # Download + processamento INMET (A607) e VIGIAR (PM2,5)
  03_prevalencias_razoes_IC.R      # Prevalências e razões de internação + IC Poisson
  04_tendencia_sazonalidade.R      # Tendência e sazonalidade
  05_generate_results_text.R       # Texto de Resultados e Discussão (Markdown)
  run_all.R                        # Executa 01→05 em ordem

data/
  processed/                       # Dados processados (saídas do pipeline)
  raw/                             # Dados brutos (INMET horário A607 e VIGIAR PM2,5)
  cache/                           # Cache de downloads (REGENERÁVEL — ignorado pelo git)

results/
  tables/                          # Tabelas de resultados (CSV)
  figures/                         # Figuras (PNG)
  text/                            # resultados_discussao_etapa1.md

analysis/  src/  docs/  tests/     # Trabalho anterior (análise 2020–2024) e documentação
```

### Arquivos gerados em `data/processed/`

| Arquivo | Conteúdo |
|---|---|
| `internacoes_q20q26_campos.csv` | Internações SIH-RD < 1 ano, Q20–Q26 (desfecho principal) |
| `internacoes_q20q28_campos.csv` | Internações SIH-RD < 1 ano, Q20–Q28 (sensibilidade) |
| `nascidos_malformacao_q20q26_campos.csv` | Nascidos vivos SINASC com Q20–Q26 |
| `nascidos_malformacao_q20q28_campos.csv` | Nascidos vivos SINASC com Q20–Q28 |
| `nascidos_totais_campos.csv` | Total de nascidos vivos residentes (denominador, mensal) |
| `temp_umidade_mensal_A607_2010_2019.csv` | Temperatura e umidade mensais (INMET A607) com cobertura |
| `temp_umidade_mensal_A607_2010_2019_exclusoes.csv` | Meses excluídos por cobertura < 80% |
| `pm25_mensal_campos_2010_2019.csv` | Concentração mensal de MP2,5 (µg/m³) |

---

## 3. Métodos — decisões principais

### 3.1 Desfechos

- **SINASC:** nascidos vivos com `CODMUNRES = 330100` e `CODANOMAL` contendo
  **qualquer** código Q20–Q26 (principal) ou Q20–Q28 (sensibilidade). O campo
  `CODANOMAL` pode conter vários códigos concatenados; varre-se todos eles.
- **SIH-RD:** internações com `MUNIC_RES = 330100`, **idade < 1 ano** e
  diagnóstico **principal ou secundário** (`DIAG_PRINC` + `DIAGSEC1..9`) em
  Q20–Q26/Q20–Q28. A idade é calculada por `DT_INTER − NASC` (fallback por
  `COD_IDADE`/`IDADE`).
- A **série temporal** usa a **competência** (`ANO_CMPT`/`MES_CMPT`) no SIH-RD
  (padrão do sistema) e a data de nascimento (`DTNASC`) no SINASC.

### 3.2 Exposições

- **Temperatura e umidade (INMET):** estação automática **A607** (Campos dos
  Goytacazes), agregação mensal da média horária. **Critério de qualidade:**
  mantém-se apenas meses com **≥ 80% dos dias com registro** (temperatura e
  umidade); os meses excluídos são documentados em arquivo próprio.
- **MP2,5 (VIGIAR/MS):** concentração mensal (µg/m³), 2010–2019.

### 3.3 Análise estatística (Etapa 1)

- **Prevalência** = (casos SINASC / total de nascidos vivos) × 1.000.
- **Razão de internação** = (internações SIH < 1 ano / total de nascidos vivos)
  × 1.000.
- **IC 95% exato de Poisson** (Garwood, 1936) para todas as estimativas.
- **Tendência:** Mann-Kendall (séries anuais) e Seasonal Mann-Kendall /
  Hirsch-Slack (séries mensais).
- **Sazonalidade:** decomposição STL (exposições), razão de verossimilhança
  entre modelos de Poisson com/sem efeito de mês (desfechos, com offset pelo
  total de nascidos vivos) e testes complementares de qui-quadrado e
  Kruskal-Wallis.

### 3.4 Por que Q20–Q26 (principal) e Q20–Q28 (sensibilidade)?

O intervalo **Q20–Q28** (malformações congênitas do aparelho circulatório)
inclui as malformações do coração e grandes vasos (**Q20–Q26**, as
cardiopatias congênitas propriamente ditas) **e** as malformações de vasos
periféricos e outras estruturas (**Q27–Q28**). Adotou-se **Q20–Q26 como
desfecho principal** (interesse clínico-epidemiológico) e **Q20–Q28 como
análise de sensibilidade**, para avaliar a robustez dos resultados a diferentes
definições de caso.

---

## 4. Reprodução

### 4.1 Dependências

Instale as dependências com:

```r
Rscript requirements.R
```

Pacotes principais: `microdatasus`, `BrazilMet`, `vigiar` (GitHub),
`dplyr`, `tidyr`, `readr`, `lubridate`, `stringr`, `httr`, `ggplot2`,
`viridisLite`, `Kendall`, `trend`.

### 4.2 Execução

A partir da raiz do repositório:

```bash
Rscript scripts/run_all.R
```

ou, individualmente:

```bash
Rscript scripts/01_download_process_datasus.R
Rscript scripts/02_download_process_exposures.R
Rscript scripts/03_prevalencias_razoes_IC.R
Rscript scripts/04_tendencia_sazonalidade.R
Rscript scripts/05_generate_results_text.R
```

> Os downloads do DATASUS/INMET são armazenados em `data/cache/` (ignorado
> pelo git) e reutilizados nas execuções seguintes — o pipeline é **retomável**
> e **idempotente**.

---

## 5. Principais resultados (2010–2019)

| Indicador | Q20–Q26 (principal) | Q20–Q28 (sensibilidade) |
|---|---|---|
| Nascidos vivos residentes | 72.688 | 72.688 |
| Casos SINASC | 32 | 35 |
| Prevalência (‰, IC 95% Poisson) | 0,44 (0,30–0,62) | 0,48 (0,34–0,67) |
| Internações SIH < 1 ano | 117 | 130 |
| Razão de internação (‰, IC 95% Poisson) | 1,61 (1,33–1,93) | 1,79 (1,49–2,12) |

- **Tendência:** não houve tendência estatisticamente significativa nas séries
  anuais (Mann-Kendall) ou mensais (Hirsch-Slack), para nenhum dos desfechos.
- **Sazonalidade dos desfechos:** sem evidência significativa (razão de
  verossimilhança e qui-quadrado).
- **Sazonalidade das exposições:** temperatura, umidade e PM2,5 apresentam
  ciclo anual bem definido (decomposição STL; Kruskal-Wallis p < 0,05).

O texto completo, pronto para o TCC, está em
[`results/text/resultados_discussao_etapa1.md`](results/text/resultados_discussao_etapa1.md).

---

## 6. Conformidade e ciência aberta

- Dados públicos do DATASUS, INMET e VIGIAR/MS.
- Colunas com dados pessoais do SIH-RD (`CPF_AUT`, `GESTOR_CPF`, `GESTOR_DT`,
  `IDENT`, `N_AIH`) são **removidas** antes da publicação.
- Código comentado em português, com decisões metodológicas documentadas.
- O cache de downloads (`data/cache/`) é regenerável e não é versionado.

---

## 7. Histórico

- **Etapa 1 (este pipeline):** desfechos e exposições 2010–2019; prevalências,
  razões de internação, tendência e sazonalidade.
- **Trabalho anterior (2020–2024):** análise exploratória e inferencial
  (modelos de Poisson, DLNM) em `analysis/` e `src/`, documentada em
  `docs/`.
