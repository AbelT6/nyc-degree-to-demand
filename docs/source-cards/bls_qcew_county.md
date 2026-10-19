# Source card: BLS QCEW county files (NYC boroughs)

**Explored in:** `notebooks/09-profile-industry-job-bridge.ipynb` (Part C) · Verdict: use for government jobs by sector; NYS DOL QCEW (nb 07) stays the main industry source

## 1. What it is
- **Publisher / dataset:** U.S. Bureau of Labor Statistics, *Quarterly Census of Employment and Wages*, open data area slices (annual averages)
- **Files:** `jobs/bls_qcew_county/{year}_a_{fips}.csv`, 2019–2025 × the five borough FIPS (35 files)
- **Retrieved:** 2026-10-12 · Reference period: annual averages 2019–2025
- **How it was collected:** administrative records (UI employer reports); same source as NYS DOL's QCEW
- **Covers / missing:** UI-covered wage and salary jobs. Missing: self-employed, most farm workers, armed forces
- **License / terms:** public domain
- **Documentation:** [QCEW open data](https://www.bls.gov/cew/additional-resources/open-data/), [CSV layout](https://www.bls.gov/cew/about-data/downloadable-file-layouts/annual/naics-based-annual-layout.htm)

## 2. Shape
- **Rows × columns:** 63,485 × 38
- **One row =** county × year × ownership × industry (any level). Key `area_fips + year + own_code + industry_code` unique ; `size_code` always 0, `qtr` always `A`
- **Codes used:** NAICS ranges (`31-33`); `own_code` 0 total, 1 federal, 2 state, 3 local, 5 private; `agglvl_code` 71 = county × ownership, 74 = × sector
- **NYC slice:** the five files per year; add counties for NYC

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `own_code`, `industry_code`, `agglvl_code` | Ownership, NAICS, aggregation level | text | |
| `annual_avg_emplvl` | Jobs | int | 0 when suppressed |
| `disclosure_code` | `N` = not disclosed | text | 36% of rows (mostly detailed private industries) |
| `annual_avg_estabs`, `total_annual_wages`, `avg_annual_pay` | Establishments, wages | int | |

## 4. What it answers
- **Answers:** NYC government jobs by sector (local public schools 142k, public hospitals 36k published in 2024), needed to apply staffing patterns correctly
- **Can't answer / limits:** 129k NYC local government jobs (2024) sit in suppressed borough × sector cells (transit, Queens and Staten Island schools and health)

## 5. Tie-out
- vs NYS DOL NYC QCEW 2024: federal 0, state 0, local +2, private +608 (0.015%). 2019 and 2025 are just as close

## 6. Issues list
| # | Issue | Rows affected | Proposed treatment (decided in staging) |
|---|---|---|---|
| 1 | Suppressed cells show 0 jobs | `disclosure_code = N` | `NULL` + `disclosed = false` |
| 2 | Local government transit suppressed in 3 boroughs | 48-49 local | Fill from NYS DOL NYC-level (55,174 in 2024) |
| 3 | 77k local jobs still unplaced (2024) | Queens/SI 61, 62 etc. | "Unplaced government" bucket; the bridge test shows it barely matters |

## 7. Proposed staging table
- **Name:** `stg_bls__qcew_county`
- **Grain / key:** `(county_fips, year, own_code, industry_code)`
- **Columns:** `county_fips`, `year`, `own_code`, `industry_code`, `agglvl_code`, `estabs`, `emp`, `total_wages`, `avg_annual_pay`, `disclosed`
- **Filters:** `agglvl_code` in (71, 74): 63,485 rows in → 1,365 out
