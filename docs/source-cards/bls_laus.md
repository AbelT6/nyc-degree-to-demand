# Source card: BLS Local Area Unemployment Statistics (LAUS)

**Explored in:** profiled and loaded in `notebooks/34-load-bls-jolts-laus.ipynb` · Verdict: context: NYC and borough labor force and unemployment

## 1. What it is
- **Publisher / dataset:** BLS LAUS, bulk files `bls_timeseries/bls_la/la-*` (New York data file; snapshot 2026-10-12)
- **How it was collected:** model estimates combining the household survey (CPS), payroll jobs (CES) and UI claims
- **Covers:** labor force, employment, unemployment, unemployment rate (+ population ratios for state and city), monthly since 1976
- **License:** public domain
- **Documentation:** `la-txt` file; bls.gov/lau

## 2. Shape
- **One row =** series × year × period
- **Kept:** New York State, New York City, its 5 counties, NY-NJ metro (35620), balance of state; 2015+: 58 series, 8,582 rows. Counties and metro are not seasonally adjusted; state, city and balance have both

## 5. Tie-out
- NYC (not adjusted) = sum of its 5 counties for labor force, employment and unemployment: 450 month × measure cells, max gap 3 people

## 6. Issues list
| # | Issue | Treatment |
|---|---|---|
| 1 | Oct 2025 not collected | NULL, footnote `X`; 2025 annual averages are 11-month (footnote `G`) |
| 2 | Annual revisions (benchmarking) each spring | Snapshot each run |

## 7. Staging table
- `stg_bls__laus`: key `series_id + year + period`; `area_type` (state / city / county / metro / balance), `county_fips` for the 5 boroughs, measure labels joined in
