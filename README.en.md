# Congenital and Acquired Heart Diseases

Analysis of **congenital heart diseases (ICD-10 Q20–Q28)** among live births and
hospital admissions of infants under one year old, residents of
**Campos dos Goytacazes (RJ, Brazil)**, from **2020 to 2024**.

Project developed as part of an undergraduate thesis (TCC).

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

## Repository structure

```
analysis/    # Analysis scripts (figures and tables)
data/        # raw/ (INMET), processed/ (final .rds), cache/ (not versioned)
docs/        # AUDITORIA.md (audit report) and METODOLOGIA.md (methods)
results/     # auditoria/, figures/ and final CSVs
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

## Main results

| Year | Live births Q20–Q28 (SINASC) | Admissions Q20–Q28 < 1 yr (SIH-RD) |
|------|------------------------------|-------------------------------------|
| 2020 | 5 | 7 |
| 2021 | 4 | 12 |
| 2022 | 6 | 16 |
| 2023 | 7 | 10 |
| 2024 | 6 | 10 |
| **Total** | **28** | **55** |

- Age group of admissions: **11 neonates** (0–28 days) and **44 infants**
  (29–364 days).
- See [`docs/METODOLOGIA.md`](docs/METODOLOGIA.md) for methods and thresholds
  and [`docs/AUDITORIA.md`](docs/AUDITORIA.md) for the full code audit report.

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
  howpublished = {\url{https://github.com/leticiamariasantos/congenital-and-acquired-heart-diseases}},
  note         = {Undergraduate thesis}
}
```

---

## License

Licensed under the **MIT License** — see [LICENSE](LICENSE).
