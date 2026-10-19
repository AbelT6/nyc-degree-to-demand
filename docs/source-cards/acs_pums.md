# Source card: ACS PUMS 2020–2024 (5-year), New York persons

**Explored in:** `notebooks/10-profile-acs-pums.ipynb` · Verdict: use for outcomes of NYC residents by degree level and bachelor's field; no major for associate's holders, small-cell MOEs

## 1. What it is
- **Publisher / dataset:** U.S. Census Bureau, American Community Survey, *2020–2024 5-year Public Use Microdata Sample*, person file for New York (`psam_p36`)
- **Files:** `outcomes/acs_pums/csv_pny_2020-2024_5yr.zip`, `PUMS_Data_Dictionary_2020-2024.csv`, `2024_ACS_Code_Lists.xlsx` (field of degree), `2018-occupation-code-list-and-crosswalk.xlsx` (OCCP → SOC), `2020_Census_Tract_to_2020_PUMA.txt` (defines NYC). Tie-out: `outcomes/acs_summary_tables/acsdt5y2024-b01003.dat`, `-b15003.dat`, `-b15012.dat` (published tables, downloaded 2026-10-13 UTC)
- **Retrieved:** 2026-10-12 · Period: 2020–2024 pooled (README 2026-03-05)
- **How it was collected:** survey. PUMS is an anonymized subsample of ACS responses; non-answers are imputed and flagged
- **Covers / missing:** everyone living in NY State, including group quarters. Smallest area = PUMA (≥ 100k people). No field of degree below a bachelor's. NJ/CT residents who work in NYC are in other state files
- **License / terms:** public domain
- **Documentation:** [PUMS documentation](https://www.census.gov/programs-surveys/acs/microdata/documentation.html) (User Guide, Accuracy of the Data); data dictionary in the folder

## 2. Shape
- **Rows × columns:** 984,474 × 285 (127 variables + 78 allocation flags + 80 replicate weights) for NY State; 326,729 NYC residents
- **One row =** one person. Key `SERIALNO + SPORDER` unique . Year = `SERIALNO[:4]`
- **Codes used:** Census occupation 2018 (`OCCP`) + SOC-style `SOCP` (incl. Census groups with `X`/`Y`); Census industry 2022 (`INDP`) + `NAICSP`; ACS field of degree (`FOD1P`, 174 codes in NYC); 2020 PUMAs
- **Time span:** one pooled 5-year period. Weights add up to the period-average population (8.48M for NYC)
- **NYC slice:** home `PUMA` in the 55 NYC PUMAs (Bronx 042xx, Brooklyn 043xx, Manhattan 041xx, Queens 044xx, Staten Island 045xx). Place of work in NYC = `POWSP 036` + `POWPUMA 04100–04500`

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `PWGTP`, `PWGTP1–80` | Person weight; replicate weights | int | MOE: SE = √(4/80 · Σ(rep − est)²); 90% MOE = 1.645 · SE |
| `AGEP` | Age | int | Top-coded |
| `SCHL` | Highest education | code | `20` associate's, `21` bachelor's, `22–24` graduate |
| `SCHG` | Grade now attending | code | Blank = not in school |
| `FOD1P`, `FOD2P` | Bachelor's field of degree (1st, 2nd) | code | Only for `SCHL ≥ 21`; 25% imputed |
| `ESR` | Employment status | code | `1`/`2` civilian employed, `3` unemployed, `6` not in labor force |
| `OCCP`, `SOCP` | Job | code | 38% of workers on a group code; 24% imputed |
| `NAICSP` | Industry | code | First 2 chars = NAICS sector; `3M`, `4M` Census groups |
| `WAGP`, `PERNP` | Wages; total earnings, last 12 months | int | × `ADJINC`/1e6 → 2024 dollars; 34% of wages imputed |
| `WKHP`, `WKWN` | Usual hours / weeks worked | int | Full-time year-round = 35+ h and 50+ weeks |
| `F…P` | "Imputed" flag per variable | 0/1 | Keep for FOD, OCC, wages |

## 4. What it answers
- **Answers:** Q2 what NYC bachelor's holders with each field do (job, industry); Q4 what young grads earn by degree level and big fields; S11 underemployment (young bachelor's in jobs needing less); O1 share of each job's workers aged 22–29; D2 check of major → job links (bachelor's only)
- **Can't answer / limits:** no major for associate's holders; no year-by-year trend from a 5-year file; small fields are noisy; residents only; imputed answers

## 5. Tie-out
- **Population** vs published B01003: −0.03% to −0.07% by borough; NYC 8,480,225 vs 8,483,844 
- **Bachelor's+, 25+** vs B15003: NYC +0.08% (boroughs −0.40% to +0.75%) ; associate's, 25+ NYC +0.29% 
- B15012 counts fields of degrees reported (2,772,579), between first majors (2,535,587) and first + second (2,847,345); not a clean tie
- Sanity: 38.8% of employed NYC bachelor's holders aged 22–27 are in jobs whose BLS entry is below a bachelor's (NY Fed national recent-grad figure ≈ 41%)

## 6. Issues list
| # | Issue | Rows affected | Proposed treatment |
|---|---|---|---|
| 1 | No field of degree below a bachelor's | associate's holders | Outcomes by degree level only |
| 2 | No public FOD → CIP crosswalk | bachelor's+ | Hand-built `ref_fod_cip` (brief O5), needs a decision |
| 3 | `SOCP` group codes | 37.6% of workers | `ref_socp_soc` with 4-step rule (exact → one-level group → BLS parent → biggest OEWS job) |
| 4 | Heavy imputation | ~¼ | Keep flags; D2 sensitivity without imputed rows |
| 5 | Small cells | fields < 30 rows | MOE on every estimate; group small fields up |
| 6 | Pooled period | all | One "2020–2024" period |
| 7 | Nominal dollars | pay | × `ADJINC` |
| 8 | Residents only | workforce | Label "NYC residents" |
| 9 | `NAICSP` Census groups | < 1% | Map by first 2 chars |
| 10 | Still-enrolled grads | 41% assoc. / 23% bach. (22–27) | `enrolled` flag; outcomes on those not in school |
| 11 | 2020 collection disrupted | 2020 rows | Footnote |

## 7. Proposed staging table
- **Name:** `stg_census__acs_pums_person`
- **Grain / key:** `(serialno, sporder)`; NYC residents aged 16+, 2020–2024 pooled
- **Columns kept:** ids, `response_year`, `puma`, `borough`, `is_group_quarters`, `age`, `sex`, `education_code`, `degree_level`, `enrolled`, `fod1`, `fod2`, `employment_status`, `class_of_worker`, `occp`, `socp`, `naicsp`, `wage_2024usd`, `earnings_2024usd`, `usual_hours`, `weeks_worked`, `works_in_nyc`, imputed flags (FOD, OCC, wage), `weight`, 80 replicate weights
- **Filters:** NY State 984,474 rows → NYC residents 326,729 → age 16+ 279,311 (of which 14,073 are 22–27 with an associate's or bachelor's)
