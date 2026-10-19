# Source card: BLS OEWS, New York metro area (2018–2025)

**Explored in:** `notebooks/03-profile-oews-wages.ipynb` · Verdict: use with limits (metro ≠ NYC; three code systems; top-coding stops in 2025)

## 1. What it is
- **Publisher / dataset:** U.S. Bureau of Labor Statistics, *Occupational Employment and Wage Statistics* (OEWS), May estimates, metropolitan areas
- **Files:** `jobs/bls_oews_metro/oesm18ma.zip` … `oesm25ma.zip` (8 files); the `MSA_MYYYY_dl.xlsx` workbook inside each
- **Retrieved:** 2026-10-12 · Editions: May 2018 – May 2025, annual
- **How it was collected:** employer survey. Each May estimate pools six semiannual panels over 3 years (May 2025 = Nov 2022 → May 2025), so it's a smoothed series ([technical notes](https://www.bls.gov/oes/2025/may/oes_tec.htm))
- **Covers:** wage and salary jobs by employer location. Excludes the self-employed. Area = metro 35620 (NYC + Long Island, lower Hudson Valley, northern NJ; Pike County PA until 2023)
- **License / terms:** U.S. government work, public domain
- **Documentation:** *Field Descriptions* sheet in each workbook (symbols, field meanings); technical notes above

## 2. Shape
- **Rows × columns:** ~140–150k rows per workbook (all metros) × 25–32 columns. NY metro: 756–804 rows per year, 6,281 over 8 years
- **One row =** year × job, cross-industry, all ownerships. Key `year + OCC_CODE` unique 
- **Codes used:** SOC 2010 (2018), BLS hybrid SOC (2019–2020), SOC 2018 (2021–2025). Levels: total, major, detailed only
- **Time span:** 2018–2025, annual (May reference)
- **NYC slice:** none. `AREA = 35620` is the closest; NYC is ~48% of its jobs

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `OCC_CODE`, `OCC_TITLE` | Job code and title | text | Code system changes in 2019 and 2021 |
| `O_GROUP` | Level: total / major / detailed | text | `OCC_GROUP` in 2018 |
| `TOT_EMP` | Employment, rounded to 10 | int | `**` = not available (16–29 jobs/year) |
| `A_MEAN`, `A_PCT10…A_PCT90` | Annual mean and percentile wages | int | `*` = not available; `#` = ≥ cap ($100/hr ≤ 2021, $115/hr 2022–24); no `#` in 2025 |
| `H_*` | Hourly equivalents | num | `*` for annual-only jobs (teachers, pilots) |
| `ANNUAL`, `HOURLY` | Only annual / only hourly wages released | bool | `TRUE` or blank |
| `EMP_PRSE`, `MEAN_PRSE` | Relative standard error, % | num | Redefined as model error in 2025 (sampling error before) |

## 4. What it answers
- **Answers:** Q4 pay over time (full percentile spread, 8 years); Q1 employment over time, at metro level
- **Can't answer / limits:** NYC-only figures; boroughs; self-employed workers; year-to-year shocks (3-year pooled sample); top-paid trends across 2024→2025; 2020–21 means are inflated by losing low-paid jobs (composition)

## 5. Tie-out
- Published: BLS *[Occupational Employment and Wages in New York-Newark-Jersey City, May 2025](https://www.bls.gov/regions/northeast/news-release/occupationalemploymentandwages_newyork.htm)*: mean hourly all jobs $41.50, computer & math $67.04, healthcare practitioners $62.24 · From the file: identical · Difference: 0 
- Internal: annual = hourly × 2,080 within $20; detailed jobs cover 98.9–99.8% of the total every year

## 6. Issues list
See notebook §9 for all 15 (shared with the NYS DOL wage table). The ones that decide design:

| # | Issue | Rows affected | Proposed treatment |
|---|---|---|---|
| 1 | Layout changes by year | all | Per-year rename map; assert final column set |
| 4 | `**` / `*` / `#` symbols in numeric columns | every year | `NULL` + `is_top_coded` flag + cap value |
| 5 | Top-coding stops in 2025, not documented | 68 jobs ≥ $239,200 in 2025 | Keep values; mark the series break; footnote high-wage trends |
| 6 | SOC 2010 / hybrid / SOC 2018 | 2018–2020 | Original code + `soc_edition`; bridge in core (nb 06), shared with projections |
| 8 | Metro ≠ NYC | all | Label "New York metro area", never NYC |

## 7. Proposed staging table
- **Name:** `stg_bls__oews_metro_occupations`
- **Grain / key:** `(year, occ_code)`, NY metro, cross-industry
- **Columns:** `year`, `area_code`, `area_title`, `occ_code`, `occ_title`, `soc_edition`, `occ_level`, `employment`, `employment_rse_pct`, `jobs_per_1000`, `location_quotient`, `hourly_mean`, `annual_mean`, `mean_rse_pct`, `hourly_p10…p90`, `annual_p10…p90`, `annual_only`, `hourly_only`, `is_top_coded`, `source_file`
- **Filters:** `AREA = 35620` in each `MSA_` workbook → 6,281 rows (8 years)
