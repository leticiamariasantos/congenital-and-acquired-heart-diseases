# Relatório de Auditoria do Projeto

Auditoria técnica do repositório **Cardiopatias Congênitas e Adquiridas**,
realizada antes da publicação no GitHub.

> **Transparência sobre o uso de IA:** esta auditoria e a refatoração dos
> scripts foram realizadas com apoio técnico da ferramenta de Inteligência
> Artificial Generativa **DeepSeek (modelo `deepseek-v4-pro`)**, utilizada como
> assistente de programação e edição de texto. O uso está declarado em
> conformidade com a **Portaria CNPq nº 2.664/2026** (art. 9º, I, "c"), na
> seção *"Declaração de uso de Inteligência Artificial Generativa"* do
> `README.md`. Nenhum dado foi gerado por IA e todos os resultados foram
> revisados e validados manualmente.

---

## 1. Problemas encontrados (por gravidade)

### 🔴 Crítico

| # | Problema | Onde | Impacto | Correção |
|---|----------|------|---------|----------|
| C1 | **Bug de ancoragem na seleção de CID Q20–Q28.** `grepl("^Q2[0-8]", CODANOMAL)` avaliava apenas o **primeiro** código da concatenação do SINASC. Registros com primeiro código não cardíaco (ex.: `Q031Q248`, `Q175Q189Q249`, `Q059Q204Q224Q602`) eram **descartados indevidamente**. | `extrair_sinasc_*.R` / `src/03_process_sinasc.R` | **6 casos perdidos** (subcontagem de 22 → 28; erro de ~21% no total). | `tem_cid_q20_q28()` agora varre **todos** os códigos Qxxx presentes. |
| C2 | **CSV publicado inconsistente com os scripts.** Os CSVs em `resultados/` tinham colunas removidas (sem `CODMUNRES`/`MUNIC_RES` e sem colunas `audit_*`), enquanto os scripts gravam a tabela completa. Reexecutar os scripts geraria CSVs diferentes do que estava publicado. | `resultados/*.csv` | Falha de reprodutibilidade: CSV ≠ RDS ≠ script. | Pipeline unificado: RDS e CSV agora contêm exatamente a mesma tabela. |
| C3 | **Pasta `RStudio/` (1,6 GB) dentro do projeto.** Contém a instalação completa do IDE (binários, Chromium, DLLs, `locales/`). | raiz do projeto | Poluiria o repositório (4.329 arquivos) e poderia vazar artefatos locais. | Adicionada ao `.gitignore`; recomendação: mover para fora da pasta do projeto. |
| C4 | **Dados pessoais em metadados.** Os JSON de metadados gravavam `Sys.info()` (nomes `nodename`, `login`, `user`, `effective_user`, domínio) e caminhos absolutos com o nome do usuário. | `resultados/auditoria/metadados_*.json` | Vazamento de informação pessoal (usuário `letic`, máquina `LETICIA`). | `montar_metadados()` grava apenas versão de R, plataforma, pacotes e sessionInfo (sem dados pessoais). |

### 🟠 Importante

