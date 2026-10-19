# Source card: BLS Job Openings and Labor Turnover Survey (JOLTS)

**Explored in:** profiled and loaded in `notebooks/34-load-bls-jolts-laus.ipynb` · Verdict: context only: state totals, no jobs or industries for NY

## 1. What it is
- **Publisher / dataset:** BLS JOLTS, bulk time-series files `bls_timeseries/bls_jt/jt-*` (snapshot 2026-10-12)
- **How it was collected:** employer survey (~21,000 establishments); state estimates are model-based
- **Covers:** openings, hires, quits, layoffs, other and total separations, unemployed per opening; U.S. and states, Dec 2000 → latest
- **License:** public domain (U.S. government)
- **Documentation:** `jt-txt` file in the download; bls.gov/jlt

## 2. Shape
- **One row =** series × year × period (M01–M12, M13)
- **Kept:** U.S. (00) and New York (36), total nonfarm, all size classes, SA and NSA, 2015+: 48 series, 6,793 rows

## 3. Key columns
| Column | Meaning | Notes |
|---|---|---|
| `value` | Level (thousands) or rate (%) | `ratelevel_code` L / R |
| `period_type` | `month`, `annual_avg`, `annual_total` | M13 is a 12-month total for hire/separation levels (BLS: "annual estimates ... for hires, quits, layoffs..."), an average for openings and rates |
| `footnote_code` | `P` preliminary, `9` not collected (Oct 2025 shutdown) | |

## 5. Tie-out
- 242 not-adjusted annual values vs their 12 months: totals = sum, averages = mean; max gap 0.5 thousand (rounding), 0.08 pt for rates

## 6. Issues list
| # | Issue | Treatment |
|---|---|---|
| 1 | Oct 2025 not collected | NULL, footnote `9` kept |
| 2 | M13 means total or average by series | `period_type` says which |
| 3 | NY has no industry detail | Industry hiring stays from QWI |

## 7. Staging table
- `stg_bls__jolts`: key `series_id + year + period`; labels for area, data element and rate/level joined in
