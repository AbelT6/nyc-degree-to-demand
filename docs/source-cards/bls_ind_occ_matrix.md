# Source card: BLS National Employment Matrix (industry × job)

**Explored in:** `notebooks/09-profile-industry-job-bridge.ipynb` (Part A, Part C) · Verdict: use with limits: 2035 shares and self-employment only. The NY research estimates are the main bridge

## 1. What it is
- **Publisher / dataset:** U.S. Bureau of Labor Statistics, Employment Projections, *National Employment Matrix*, 2025–35
- **Files:** `jobs/bls_ind_occ_matrix/matrix_2026-10-12.xlsx` (sheet `Matrix`)
- **Retrieved:** 2026-10-12 · Edition: 2025 base, 2035 projected (same as `education.xlsx`, `occupation.xlsx`)
- **How it was collected:** model / compilation: national OEWS staffing patterns, CES and other industry totals, CPS for self-employed, then projected by BLS economists
- **Covers / missing:** all US jobs including self-employed. United States only
- **License / terms:** public domain
- **Documentation:** [EP occupational data](https://www.bls.gov/emp/data/occupational-data.htm), [EP methods](https://www.bls.gov/emp/documentation/projections-methods.htm)

## 2. Shape
- **Rows × columns:** 113,898 × 14
- **One row =** industry × job. Key `Occupation code + Industry code` unique . Only cells with jobs are listed
- **Codes used:** BLS EP industry codes (NAICS-based, 68 of 423 with letters or dashes: `TE1000`, `31-330`, ownership suffixes `P`/`S`/`L`/`Y`); SOC 2018 + 7 BLS aggregates
- **Time span:** 2025 and 2035
- **NYC slice:** none (national)

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `Industry code`, `Industry type` | Industry and `Line item` / `Summary` | text | Line items don't add up to sectors |
| `Occupation code`, `Occupation type` | Job and `Line item` / `Summary` | text | |
| `2025 Employment`, `2035 Employment` | Jobs, thousands | float | |
| `2025/2035 Percent of Industry` | Staffing share | float | |
| `2025/2035 Percent of Occupation` | Industry share of a job | float | |

## 4. What it answers
- **Answers:** how the job mix inside an industry is expected to shift by 2035 (national trend); self-employed jobs by occupation
- **Can't answer / limits:** NYC's current job mix inside an industry: it rebuilds NYC's job mix much worse than the NY research estimates (dissimilarity 23.0 vs 13.9)

## 5. Tie-out
- Total-all-industries column vs EP Table 1.2: 1,112 of 1,112 codes exact, 170,280.8k jobs in 2025

## 6. Issues list
| # | Issue | Rows affected | Proposed treatment (decided in staging) |
|---|---|---|---|
| 1 | Line-item industries cover 49–100% of their sector | industry line items | Use sector rows |
| 2 | Postal Service outside the `48-490` row | `491000` | Treat as its own sector |
| 3 | Public schools/hospitals inside `610000`/`620000`; government rows exclude them | 61, 62, 999xxx | Same filing as the NY research file |
| 4 | Industry codes with letters and dashes | 68 industries | Own code column + `naics_sector` map |
| 5 | 7 BLS aggregate job codes | 7 jobs | Job dimension keeps them (nb 06) |
| 6 | National, not NYC | all | Use only as "national trend" |

## 7. Proposed staging table
- **Name:** `stg_bls__ind_occ_matrix`
- **Grain / key:** `(industry_code, occ_code)`
- **Columns:** `industry_code`, `industry_title`, `industry_type`, `occ_code`, `occ_title`, `occ_type`, `emp_2025`, `pct_of_industry_2025`, `pct_of_occ_2025`, `emp_2035`, `pct_of_industry_2035`, `pct_of_occ_2035`, `naics_sector`
- **Filters:** none: 113,898 rows in → 113,898 out
