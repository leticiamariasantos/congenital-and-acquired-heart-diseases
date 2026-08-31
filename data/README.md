# Dados

Este diretório contém os dados utilizados e gerados pelo projeto.

## Estrutura

```
data/
├── raw/                 # Dados brutos de entrada (INMET)
│   └── inmet/           # Estação meteorológica A607 — Campos dos Goytacazes (2020–2024)
├── processed/           # Tabelas finais extraídas (RDS), prontas para análise
└── cache/               # Caches de download/processamento do DATASUS (NÃO versionado)
    ├── raw/             # Arquivos brutos baixados (SINASC e SIH-RD)
    └── processed/       # Arquivos pós-processamento do microdatasus
```

## Fontes

| Fonte  | Sistema | Período | Escopo |
|--------|---------|---------|--------|
| DATASUS | SINASC (Nascidos Vivos) | 2020–2024 | RJ — residência em Campos dos Goytacazes (330100) |
| DATASUS | SIH-RD (Internações) | 2020–2024 | RJ — residência em Campos dos Goytacazes (330100) |
| INMET | Estação A607 | 2020–2024 | Campos dos Goytacazes (dados meteorológicos horários) |

## Versionamento

- `data/raw/inmet/` e `data/processed/` **são versionados** (arquivos pequenos).
- `data/cache/` **NÃO é versionado** (arquivos grandes, regeneráveis via
  `src/run_sinasc.R` e `src/run_sih.R`). Os caches evitam novos downloads do
  DATASUS, mas podem ser recriados a qualquer momento.

## Observações sobre os dados do DATASUS

- Os dados são públicos e obtidos via pacote R [`microdatasus`](https://github.com/rfsaldanha/microdatasus).
- Os microdados do SINASC e do SIH-RD podem conter variáveis sensíveis
  (ex.: CPF de gestor hospitalar no SIH-RD). Por isso, o pipeline remove as
  colunas `CPF_AUT`, `GESTOR_CPF`, `GESTOR_DT`, `IDENT` e `N_AIH` antes da
  publicação (ver `src/00_config.R` → `CONFIG$colunas_sensiveis_sih`).
