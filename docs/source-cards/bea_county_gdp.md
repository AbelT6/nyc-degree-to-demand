# Source card: BEA GDP by county and industry

**Explored in:** `notebooks/07-profile-industry-jobs-output.ipynb` (Part C) · Verdict: use with limits (context panel; can wait until after v1)

## 1. What it is
- **Publisher / dataset:** U.S. Bureau of Economic Analysis, CAGDP2 (GDP, current dollars) and CAGDP9 (real GDP, chained 2017 dollars)
- **Files:** `jobs/bea_county_gdp/CAGDP2_2026-10-12.zip`, `CAGDP9_2026-10-12.zip` (member `CAGDPn_NY_2001_2024.csv`)
- **Retrieved:** 2026-10-12 · Release: Feb 5, 2026 (2024 new; 2020–2023 revised) · Period: 2001–2024
- **How it was collected:** model estimate: state GDP allocated to counties mostly with QCEW wages
- **Covers:** all industries, by county (each borough is a county); no NYC row
- **License / terms:** public domain
- **Documentation:** [BEA county GDP](https://www.bea.gov/data/gdp/gdp-county-metro-and-other-areas); footnotes inside each zip

## 2. Shape
- **Rows × columns:** 2,146 × 32 per table (NY file), incl. 4 footer rows
- **One row =** county × industry line, years wide (2001–2024). Key `GeoFIPS + LineCode` unique 
- **Codes used:** 34 BEA line codes over NAICS 2017: total, private, 20 sectors, 12 combinations/sub-lines
- **NYC slice:** FIPS 36005, 36047, 36061, 36081, 36085 (34 lines each)

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `GeoFIPS` | County | text | Padded and quoted: `' "36061"'` |
| `LineCode`, `IndustryClassification`, `Description` | Industry line | text | Combined lines double-count |
| `Unit` | Thousands of current $ / chained 2017 $ | text | |
| `2001` … `2024` | GDP | int | `(D)` = withheld (566 NYC cells per table) |

## 4. What it answers
- **Answers:** Q1 context: how big each industry's output is in each borough, and its trend
- **Can't answer / limits:** it's output, not jobs or hiring; a model; withheld cells in the Bronx (transportation all years) and Staten Island; chained dollars don't add across industries; revised every year

## 5. Tie-out
- NYC = ~59% of NY State GDP every year 2019–24. Manhattan sector lines add to the total exactly in 2022–24 (0.4% gap 2019–21 = withheld). Implied price index 105.0 → 124.9 (2019 → 2024), to cross-check with CPI (nb 12). GDP per covered QCEW job 2024: Manhattan ≈ $408k, other boroughs $158–186k

## 6. Issues list
| # | Issue | Rows affected | Proposed treatment |
|---|---|---|---|
| 12 | Years wide; quoted FIPS; footer rows | all | Unpivot; strip; drop footers |
| 13 | `(D)` withheld | 566 NYC cells per table | `NULL` + `is_withheld` |
| 14 | Combined lines double-count | 12 of 34 lines | Keep total, private, 20 sectors |
| 15 | Chained dollars non-additive | CAGDP9 | Trends of one line only |
| 16 | Revised yearly | 2020–2023 | `release` column |

## 7. Proposed staging table
- **Name:** `stg_bea__county_gdp`
- **Grain / key:** `(county_fips, line_code, year)`
- **Columns:** `county_fips`, `county_name`, `line_code`, `naics_label`, `line_title`, `year`, `gdp_current_thousands`, `gdp_real_chained2017_thousands`, `is_withheld`, `release`
- **Filters:** 5 boroughs × 22 lines × 2019–2024 = 660 rows (from 110 wide rows)
