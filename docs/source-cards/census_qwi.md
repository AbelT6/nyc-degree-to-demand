# Source card: Census QWI (Quarterly Workforce Indicators), New York

**Explored in:** `notebooks/08-profile-qwi-hiring.ipynb` · Verdict: use (hiring by industry, borough and age); the education split is weak

## 1. What it is
- **Publisher / dataset:** U.S. Census Bureau, LEHD, *Quarterly Workforce Indicators*, release R2026Q3 (schema V4.14.0)
- **Files:** `hiring/census_qwi/qwi_ny_sa_f_gc_ns_op_u.csv.gz` (sex × age), `qwi_ny_se_f_gc_ns_op_u.csv.gz` (sex × education), plus `version_qwi.txt`, `qwi_ny.md5sum`
- **Retrieved:** 2026-10-12 · Period: 2000Q1 → 2025Q4 (latest quarter lacks stable-job measures)
- **How it was collected:** linked administrative records: UI wage records + QCEW + Census demographics. Education imputed, only for ages 25+. Every value noise-infused; small cells suppressed
- **Covers / missing:** private UI-covered jobs (`op` = private only in these files); no self-employed, no government
- **License / terms:** public domain
- **Documentation:** [LEHD schema](https://lehd.ces.census.gov/data/schema/latest/lehd_public_use_schema.html), `label_flags.csv`, `label_education.csv`, `variables_qwi.csv` in the same schema folder

## 2. Shape
- **Rows × columns:** 3.55M (age) + 2.37M (education) × 81 for NY State; 283,041 + 188,694 borough rows
- **One row =** county × industry × sex × age (or education) × quarter. Key unique . Age and education are never crossed
- **Codes used:** NAICS sectors written as ranges (`31-33`, `44-45`, `48-49`) + `00` all industries; LEHD age `A00–A08`, education `E0–E5`
- **NYC slice:** `geography` ∈ 36005, 36047, 36061, 36081, 36085

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `geography` | County FIPS | text | |
| `industry` | NAICS sector | text | Ranges, not first codes |
| `agegrp` / `education` | Worker group | text | `A03` = 22–24, `A04` = 25–34; `E3` = some college or associate, `E4` = bachelor's or more, `E5` = age ≤ 24 (no education) |
| `Emp`, `EmpS` | Jobs at start of quarter; stable (full-quarter) jobs | int | |
| `HirA`, `HirN`, `Sep` | All hires, new hires (no recalls), separations | int | `Sep` blank in the latest quarter |
| `EarnS`, `EarnHirNS` | Avg monthly earnings: stable jobs; stable new hires | int | 86–89% released |
| `s<Var>` | Status flag per indicator | int | 1 OK, 5 suppressed, -1 not computable, 9 distorted… |

## 4. What it answers
- **Answers:** Q1 which industries hire the most in each borough, and how many hires are aged 22–24 / 25–34; Q4 what stable new hires earn by industry
- **Can't answer / limits:** no occupations; no associate-only or bachelor's-only split; education only for 25+ and imputed; not seasonally adjusted; noise-infused

## 5. Tie-out
- QWI NYC private jobs vs QCEW NYC private jobs, 2019–2024: QWI +2.6% to +5.6% (steady 3–4% except 2020). Different counting rules, same UI system
- Internal: age groups, education groups and sectors add to their totals exactly; the two files' totals are identical (100% of 31,449 cells)
- NYC 2024 new hires: 2.23M; avg monthly earnings $5,621 (`E3`), $8,209 (`E4`), $2,968 (`E5`, age ≤ 24)

## 6. Issues list
| # | Issue | Rows affected | Proposed treatment |
|---|---|---|---|
| 1 | Status flags per indicator | all | Value kept only for released flags; flag column kept |
| 2 | Latest quarter incomplete | 2025Q4 | `quarter_complete = false` |
| 3 | Age and education in separate files | both | Stack with a `breakdown` column; totals once |
| 4 | Education imputed, 25+, coarse groups | education file | Label exactly; never call `E3` "associate's" |
| 5 | Not seasonally adjusted | all | Year-over-year or 4-quarter sums |
| 6 | Noise-infused | all | Footnote on every visual |
| 7 | Level ≠ QCEW | all | Separate fact |
| 8 | NAICS ranges vs QCEW first codes | industry | Both spellings in the industry dimension |
| 9 | Sex breakdown not needed | 2/3 of rows | Keep `sex = 0` |

## 7. Proposed staging table
- **Name:** `stg_census__qwi`
- **Grain / key:** `(county_fips, naics_sector, breakdown, group_code, year, quarter)`, private, both sexes
- **Columns:** `county_fips`, `naics_sector`, `breakdown`, `group_code`, `year`, `quarter`, `emp_begin`, `emp_stable`, `hires_all`, `hires_new`, `separations`, `earn_stable_monthly`, `earn_new_hire_stable_monthly`, `job_creation`, flag columns, `release`
- **Filters:** 5 boroughs, `sex = 0`, 2019Q1 → 2025Q4: 471,735 borough rows in → 39,648 out
