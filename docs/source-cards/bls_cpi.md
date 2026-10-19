# Source card: BLS CPI-U, New York-Newark-Jersey City

**Explored in:** `notebooks/12-profile-cpi.ipynb` · Verdict: use to show pay over time in 2025 dollars; metro area, not NYC; October 2025 missing

## 1. What it is
- **Publisher / dataset:** U.S. Bureau of Labor Statistics, *Consumer Price Index for All Urban Consumers (CPI-U)*, flat files `download.bls.gov/pub/time.series/cu/`
- **Files:** `bls_timeseries/bls_cu/cu-data-1-AllItems_2026-10-12.txt` + `cu-series`, `cu-area`, `cu-item`, `cu-period`, `cu-footnote`, `cu-txt` (same date)
- **Retrieved:** 2026-10-12 · Latest month: August 2026
- **How it was collected:** survey of prices for a fixed basket, monthly, in 75 urban areas
- **Covers / missing:** NY-Newark-Jersey City metro (NY, NJ, PA parts). No NYC-only or borough index. October 2025 not collected (federal shutdown)
- **License / terms:** public domain
- **Documentation:** [CPI handbook of methods](https://www.bls.gov/opub/hom/cpi/), `cu-txt` readme

## 2. Shape
- **Rows × columns:** 64,007 × 5 (201 series, 58 areas)
- **One row =** series × period. Key `series_id + year + period` unique 
- **Codes used:** area `S12A` (NY metro), `0000` (U.S.); item `SA0` all items; periods `M01–M12`, `M13` annual average, `S01–S03` halves
- **Time span:** NY monthly 1914 → Aug 2026
- **NYC slice:** `CUURS12ASA0` (monthly, not seasonally adjusted, 1982–84 = 100)

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `series_id` | `CU` + `U` (not SA) + `R` (monthly) + area + item | text | Padded with spaces |
| `year`, `period` | Reference period | int, text | `M13` = annual average |
| `value` | Index, 1982–84 = 100 | text → decimal | `-` for October 2025 |
| `footnote_codes` | `X` = not collected (2025 shutdown), `R` = revised | text | Only `X` used here |

## 4. What it answers
- **Answers:** Q4 pay over time in constant (2025) dollars; brief O4's "OEWS medians adjusted with CPI".
- **Can't answer / limits:** NYC-specific or student-specific cost of living (rent); anything below the metro area.

## 5. Tie-out
- Published annual averages (`M13`) = mean of the 12 months for 2018–2024 (diff ≤ 0.001) and = the half-yearly series' `S03` 
- 2025 annual average 345.511 = mean of the 11 collected months (BLS left October out) 
- NY prices 2019 → 2025: +24.2% (U.S. +25.9%)

## 6. Issues list
| # | Issue | Rows affected | Proposed treatment (decided in staging) |
|---|---|---|---|
| 1 | October 2025 missing | 1 per series | NULL + footnote; no interpolation |
| 2 | Padded text values | all | Strip, cast numeric |
| 3 | Annual average stored as period `M13` | 1 per year | `period_type` column |
| 4 | Metro, not NYC | all | Label "NY metro area prices" |
| 5 | Self-overwriting file | latest months | Dated snapshots; refresh each January |

## 7. Proposed staging table
- **Name:** `stg_bls__cpi`
- **Grain / key:** `(series_id, year, period)`
- **Columns:** `series_id`, `area_code`, `area_name`, `year`, `period`, `period_type` (`month`/`annual_avg`), `month`, `index_value` numeric(8,3), `footnote_code`
- **Filters:** `CUURS12ASA0` + `CUUR0000SA0`, years ≥ 2015 → 302 rows. Deflator to the base year built in core from annual averages.
