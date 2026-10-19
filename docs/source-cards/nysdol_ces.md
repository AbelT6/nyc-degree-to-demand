# Source card: NYS DOL Current Employment Statistics (CES), NYC

**Explored in:** `notebooks/07-profile-industry-jobs-output.ipynb` (Part B) · Verdict: use with limits (the "latest month" line only)

## 1. What it is
- **Publisher / dataset:** NYS Department of Labor with BLS, *Current Employment Statistics: Beginning 1990* (data.ny.gov `6k74-dgkb`)
- **Files:** `jobs/nysdol_ces/6k74-dgkb.csv`
- **Retrieved:** 2026-10-12 · Reference period: Jan 1990 → Aug 2026 (latest months preliminary)
- **How it was collected:** monthly employer payroll survey, benchmarked each year to QCEW-based totals
- **Covers / missing:** nonfarm wage and salary jobs (not people), not seasonally adjusted. No self-employed, no farms. No boroughs
- **License / terms:** NY Open Data
- **Documentation:** [dataset page](https://data.ny.gov/d/6k74-dgkb), [BLS State and Metro Area](https://www.bls.gov/sae/), [CES benchmark article](https://www.bls.gov/web/empsit/cesbmart.htm)

## 2. Shape
- **Rows × columns:** 498,400 × 7 (43 areas)
- **One row =** area × series × year × month. Key unique . `Month = 0` = annual average (= mean of the 12 months, 100% of checks)
- **Codes used:** CES 8-digit industry codes (supersector + NAICS-based detail), not plain NAICS
- **Time span:** monthly, 1990 → Aug 2026
- **NYC slice:** `Area = '93561'`, 105 series, all continuous from 2019

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `Area`, `Area Name` | Geography | text | NYC = `93561` |
| `Series`, `Title` | CES industry | text | `00000000` total nonfarm; supersectors `xx000000` |
| `Year`, `Month` | Period | int | Month 0 = annual average |
| `Current Employment` | Jobs | int | Rounded to the hundred |

## 4. What it answers
- **Answers:** Q1 how NYC jobs by industry moved in the latest months (~6 months ahead of QCEW)
- **Can't answer / limits:** no boroughs, no pay, supersectors ≠ NAICS sectors (Financial activities = 52 + 53), preliminary months get revised; level is not comparable to QCEW

## 5. Tie-out
- CES NYC total nonfarm vs QCEW NYC total, 2019–2025: CES +3.5% to +5.1% every year. Expected: CES includes jobs not covered by unemployment insurance. Supersector gaps +1.2% (leisure) to +6.5% (education & health)

## 6. Issues list
| # | Issue | Rows affected | Proposed treatment |
|---|---|---|---|
| 8 | Month 0 is the annual average | 1 per series-year | Store months 1–12; compute annual in core |
| 9 | Preliminary months; yearly benchmark revisions | current year | `vintage` column; re-download after each March benchmark |
| 10 | CES codes ≠ NAICS | 105 series | Hand map series → NAICS sector(s) |
| 11 | Level ≠ QCEW | all | Separate fact; never summed with QCEW |

## 7. Proposed staging table
- **Name:** `stg_nysdol__ces_monthly`
- **Grain / key:** `(series_code, year, month)`
- **Columns:** `series_code`, `series_title`, `supersector_code`, `year`, `month`, `employment`, `vintage`
- **Filters:** NYC, months 1–12, 2019 → latest: 498,400 rows in → 9,660 out
