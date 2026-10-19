# Source card: NYS DOL QCEW annual averages

**Explored in:** `notebooks/07-profile-industry-jobs-output.ipynb` (Part A) · Verdict: use (backbone of the "way in by industry", 2-digit sectors)

## 1. What it is
- **Publisher / dataset:** NYS Department of Labor with BLS, *Quarterly Census of Employment and Wages: Annual Data* (data.ny.gov `shc7-xcbw`)
- **Files:** `jobs/nysdol_qcew_annual/shc7-xcbw.csv`
- **Retrieved:** 2026-10-12 · Reference period: annual averages 2000–2025
- **How it was collected:** administrative records: every employer covered by unemployment insurance reports jobs and wages each quarter (~97% of wage and salary jobs)
- **Covers / missing:** covered wage and salary jobs. Missing: self-employed, most farm workers, armed forces, some religious-organization and railroad workers
- **License / terms:** NY Open Data
- **Documentation:** [dataset page](https://data.ny.gov/d/shc7-xcbw), [BLS QCEW overview](https://www.bls.gov/cew/overview.htm)

## 2. Shape
- **Rows × columns:** 1,163,386 × 10
- **One row =** area type × area × ownership × NAICS × year. Key unique only with `Area Type` (NYC is listed three times, identical)
- **Codes used:** NAICS 2, 3, 4 digit (`00` all industries, `99` unclassified; ranges written as first code: `31`, `44`, `48`)
- **Time span:** 2000–2025, annual
- **NYC slice:** `Area = 'New York City'` + `Area Type = 'Labor Market Area'`; boroughs = the five `County` rows. Boroughs add to NYC within ±3 jobs

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `Area Type`, `Area` | Geography | text | NYC appears as LMA, MSA and WIR |
| `Ownership` | Private, Federal/State/Local Government, 2 totals | text | Sector-level "Total, All Ownerships" rows mostly absent |
| `NAICS`, `NAICS Title` | Industry | text | Titles below the sector are partly pre-2022 |
| `Establishments` | Employer locations | int | No symbols |
| `Average Employment` | Annual average jobs | int | Suppressed cells = missing rows |
| `Total Wage` | Annual wages paid, $ | int | |
| `Annual Average Salary` | Wage ÷ employment | int | Column name padded with ~150 spaces; derivable |

## 4. What it answers
- **Answers:** Q1 which NYC industries are big and growing, by borough, 2019–2025; Q4 average pay by industry and borough; number of employers
- **Can't answer / limits:** no occupations (needs the BLS matrix, nb 09); pay is the average of all workers, not entry pay; 3/4-digit detail incomplete for retail and information from 2022 (NAICS 2022 codes dropped); ~6 months behind CES

## 5. Tie-out
- BLS QCEW open data, Manhattan 2024, private, all industries: jobs 2,240,692 · file 2,240,745 · +53 (0.002%). Wages +0.02%, establishments +490 (0.4%) 
- Internal: private sectors add to the private total within ±3 jobs; private + government = total within ±1

## 6. Issues list
| # | Issue | Rows affected | Proposed treatment |
|---|---|---|---|
| 1 | Padded column name | 1 column | Strip |
| 2 | NYC listed three times | 40,964 rows | Keep the Labor Market Area copy |
| 3 | Suppression = missing rows | 6–14 of 140 private sector × borough cells | `NULL`, never 0 |
| 4 | No sector-level "Total, All Ownerships" for most sectors | sector level | Use Private; build totals by adding ownerships |
| 5 | NAICS 2022 codes missing below the sector; stale titles | retail, information 2022–25 | v1 = 2-digit only; `naics_detail_complete` flag; BLS QCEW files if detail is needed |
| 6 | Range codes written as first code | 3 sectors | Map to `31-33`, `44-45`, `48-49` |
| 7 | Average salary is derived | all | Compute in core |

## 7. Proposed staging table
- **Name:** `stg_nysdol__qcew_annual`
- **Grain / key:** `(area_code, ownership, naics_code, year)`
- **Columns:** `area_code`, `area_name`, `ownership`, `naics_code`, `naics_level`, `naics_title`, `year`, `establishments`, `employment`, `total_wages`, `naics_detail_complete`, `source_file`
- **Filters:** NYC (LMA copy) + 5 boroughs, 2019–2025: 1,163,386 rows in → 24,114 out
