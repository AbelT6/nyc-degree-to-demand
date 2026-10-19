# Source card: CUNY Graduates and Enrollment by Program

**Explored in:** `notebooks/05-profile-ipeds-cuny-graduates.ipynb` · Verdict: use with limits (CUNY's latest year and enrollment; IPEDS stays the graduates count)

## 1. What it is
- **Publisher / dataset:** CUNY Office of Institutional Research, via data.ny.gov `28gk-bu58`, *CUNY Graduates and Enrollment by Program*
- **Files:** `graduates/cuny_programs/28gk-bu58.csv`. Tie-out only: `graduates/cuny_degrees_by_type/ybg5-afvs.csv`, `graduates/cuny_enrollment/487n-fp4r.csv`
- **Retrieved:** 2026-10-12 · Reference period: graduates AY 2007-08 → 2024-25; enrollment Fall 2008 → Fall 2025. One current vintage (the portal overwrites it)
- **How it was collected:** administrative records from CUNY's student system, by NYSED-registered program (`IRP CODE`)
- **Covers:** CUNY only (26 reporting units, more than IPEDS's 21). Missing: every other NYC college
- **License / terms:** NY Open Data
- **Documentation:** [dataset page](https://data.ny.gov/d/28gk-bu58)

## 2. Shape
- **Rows × columns:** 107,676 × 15
- **One row =** one program × one period × record type. Program key = `IRP CODE + COLLEGE + AWARD NAME` (2,991 programs, each with exactly 36 rows: 18 graduation years + 18 fall terms). Key unique . `IRP CODE` alone (365 programs share 167 codes: joint BA/MA, AS + AAS)
- **Codes used:** CIP 2020 for every year, including 2008 (history recoded). 55 CUNY award names (`AA`, `AAS`, `BTECH`, `NGBACC` …), no level column
- **Time span:** 18 academic years / 18 fall terms, annual
- **NYC slice:** all of it (all CUNY units are in NYC)

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `IRP CODE` | NYSED program registration | text | Not unique alone |
| `COLLEGE` | Reporting unit | text | 26 names; 6 have no IPEDS record (journalism, public health, labor studies, SPS, medical school ×2) → hand map to parent UNITID |
| `AWARD NAME` / `AWARD NUMBER` | CUNY award code / "1 of 2" for multi-award registrations | text | Map to IPEDS level: 382 associate, 1,369 bachelor, 107 certificate, 1,133 graduate programs |
| `CIP 2020 CODE` | Major | text `NN.NNNN` | All valid CIP 2020 codes |
| `RECORD TYPE` / `PERIOD` | `Graduation` + `AY_YYYY_YYYY`, or `Enrollment` + `Fall_YYYY` | text | Long format mixing two measures |
| `COUNT` | Graduates or enrolled | int | No suppression; 44.5% zeros (full grid) |
| `DATE CLOSED` | Program closure date | text date | Blank for 2,515 open programs |

## 4. What it answers
- **Answers:** CUNY graduates for AY 2024-25, one year ahead of IPEDS (2025: 11,676 associate's, 22,591 bachelor's; the associate's decline flattens). CUNY enrollment by program (the pipeline), which IPEDS completions doesn't have
- **Can't answer / limits:** CUNY-only, so never the all-NYC number. Counts a degree once per program completed, so bachelor's double majors count twice (≈ IPEDS 1st + 2nd majors). CIP codes for 2015–2019 are CIP 2020, so they don't match IPEDS's CIP 2010 for the same graduates

## 5. Tie-out
- vs IPEDS CUNY first majors, associate's 2019–2024: within 58 every year (2024: 11,364 vs 11,402)
- vs IPEDS CUNY 1st + 2nd majors, bachelor's: within 134 every year except 2021 (+585) (2024: 24,085 vs 24,154). Against first majors only, CUNY Programs runs 550–850 higher a year (2024: +648), the double-major effect
- College level, 2024 bachelor's vs IPEDS 1st + 2nd: 0 or ±1 at ten of twelve colleges; Graduate Center −78 (explained in nb 23 §4: IPEDS has 44 Physical Sciences `40.0101` + 34 Liberal Arts `24.0101` GC bachelor's that CUNY Programs doesn't list; health administration is `51.2211` in IPEDS vs `51.0701` in CUNY Programs) and Hunter +11. Supports the parent-college mapping

## 6. Issues list
| # | Issue | Rows affected | Proposed treatment (decided in staging) |
|---|---|---|---|
| 1 | `IRP CODE` not unique | 365 programs / 167 codes | Key `irp_code × college × award_name` |
| 2 | Full grid of zeros (closed / not yet open) | 44.5% of rows | Keep zeros; `date_closed` tells them apart |
| 3 | No award level; 55 award names | all | `award_level` map; assert no unmapped undergraduate names |
| 4 | Units with no IPEDS record | 6 units | Hand map to parent UNITID, flagged as assumption |
| 5 | Double majors counted twice | bachelor's | Document; IPEDS for "how many graduates", CUNY Programs for latest year + enrollment |
| 6 | History recoded to CIP 2020 | all | Note: CUNY 2015–19 CIP ≠ IPEDS 2015–19 CIP |
| 7 | Graduates and enrollment in one column | all | Split into two staging tables on `RECORD TYPE` |
| 8 | Graduate Center −78 vs IPEDS (2024 bachelor's) | 1 college | Explained (nb 23 §4): 78 IPEDS awards with no CUNY Programs row, plus a CIP coding difference. No fix; IPEDS stays the count source |
| 9 | Tie-out file `ybg5-afvs` has messy label variants (`Baccalaureate` / `BACHELOR'S`) | tie-out only | Not staged |

## 7. Proposed staging tables
- **`stg_cuny__program_graduates`**: key `irp_code × college × award_name × academic_year`, 53,838 rows
- **`stg_cuny__program_enrollment`**: key `irp_code × college × award_name × fall_term`, 53,838 rows
- **Columns (both):** `irp_code`, `college`, `unitid` (mapped), `program_name`, `award_name`, `award_level`, `award_number`, `cip_code` (2020), `date_registered` date, `date_closed` date, `tap_eligible` bool, `period`, `year` int, `graduates` / `enrolled` int, `source_file`
- **Filters:** none (all CUNY); split on `RECORD TYPE`
