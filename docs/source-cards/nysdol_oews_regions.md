# Source card: NYS DOL occupational wages by region (NYC)

**Explored in:** `notebooks/03-profile-oews-wages.ipynb` · Verdict: use (the only NYC-only entry wage)

## 1. What it is
- **Publisher / dataset:** NYS Department of Labor, *Occupational Wages* (data.ny.gov `gkgz-nw24`)
- **Files:** `jobs/nysdol_oews_regions/gkgz-nw24_2026-10-12.csv`
- **Retrieved:** 2026-10-12 · Vintage: OEWS panels Nov 2022 → May 2025, wages aged to Q1 2026. The portal overwrites it every year (last update ~2026-07-07)
- **How it was collected:** the OEWS employer survey, re-tabulated by NYS DOL for its 10 labor-market regions, then cost-of-living adjusted to Q1 2026
- **Covers:** wage and salary jobs. NYC region = Bronx, Kings, New York, Queens, Richmond counties (five boroughs). Self-employed not included
- **License / terms:** NY Open Data
- **Documentation:** [dataset page](https://data.ny.gov/d/gkgz-nw24) (definitions of entry/experienced wage, minimum-wage floor)

## 2. Shape
- **Rows × columns:** 7,036 × 10 (11 areas). NYC: 702 rows
- **One row =** area × job, one vintage. Key `Area + Standard Occupational Code` unique 
- **Codes used:** SOC 2018, plus the same OEWS aggregates as BLS. Levels: total, major, detailed (6 broad-level codes)
- **Time span:** a single vintage, no time dimension
- **NYC slice:** `Area Name = 'New York City'` (`Area = 7`)

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `Standard Occupational Code` | SOC 2018 | text | Column names have stray spaces (8 of 10) |
| `Employment` | Jobs | int | Blank = suppressed (117 NYC rows) |
| `Mean Wage`, `Median Wage` | Annual, Q1 2026 dollars | int | Floored at the minimum wage |
| `Entry Wage` | **Mean of the bottom third** of wages | int | 22 NYC jobs sit exactly on the $35,360 floor ($17/hr) |
| `Experienced Wage` | Mean of the top two thirds | int | Blank for 6 NYC jobs (e.g. Chief Executives) |

## 4. What it answers
- **Answers:** Q4 starting pay in NYC (entry wage), median and experienced pay; current NYC employment by job, which is also the weight for the D1 projection fill
- **Can't answer / limits:** no time series; no percentiles; boroughs not split; "entry" ≠ new-graduate wage (it's the bottom third of all workers); wages at the floor are the legal minimum, not a measurement

## 5. Tie-out
- NYC total 4,603,380 jobs, mean $95,518 · Same mean as the 2026 wage column in NYS DOL's 2022-32 projections workbook ($95,518.35) 
- Against BLS OEWS: 699 of 702 NYC codes exist in the 2025 metro file; NYC ≈ 46% of metro jobs (median per job), NYC medians ≈ 4% above metro (NYC premium + 9 months of aging, not separable)

## 6. Issues list
| # | Issue | Rows affected | Proposed treatment |
|---|---|---|---|
| 10 | Padded column names | 8 of 10 columns | Strip names |
| 11 | Blank employment / experienced wage | 117 / 6 NYC rows | `NULL`, not zero |
| 12 | Wages floored at the minimum wage | 22 NYC jobs (entry), 5 (median) | `entry_wage_at_floor`, `median_at_floor` flags |
| 13 | Aged to Q1 2026 (survey May 2025) | all | `wage_reference`, `survey_reference` columns |
| 14 | Overwritten yearly | all | `vintage` column; keep each downloaded vintage |

## 7. Proposed staging table
- **Name:** `stg_nysdol__occupation_wages`
- **Grain / key:** `(area_code, soc_code)`, NYC only for v1
- **Columns:** `vintage`, `wage_reference`, `area_code`, `area_name`, `soc_code`, `soc_title`, `soc_level`, `employment`, `mean_wage`, `median_wage`, `entry_wage`, `experienced_wage`, `entry_wage_at_floor`, `median_at_floor`, `source_file`
- **Filters:** `Area Name = 'New York City'`; 7,036 rows in → 702 out
