# Congenital and Acquired Heart Diseases

Analysis of **congenital heart diseases (ICD-10 Q20–Q28)** among live births and
hospital admissions of infants under one year old, residents of
**Campos dos Goytacazes (RJ, Brazil)**, from **2020 to 2024**.

**Author:** Letícia Maria Santos
**Supervisor:** Francielly da Silva Santos Moreira

Project developed as an undergraduate thesis (TCC).

> **Official repository:** https://github.com/leticiamariasantos/congenital-and-acquired-heart-diseases

> The main documentation is in Portuguese. This file provides an English summary.

---

## Description

The study uses public data from **DATASUS** — **SINASC** (Live Births
Information System) and **SIH-RD** (Hospital Information System, reduced) —
downloaded via the R package
[`microdatasus`](https://github.com/rfsaldanha/microdatasus), plus weather data
from **INMET** (station A607 — Campos dos Goytacazes).

Records are extracted with:

- **SINASC:** live births with **any** ICD-10 code **Q20–Q28** (congenital
  malformations of the circulatory system) whose mother resides in Campos dos
  Goytacazes (`CODMUNRES = 330100`).
- **SIH-RD:** hospital admissions of **infants under 1 year** with principal
  diagnosis **Q20–Q28**, residents of Campos dos Goytacazes
  (`MUNIC_RES = 330100`).

> ⚠️ **Current scope:** extraction covers only **congenital** heart diseases
> (Q20–Q28). Acquired heart diseases (e.g., ICD I00–I99) are a future step.

---

## Main results

| Year | Live births Q20–Q28 (SINASC) | Admissions Q20–Q28 < 1 yr (SIH-RD) |
|------|------------------------------|-------------------------------------|
| 2020 | 5 | 7 |
| 2021 | 4 | 12 |
| 2022 | 6 | 16 |
| 2023 | 7 | 10 |
| 2024 | 6 | 10 |
| **Total** | **28** | **55** |

- Admissions by age group: **11 neonates** (0–28 days) and **44 infants**
  (29–364 days).
- See [`docs/METODOLOGIA.md`](docs/METODOLOGIA.md) for methods and thresholds
  and [`docs/AUDITORIA.md`](docs/AUDITORIA.md) for the full code audit report.

---

## Repository structure

```
analysis/    # Analysis scripts (figures and tables)
data/        # raw/ (INMET), processed/ (final .rds), cache/ (not versioned)
docs/        # AUDITORIA.md (audit report) and METODOLOGIA.md (methods)
results/     # auditoria/, figures/ and summary CSVs
src/         # Pipeline source code (config, utils, download, processing, runners)
tests/       # Unit tests for utility functions
```

---

## Installation and execution

**Requirements:** R ≥ 4.1 (tested on R 4.5.3).

```r
# Install dependencies (from the repository root)
Rscript requirements.R

# Extract cases
Rscript src/run_sinasc.R   # SINASC Q20–Q28 cases
Rscript src/run_sih.R      # SIH-RD Q20–Q28 admissions (< 1 year)

# Exploratory analysis
Rscript analysis/01_analise_exploratoria.R

# Run tests
Rscript tests/test_utils.R
```

---

## Reproducibility, portability, compliance and transparency

- **Reproducibility:** relative paths, local download cache (`data/cache/`),
  execution metadata with package versions, `sessionInfo()` and SHA-256
  checksums, per-row audit trail (`audit_*` columns and `audit_hash_linha`),
  automated tests.
- **Portability:** plain R code, UTF-8, cross-platform; `renv` recommended for
  long-term package version locking.
- **Compliance:** sensitive SIH-RD columns (`CPF_AUT`, `GESTOR_CPF`,
  `GESTOR_DT`, `IDENT`, `N_AIH`) are removed before publication (LGPD
  privacy). AI use is declared under **CNPq Ordinance 2.664/2026** (below).
- **Transparency:** open source, open data and metadata, documented inclusion
  criteria/thresholds and a complete audit report.

---

## Generative Artificial Intelligence use declaration (CNPq Ordinance 2.664/2026)

In accordance with **CNPq Ordinance nº 2.664, of 6 March 2026** (Scientific
Integrity Policy), and in particular with **art. 9, item I, sub-items "c" and
"d"** — which require *"declaring the use of Generative Artificial
Intelligence (GAI) tools, of any kind and at any stage of the research
(conception, writing, data analysis, submission), specifying in the respective
texts and electronic expositions the tool used and its purpose"* and which
*"forbid submitting GAI-generated content as if it were of human authorship,
with the authors being fully responsible for the final content"* — we declare:

### Tool used

| GAI tool | Model | Provider |
|----------|-------|----------|
| DeepSeek — programming and text-editing assistant | **deepseek-v4-pro** | DeepSeek |

### Purpose and stages of use

The GAI tool **deepseek-v4-pro** was used **solely as technical support** for
programming and text editing, in the following stages and purposes:

1. **Refactoring of the audit scripts** — review and rewriting of the
extraction/processing scripts (`src/`), the per-row audit trail (`audit_row_id`,
`audit_hash_linha` and `audit_*` columns) and the audit/metadata files
(`results/auditoria/`), as reported in [`docs/AUDITORIA.md`](docs/AUDITORIA.md).
2. **Code auditing and bug fixing** — identification and correction of bugs
(e.g., incorrect ICD Q20–Q28 anchoring, inoperative `COD_IDADE` fallback, CID
normalization), with documented impact on results (22 → 28 recovered SINASC
cases).
3. **Documentation** — `README.md`, `docs/AUDITORIA.md` and
`docs/METODOLOGIA.md`.
4. **Preparation of tables, figures and supporting text** in the exploratory
analysis.

### Limits and responsibilities

1. **No data was generated by AI**; all data come from public sources (DATASUS
   and INMET) and were processed with open, verifiable code, without any use of
   GAI for fabrication, falsification or manipulation of data.
2. **No GAI-generated content was submitted as if it were of human authorship**
   (art. 9, I, "d"). All text and code produced with the tool were reviewed,
   validated and adjusted by the authors.
3. **Scientific interpretation, methodological decisions, validation and
   critical review** are the sole responsibility of the author and supervisor.
4. The authors are **fully responsible for the final content**, including any
   plagiarism or inaccuracies generated by the GAI, and all results were
   **reviewed and validated manually** before publication.

---

## CRediT — Contributor Roles Taxonomy

| Role | Letícia Maria Santos | Francielly da Silva Santos Moreira |
|------|:---:|:---:|
| Conceptualization | ✓ | ✓ |
| Data curation | ✓ | |
| Formal analysis | ✓ | |
| Funding acquisition | | |
| Investigation | ✓ | |
| Methodology | ✓ | ✓ |
| Project administration | | ✓ |
| Resources | ✓ | |
| Software | ✓ | |
| Supervision | | ✓ |
| Validation | ✓ | ✓ |
| Visualization | ✓ | |
| Writing – original draft | ✓ | |
| Writing – review & editing | ✓ | ✓ |

---

## Data sources

- **SINASC / SIH-RD** — DATASUS (Brazilian Ministry of Health), via
  [`microdatasus`](https://github.com/rfsaldanha/microdatasus).
- **INMET** — Station A607 (Campos dos Goytacazes), hourly weather data
  2020–2024.

---

## How to cite

```bibtex
@misc{santos_cardiopathies,
  author       = {Santos, Letícia Maria},
  title        = {Congenital and Acquired Heart Diseases},
  year         = {2026},
  note         = {Supervisor: Francielly da Silva Santos Moreira. Undergraduate thesis},
  howpublished = {\url{https://github.com/leticiamariasantos/congenital-and-acquired-heart-diseases}}
}
```

---

## License

Licensed under the **MIT License** — see [LICENSE](LICENSE).
