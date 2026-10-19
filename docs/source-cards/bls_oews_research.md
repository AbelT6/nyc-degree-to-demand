# Source card: BLS OEWS research estimates by state and industry (New York)

**Explored in:** `notebooks/09-profile-industry-job-bridge.ipynb` (Parts B–D) · Verdict: use as the industry → job bridge (sector level, latest year), labeled "research estimates"

## 1. What it is
- **Publisher / dataset:** U.S. Bureau of Labor Statistics, OEWS, *Research Estimates by State and Industry*
- **Files:** `jobs/bls_oews_research/oes_research_{2019…2025}_allsectors.xlsx` (all states; we keep New York, area `36`)
- **Retrieved:** 2026-10-12 · Reference period: May 2019 → May 2025 (May 2025 posted 2026-05-15). Each year pools three years of survey panels
- **How it was collected:** the OEWS employer survey, tabulated by state × industry. BLS: "for research purposes", higher model error, fewer jobs published, and none of the extra quality checks of the official tables
- **Covers / missing:** wage and salary jobs, private and government. No self-employed. State level only, no NYC
- **License / terms:** public domain
- **Documentation:** [research estimates](https://www.bls.gov/oes/oessrcres.htm), [May 2025 page](https://www.bls.gov/oes/oes_research_2025.htm), `field descriptions` sheet in each file

## 2. Shape
- **Rows × columns:** 816k–868k × 26–29 per year (all states); 28,274–30,244 NY rows a year, 204,386 for 2019–2025
- **One row =** industry (at one NAICS level) × job. Key `naics + i_group + occ_code` unique (`naics + occ_code` alone is not: a 3-digit industry with one 4-digit child is listed twice)
- **Codes used:** NAICS sector → 6 digit (NAICS 2017 in 2019–21, 2022 from 2022); SOC detailed + major groups (hybrid SOC in 2019–20, SOC 2018 from 2021)
- **Time span:** annual, May 2019 → May 2025
- **NY slice:** `area = 36`. Sector `99` = government excluding state/local schools and hospitals and the Postal Service; those sit in 61, 62 and 48-49

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `naics`, `i_group` | Industry code and level (`sector`, `3-digit` … `6-digit`) | text | Sectors as ranges (`31-33`) |
| `occ_code`, `o_group` | Job code and level (`detailed`, `major`, `total`) | text | 2019 header is `occ code` |
| `tot_emp` | Jobs | int | `**` = not published |
| `pct_total` | Share of the industry's jobs | float | `~` = under 0.05% |
| `a_median`, `h_median`, `a_mean` | Annual / hourly wages | float | `#` = top-coded, `*` = not published |
| `emp_prse`, `mean_prse` | Relative standard errors | float | |

## 4. What it answers
- **Answers:** S4 "way in by industry": the jobs inside an industry (staffing pattern), applied to NYC's own industry jobs (QCEW). Wages by industry × job at state level
- **Can't answer / limits:** no NYC geography; no projections; no self-employed; research quality only; small sectors (agriculture, mining) are noisy and only 79–81% published

## 5. Tie-out
- **Test:** NYC 2024 sector jobs × NY staffing pattern vs NYC measured job counts (NYS DOL, nb 03). Dissimilarity 13.9 (May 2025) vs 23.0 for the national matrix; 17.7 → 15.2 for May 2021 → 2024. Not fully independent: NYC is a large part of the NY sample, and NYS DOL's NYC counts come from the same survey cycle
- Published detailed jobs cover 97–98% of each sector's jobs (median)

## 6. Issues list
| # | Issue | Rows affected | Proposed treatment (decided in staging) |
|---|---|---|---|
| 1 | Headers, column order, sheet names change by year | all files | Normalise headers (lower-case, `_`), select by name |
| 2 | Same NAICS code at two levels | 450–514 rows a year | Key includes `i_group`; bridge uses sectors |
| 3 | Hybrid SOC (2019–20); NAICS 2017 → 2022 | 2019–21 | Bridge uses 2021+; keep vintage columns |
| 4 | `**`, `~`, `#`, `*` symbols | ~2.5–3.6k a year each | `NULL` + flag columns |
| 5 | Detailed jobs cover 97–98% of a sector | sector rows | Renormalise within sector; keep covered % |
| 6 | Research estimates, not official | all | Label on every visual |
| 7 | Public schools/hospitals in 61/62, Postal in 48-49 | 61, 62, 48-49, 99 | Build NYC sector jobs the same way (BLS QCEW county) |
| 8 | Job mix moves 4–9 points a year in big sectors | all | Use the latest year; don't chart pattern changes as hiring shifts |

## 7. Proposed staging table
- **Name:** `stg_bls__oews_research_ny`
- **Grain / key:** `(year, naics, i_group, occ_code)`, New York State
- **Columns:** `year`, `naics`, `naics_title`, `i_group`, `occ_code`, `occ_title`, `o_group`, `tot_emp`, `emp_prse`, `pct_total`, `h_median`, `a_median`, `a_mean`, `emp_suppressed`, `pct_lt_0_05`, `wage_topcoded`, `soc_vintage`, `naics_vintage`
- **Filters:** area `36`, 2019 → 2025: 5.9M rows in (all states) → 204,386 out