| # | Problema | Onde | Impacto | Correção |
|---|----------|------|---------|----------|
| I1 | **Fallback de idade inoperante (COD_IDADE).** O código comparava `COD_IDADE` com `"2"/"3"/"4"`, mas o `microdatasus` retorna **rótulos** (`"Dias"`, `"Meses"`, `"Anos"`, `"Centena de anos (100 + idade)"`). O fallback nunca funcionava (latente: as datas estavam válidas, então não afetou o resultado atual, mas quebraria com datas ausentes). | `scripts/extrair_sih_*.R` | Fragilidade e código morto. | `idade_dias_por_codigo()` aceita rótulos e códigos numéricos, incluindo Horas, Minutos e Centena de anos. |
| I2 | **`normalizar_cid()` removia letras minúsculas.** `toupper(gsub("[^A-Z0-9]", ...))` removia `a-z` **antes** de converter para maiúsculas. Latente (dados já vinham em maiúsculas), mas errado para entradas minúsculas. | `src/01_utils.R` | Normalização incorreta para códigos em minúsculo. | Regex passou a preservar `A-Za-z0-9`. |
| I3 | **Título "adquiridas" sem correspondência nos dados.** O projeto intitula "Cardiopatias Congênitas **e Adquiridas**", mas só extrai Q20–Q28 (exclusivamente **congênitas**). Não há extração de cardiopatias adquiridas (ex.: CID I00–I99). | documentação vs. implementação | Lacuna conceitual entre título e escopo real. | Documentado no README como limitação/escopo atual; recomendação de etapa futura. |
| I4 | **Arquivos de aula e lixo misturados ao projeto.** `aula de gráficos.R` (script didático com dados de `iris`/`dengue`, mojibake de encoding, `setwd()` com caminhos absolutos, `install.packages()` no meio do código), `gráficos tcc.R` (vazio), `Untitled-1.r` (instala pacote `vigiar` não relacionado), `Rplot*.png`, `.Rhistory`. | `resultados/`, `dados/` | Ruído, código morto e caminhos pessoais. | Removidos. |
| I5 | **Nomenclatura inconsistente de arquivos/pastas.** Script SINASC na raiz e script SIH em `scripts/`; nomes com `malformacoes_circulatorias` vs. `q20_q28`; arquivo INMET com nome duplicado e espaços. | raiz, `scripts/`, `inmet/` | Dificuldade de manutenção. | Estrutura padronizada (`src/`, `data/raw/inmet/` com nomes `inmet_campos_goytacazes_YYYY.csv`). |

### 🟡 Melhoria

| # | Problema | Onde | Correção |
|---|----------|------|----------|
| M1 | Dupla computação da idade (`calcular_idade_dias` chamada 2× e ainda sobre dados não filtrados) na auditoria mensal do SIH. | `scripts/extrair_sih_*.R` | Cálculo feito uma única vez, reutilizado na auditoria. |
| M2 | `audit_linha_aprovada`/`audit_classe_idade_valida` redundantes (sempre TRUE após o filtro). | `scripts/extrair_sih_*.R` | Flags calculadas **antes** do filtro; coluna redundante removida. |
| M3 | `n_reprovadas_pos_filtro` sempre 0 (métrica sem sentido). | `scripts/extrair_sih_*.R` | Removida. |
| M4 | `parse_data_sih` com chamadas redundantes de `ymd()`. | `scripts/extrair_sih_*.R` | Simplificado. |
| M5 | Hash de linha usando `cur_data()` dentro de `map_chr` (frágil e lento). | `scripts/*.R` | Substituído por `hash_linhas()` com `vapply`. |
| M6 | `install.packages()` e `View()`/`setwd()` interativos espalhados no código. | vários | Removidos; dependências centralizadas em `requirements.R`. |
| M7 | Ausência de type hints/docstrings padronizadas (estilo R) e de testes. | — | Módulos documentados + `tests/test_utils.R`. |
| M8 | Sem `.gitignore`, `LICENSE`, `README`, `requirements`. | raiz | Todos criados. |
| M9 | Codificação dos arquivos `.R` em Latin-1/CP1252 (mojibake). | `aula de gráficos.R` | Arquivo removido; novos arquivos em UTF-8. |

---

## 2. Thresholds e benchmarks

| Item | Status | Ação |
|------|--------|------|
| Corte neonatal (0–28 dias) | Consistente com a OMS; documentado. | Mantido e centralizado em `CONFIG$criterios`. |
| Corte "menor de 1 ano" (< 365 dias) | Consistente; documentado. | Mantido. |
| Regex Q20–Q28 (`^Q2[0-8]`) | **Incorreto para concatenações** (ver C1). | Corrigido para "qualquer código Q20–Q28". |
| Conversões 30 dias/mês e 365 dias/ano | Aproximações razoáveis; não documentadas. | Documentadas em `docs/METODOLOGIA.md`. |
| Benchmarks com literatura | **Inexistentes** no código (nenhum modelo/limiar de risco). | Documentado que a comparação deve ocorrer na etapa de discussão do TCC; referências sugeridas no `docs/METODOLOGIA.md`. |
| Diagnóstico principal vs. secundário (SIH) | Usa apenas `DIAG_PRINC` (decisão não explícita). | Documentado. |

