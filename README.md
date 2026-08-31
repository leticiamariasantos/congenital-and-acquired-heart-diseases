# Cardiopatias Congênitas e Adquiridas

Análise de **cardiopatias congênitas (CID-10 Q20–Q28)** em nascidos vivos e em
internações hospitalares de menores de um ano, residentes em
**Campos dos Goytacazes (RJ)**, no período de **2020 a 2024**.

Projeto desenvolvido como parte do Trabalho de Conclusão de Curso (TCC).

> **Repositório oficial:** https://github.com/leticiamariasantos/congenital-and-acquired-heart-diseases

---

## Descrição

O estudo utiliza dados públicos do **DATASUS** — **SINASC** (Sistema de
Informações sobre Nascidos Vivos) e **SIH-RD** (Sistema de Informações
Hospitalares, reduzida) — obtidos por meio do pacote R
[`microdatasus`](https://github.com/rfsaldanha/microdatasus), além de dados
meteorológicos do **INMET** (estação A607 — Campos dos Goytacazes).

São extraídos os registros com:

- **SINASC:** nascidos vivos com **qualquer** código CID-10 **Q20–Q28**
  (malformações congênitas do aparelho circulatório), cuja mãe reside em
  Campos dos Goytacazes (`CODMUNRES = 330100`).
- **SIH-RD:** internações de **menores de 1 ano** com diagnóstico principal
  **Q20–Q28**, residentes em Campos dos Goytacazes (`MUNIC_RES = 330100`).

> ⚠️ **Escopo atual:** a extração cobre apenas as cardiopatias **congênitas**
> (Q20–Q28). A inclusão de cardiopatias **adquiridas** (ex.: CID I00–I99) é
> uma etapa futura do trabalho.

---

## Objetivos

1. Estimar a frequência de cardiopatias congênitas (Q20–Q28) em nascidos vivos
   e internações de menores de um ano em Campos dos Goytacazes (2020–2024).
2. Descrever o perfil sociodemográfico e clínico dos casos.
3. Fornecer um pipeline **reprodutível** e **auditável** de extração e
   processamento dos microdados do DATASUS.

---

## Estrutura do repositório

```
.
├── analysis/                 # Scripts de análise (figuras e tabelas)
│   └── 01_analise_exploratoria.R
├── data/
│   ├── raw/inmet/            # Dados meteorológicos INMET (2020–2024)
│   ├── processed/            # Tabelas finais extraídas (.rds)
│   ├── cache/                # Caches DATASUS (NÃO versionado)
│   └── README.md
├── docs/
│   ├── AUDITORIA.md          # Relatório de auditoria do código
│   └── METODOLOGIA.md        # Critérios, thresholds e benchmarks
├── results/
│   ├── auditoria/            # CSVs/JSONs de auditoria e metadados
│   ├── figures/              # Figuras geradas
│   └── *.csv                 # Tabelas finais (CSV)
├── src/                      # Código-fonte (pipeline)
│   ├── 00_config.R           # Configurações e caminhos
│   ├── 01_utils.R            # Funções utilitárias
│   ├── 02_download.R         # Download DATASUS com cache/retry
│   ├── 03_process_sinasc.R   # Pipeline SINASC
│   ├── 04_process_sih.R      # Pipeline SIH-RD
│   ├── run_sinasc.R          # Executa o pipeline SINASC
│   └── run_sih.R             # Executa o pipeline SIH-RD
├── tests/
│   └── test_utils.R          # Testes das funções utilitárias
├── .gitignore                # Arquivos/pastas ignorados pelo Git
├── LICENSE                   # MIT
├── README.en.md              # Resumo em inglês
├── README.md
└── requirements.R            # Instalação de dependências
```

---

## Instalação e execução

### Pré-requisitos

- [R](https://cran.r-project.org/) ≥ 4.1 (testado em R 4.5.3).
- Acesso à internet (apenas para o **primeiro** download do DATASUS; depois os
  caches locais são reutilizados).

### 1. Instalar dependências

```r
# a partir da raiz do repositório
source("requirements.R")
# ou: Rscript requirements.R
```

### 2. Executar a extração

```r
Rscript src/run_sinasc.R   # extrai casos Q20–Q28 do SINASC
Rscript src/run_sih.R      # extrai internações Q20–Q28 (< 1 ano) do SIH-RD
```

Os scripts:

- baixam os microdados do DATASUS (com retry e cache em `data/cache/`);
- aplicam os critérios de inclusão;
- geram as tabelas finais (`data/processed/*.rds` e `results/*.csv`);
- geram arquivos de auditoria e metadados (`results/auditoria/`).

### 3. Executar a análise exploratória

```r
Rscript analysis/01_analise_exploratoria.R
```

Gera as figuras em `results/figures/` e o resumo anual em
`results/resumo_anual_casos.csv`.

### 4. Rodar os testes

```r
Rscript tests/test_utils.R
```

---

## Principais resultados

| Ano | Nascidos vivos Q20–Q28 (SINASC) | Internações Q20–Q28 < 1 ano (SIH-RD) |
|-----|----------------------------------|---------------------------------------|
| 2020 | 5 | 7 |
| 2021 | 4 | 12 |
| 2022 | 6 | 16 |
| 2023 | 7 | 10 |
| 2024 | 6 | 10 |
| **Total** | **28** | **55** |

- Internações por faixa etária: **11 neonatos** (0–28 dias) e **44 lactentes**
  (29–364 dias).
- Detalhes metodológicos em [`docs/METODOLOGIA.md`](docs/METODOLOGIA.md).
- Relatório de auditoria em [`docs/AUDITORIA.md`](docs/AUDITORIA.md).

---

## Reproducibilidade

- Caminhos relativos à raiz do repositório (sem caminhos absolutos).
- Cache local de downloads (`data/cache/`, ignorado pelo Git).
- Metadados com versões de pacotes, versão do R, `sessionInfo()` e hashes
  SHA-256 dos arquivos gerados (`results/auditoria/`).
- Cada linha das tabelas finais possui `audit_row_id` e `audit_hash_linha`.

---

## Fontes de dados

- **SINASC / SIH-RD** — DATASUS (Ministério da Saúde), via
  [`microdatasus`](https://github.com/rfsaldanha/microdatasus).
- **INMET** — Estação A607 (Campos dos Goytacazes), dados meteorológicos
  horários 2020–2024.

> **Privacidade:** as colunas do SIH-RD com dados pessoais ou identificadores
> únicos (`CPF_AUT`, `GESTOR_CPF`, `GESTOR_DT`, `IDENT`, `N_AIH`) são removidas
> no pipeline antes da publicação (ver [`docs/METODOLOGIA.md`](docs/METODOLOGIA.md)).

---

## Como citar

> Santos, L. M. *Cardiopatias Congênitas e Adquiridas*. Trabalho de Conclusão
> de Curso. Repositório: https://github.com/leticiamariasantos/congenital-and-acquired-heart-diseases

Formato BibTeX:

```bibtex
@misc{santos_cardiologias,
  author       = {Santos, Letícia Maria},
  title        = {Cardiopatias Congênitas e Adquiridas},
  year         = {2026},
  howpublished = {\url{https://github.com/leticiamariasantos/congenital-and-acquired-heart-diseases}},
  note         = {Trabalho de Conclusão de Curso}
}
```

---

## Licença

Este projeto está licenciado sob a **MIT License** — veja [LICENSE](LICENSE).

Os dados do DATASUS e do INMET são públicos; verifique os termos de uso de cada
fonte antes de redistribuição.
