# Source card: IPEDS Completions + Directory

**Explored in:** `notebooks/05-profile-ipeds-cuny-graduates.ipynb` · Verdict: use (the all-NYC graduates count; CIP 2010 before 2020, C2024 provisional)

## 1. What it is
- **Publisher / dataset:** U.S. Dept. of Education, NCES, Integrated Postsecondary Education Data System. Completions `C<YYYY>_A` (awards by college × major × level) and Institutional Characteristics directory `HD<YYYY>` (one row per college)
- **Files:** `graduates/ipeds_completions/C2015_A.zip` … `C2024_A.zip`, `graduates/ipeds_directory/HD2015.zip` … `HD2024.zip`, dictionary `graduates/ipeds_dictionary/C2024_A_Dict.zip`
- **Retrieved:** 2026-10-12 · Reference period: award year July 1 → June 30 (`C2024` = July 2023 – June 2024). 2015–2023 revised; 2024 provisional
- **How it was collected:** administrative census. Every college that takes federal student aid (Title IV) must report. Counts are awards, not people; each award is reported under up to two majors
- **Covers:** every Title IV college in the US. Missing: non-Title-IV schools; where graduates live or work afterwards
- **License / terms:** U.S. government work, public domain
- **Documentation:** [Completions survey](https://nces.ed.gov/ipeds/survey-components/7), [data files](https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx), `C2024_A_Dict.zip`

## 2. Shape
- **Rows × columns:** 2,990,729 completions rows (US, 2015–2024) × 64 columns (totals, men/women, race/ethnicity, each with an `X` imputation flag). HD ≈ 6–7k colleges a year
- **One row =** one college × one major (CIP) × first/second major × one award level, for one award year. Key `year + UNITID + CIPCODE + MAJORNUM + AWLEVEL` unique . HD key `year + UNITID` unique 
- **Codes used:** CIP 2010 in 2015–2019, CIP 2020 from 2020 (clean break). `CIPCODE = 99` is the grand total per college × level × major number. IPEDS award levels (`AWLEVEL`); associate's = 3, bachelor's = 5 in every year
- **Time span:** 10 award years, 2015–2024, annual
- **NYC slice:** college's county code (`COUNTYCD`) in the five boroughs, from each year's HD. 191 units in 2015 → 173 in 2024; 58,343 detailed completions rows. CUNY = system code `F1SYSCOD = 136010` (21 units every year, incl. the System Office)

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `UNITID` | College ID | text | Joins to HD on `year + UNITID` (100% match) |
| `CIPCODE` | Major | text `NN.NNNN` | `99` = grand total. Edition changes in 2020 |
| `MAJORNUM` | 1 = first major, 2 = second | text | Count awards on `1` only (~7% of rows are `2`) |
| `AWLEVEL` | Award level | text → int | Zero-padded through 2022, unpadded from 2023. Level 1 split into 20/21 from 2020 |
| `CTOTALT` / `CTOTALM` / `CTOTALW` | Awards total / men / women | int | No suppression; men + women = total in 100% of rows |
| `XCTOTALT` | Imputation flag | text | `R` reported; `P` carried forward, `C` corrected, `N` imputed, `Z` implied zero (1,862 in 2020) |
| HD `F1SYSCOD` / `F1SYSNAM` | System code / name | text | Name is space-padded from 2023; use the code |
| HD `COUNTYCD`, `SECTOR` | County FIPS, sector | text | NYC flag and public/private split |

## 4. What it answers
- **Answers:** Q3, graduates per major per year at every NYC college, CUNY highlighted. Headline: NYC associate's fell a third 2019 → 2024 (27,593 → 18,490), about four-fifths of it at CUNY (18,880 → 11,402). CUNY awards 59–69% of NYC associate's and 43–49% of bachelor's. With the CIP→SOC crosswalk, 97.1% of 2024 NYC associate + bachelor's awards (73,225) link to at least one job
- **Can't answer / limits:** awards ≠ people (double majors, people with several awards); where graduates end up working (ACS PUMS, nb 08); students' home borough; the most recent year (CUNY Programs is one year ahead); general/"other" majors (`51.0000`, `30.0000`, `…99`) have no direct job

## 5. Tie-out
- CUNY *Degrees Granted by Type* (`ybg5-afvs`) vs IPEDS CUNY first majors, 2019–2024: exact every year except 2020 associate's (CUNY 18,499 vs IPEDS 18,498, ±1). 2024: 11,402 associate's / 23,437 bachelor's both sides. The CUNY file is IPEDS republished, so this confirms the CUNY filter and first-major rule, not an independent count
- Internal: every `99` grand-total row equals the sum of its detailed rows (206,538 checked, 100%) 
- Revised vs original files differ by −0.004% to +0.083% of US awards a year

## 6. Issues list
| # | Issue | Rows affected | Proposed treatment (decided in staging) |
|---|---|---|---|
| 1 | Original + revised CSV in the same zip; member name case varies | 2015–2023 | Read the `_rv` member (case-insensitive); else the only member, `release = 'provisional'` |
| 2 | C2024 is provisional | 2024 | `release` column; re-download when revised |
| 3 | HD Latin-1 through 2022, UTF-8 from 2023 | HD 2015–2022 | Try UTF-8, fall back to Latin-1 |
| 4 | HD text space-padded | HD 2023–2024 (20,743 `F1SYSNAM` cells) | Strip every text column (pandas 3: not only `object` dtype); CUNY on `F1SYSCOD` |
| 5 | `AWLEVEL` padding change; level 1 → 20/21 | all | Cast to int; `award_level` dimension with old and new certificate codes |
| 6 | Second majors double-count awards | ~7% of rows | Keep `major_number`; measures choose awards (1st) or majors (1st + 2nd) |
| 7 | `99` grand-total rows mixed with detail | ~20.6k rows/year | Drop from fact; keep the tie-out test |
| 8 | CIP 2010 in 2015–2019 (brief start year 2019 included) | 5 years | `cip_edition`; map to CIP 2020 in core (nb 06) |
| 9 | Imputation flags | dozens/year; 1,862 `Z` in 2020 | Keep as `imputation_flag` |
| 10 | Colleges close; NYC membership changes | HD 191 → 173 units | NYC flag from each year's HD |

## 7. Proposed staging tables
- **`stg_ipeds__completions`**: key `year × unitid × cip_code × major_number × award_level`, detailed CIP only, NYC only, asserted unique. `year` int, `release`, `unitid`, `cip_code`, `cip_edition`, `major_number` smallint, `award_level` smallint, `awards_total` / `awards_men` / `awards_women` int, `imputation_flag`, `source_file`. Race/ethnicity stays in raw (not in v1)
- **`stg_ipeds__institutions`**: key `year × unitid`, NYC only (1,836 rows). `name`, `city`, `county_fips`, `borough`, `sector`, `control`, `level`, `is_cuny`, `system_name`, `closed_date`
- **Filters:** 2,990,729 US rows → 58,343 NYC detailed rows