---

## 3. Mudanças realizadas

1. **Estrutura** reorganizada:
   ```
   analysis/  data/{raw,processed,cache}  docs/  results/{auditoria,figures}  src/  tests/
   ```
2. **Código** modularizado em `src/` (`00_config.R`, `01_utils.R`,
   `02_download.R`, `03_process_sinasc.R`, `04_process_sih.R`,
   `run_sinasc.R`, `run_sih.R`).
3. **Bugs corrigidos**: ancoragem do CID (C1), fallback de `COD_IDADE` (I1),
   `normalizar_cid` (I2), CSV inconsistente (C2).
4. **Limpeza**: remoção de aula didática, arquivos vazios, `Untitled-1.r`,
   `Rplot*.png`, `.Rhistory`, scripts antigos duplicados, pasta `scripts/`.
5. **Dados INMET** renomeados e movidos para `data/raw/inmet/`.
6. **Documentação**: `README.md`, `docs/METODOLOGIA.md`, `docs/AUDITORIA.md`,
   `data/README.md`, `requirements.R`, `LICENSE` (MIT), `.gitignore`.
7. **Análise exploratória** reescrita em `analysis/01_analise_exploratoria.R`
   (substitui os gráficos soltos do `.Rhistory`), gerando 6 figuras e o
   `results/resumo_anual_casos.csv`.
8. **Testes** básicos em `tests/test_utils.R`.

---

## 4. Resultados após reexecução

| Métrica | Antes | Depois | Observação |
|---------|-------|--------|------------|
| SINASC — casos Q20–Q28 (2020–2024) | 22 | **28** | +6 casos recuperados (bug C1). |
| SIH-RD — internações Q20–Q28 < 1 ano | 55 | 55 | Inalterado. |
| SIH-RD — Neonatos | 11 | 11 | Inalterado. |
| SIH-RD — Lactentes | 44 | 44 | Inalterado. |
| Colunas SINASC (RDS) | 77 | 77 | — |
| Colunas SIH-RD (RDS) | 133 | 127 | Removida coluna redundante `audit_classe_idade_valida` + 5 colunas sensíveis (privacidade). |
| Testes unitários | — | 10/10 passaram | `tests/test_utils.R`. |

**Casos recuperados no SINASC (exemplos):**

| Ano | CODANOMAL |
|-----|-----------|
| 2020 | `Q059Q204Q224Q602` |
| 2021 | `Q175Q189Q249` |
| 2022 | `Q031Q189Q212Q213Q248` |
| 2023 | `Q031Q248Q379`, `Q159Q249` |
| 2024 | `Q189Q248` |

> Os pipelines foram reexecutados usando os caches locais (`data/cache/`),
> sem novo download do DATASUS, e os resultados são reprodutíveis.

---

## 5. Sugestões finais

1. **Mover a pasta `RStudio/` para fora** do diretório do projeto antes do
   primeiro commit (ou garantir que está no `.gitignore`).
2. **Decidir o escopo de "adquiridas"**: adicionar extração de cardiopatias
   adquiridas (CID I00–I99, etc.) ou ajustar o título para refletir o escopo
   atual (apenas congênitas Q20–Q28).
3. ~~Revisar campos sensíveis do SIH-RD~~ ✅ **Resolvido** — colunas `CPF_AUT`,
   `GESTOR_CPF`, `GESTOR_DT`, `IDENT` e `N_AIH` já são removidas no pipeline
   (`CONFIG$colunas_sensiveis_sih`).
4. **Usar `renv`** (opcional) para travar versões exatas de pacotes e aumentar
   a reprodutibilidade a longo prazo.
5. **Complementar a análise** com testes estatísticos de tendência
   (Mann-Kendall/regressão) e a comparação com a literatura na etapa de
   discussão do TCC.
6. **Incluir os dados INMET** na análise se o objetivo for correlacionar
   variáveis meteorológicas com as internações (atualmente não utilizados).
7. **Adicionar CI** (ex.: GitHub Actions executando `Rscript tests/test_utils.R`)
   para validar automaticamente o repositório.
