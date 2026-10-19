# Source card: BLS education & training requirements

**Explored in:** `notebooks/04-profile-bls-education.ipynb` · Verdict: use (national rule applied to NYC jobs; attainment table with limits)

## 1. What it is
- **Publisher / dataset:** U.S. Bureau of Labor Statistics, Employment Projections: `education.xlsx`, 2025–35 projections (2025 National Employment Matrix)
- **Files:** `jobs/bls_ep_education/education_2026-10-12.xlsx`. The prototype's `data/raw/education.xlsx` is the same file (same SHA-256)
- **Retrieved:** 2026-10-12 · Edition: assignments 2025; attainment ACS 2023–24; earnings CPS 2025
- **How it was collected:** Table 5.4 is an expert assignment by BLS economists (ACS, O*NET, NCES completions, employer/educator input; legal rules override). Only the *typical* path is recorded. Table 5.3 is ACS microdata (workers 25+)
- **Covers:** all 831 jobs in the national matrix. United States only, no NYC version exists
- **License / terms:** U.S. government work, public domain
- **Documentation:** [EP education technical documentation](https://www.bls.gov/emp/documentation/education/tech.htm), [EP tables](https://www.bls.gov/emp/tables.htm), [ACS crosswalk for the `[1]` footnote](https://www.bls.gov/emp/classifications-crosswalks/NEM-OccCode-ACS-Crosswalk.xlsx)

## 2. Shape
- **Sheets:** Index, 5.1 (attainment → earnings, unemployment), 5.2 (US jobs by entry education), 5.3 (attainment by job), 5.4 (requirements by job)
- **One row =** one job, one edition. Key `soc` unique in 5.3 (832 incl. total) and 5.4 (831)
- **Codes used:** 819 SOC 2018 detailed + 7 SOC 2018 broad codes (e.g. `31-1120`) + 4 BLS aggregates (`21-1018`, `25-9045`, `51-2028`, `53-1047`) + 1 SOC 2010 code BLS kept (`25-2052`). All resolve to SOC 2018 through the notebook 06 bridge. A trailing `8` is not a hybrid marker (`29-1218` is real SOC 2018); test against the structure file and BLS's hybrid list
- **Time span:** one edition, no history
- **NYC slice:** none. Applied to NYC by joining on SOC

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `Typical education needed for entry` | Typical entry credential | ordered text (8) | From "No formal educational credential" to "Doctoral or professional degree". Certificates ("Postsecondary nondegree award") rank below associate's |
| `Work experience in a related occupation` | Prior work needed | ordered text (3) | None / Less than 5 years / 5 years or more. 716 of 831 = None |
| `Typical on-the-job training…` | Training after hire | ordered text (6) | None … Apprenticeship, Internship/residency |
| `Related OOH content` | Has a Handbook page | text | `—` = no page (225) |
| 5.3 attainment columns (7) | % of workers 25+ by highest education | numeric | Rows sum to 100 ± 0.2. Title mark `[1]` = profile borrowed from a broader ACS code (458 jobs) |

## 4. What it answers
- **Answers:** Q2, the education, experience and training each job asks for at entry. The degree-level filter between majors and jobs (associate vs bachelor's). One input to junior vs senior (experience = jobs you're promoted into). Underemployment per job for the crowded-field rule (attainment vs requirement)
- **Can't answer / limits:** NYC employers' actual asks; alternative paths (RN: associate's also accepted, but typical = bachelor's); junior vs senior *openings* within a job; attainment is national and over half borrowed from broader groups

## 5. Tie-out
- OOH Software Developers (2025–35): Bachelor's / None / None. File: same 
- EP tech doc example, Registered Nurses = Bachelor's. File: same 
- Table 5.2 categories sum to the total (170,280.8k) within 0.1k 
- NYC context: 30.7% of NYC jobs need a bachelor's at entry vs 25.2% US; associate's 1.6% vs 2.1%

## 6. Issues list
| # | Issue | Rows affected | Proposed treatment (decided in staging) |
|---|---|---|---|
| 1 | Notes, source and footnote rows below the data | 1 (5.4), 3 (5.3) | Keep rows whose code matches `NN-NNNN`; assert counts |
| 2 | `[1]` mark inside 5.3 titles | 458 | Strip; `acs_inexact = true` |
| 3 | Borrowed attainment profiles | 454 jobs (520 profiles for 831 jobs) | Keep flag; dashboard says "based on a broader group" |
| 4 | Ordered categories stored as text | 831 × 3 | Add ranks from BLS's order; assert no unknown labels |
| 5 | `—` for no OOH page | 225 | `has_ooh_page` boolean |
| 6 | 7 BLS aggregate codes ending in `0` | 7 | Keep; mark `is_bls_aggregate` in the job dimension |
| 7 | 2022-32 projection codes with no assignment (hybrids, split codes, minor groups) | 15 NYC leaves incl. `15-1256` Software Developers | Resolve through the notebook 06 bridge; take the children's requirement, flag disagreements |
| 8 | National, not NYC | all | Area = United States; page footnote |
| 9 | Three time references; 2025 CPS missing October | all | `edition`, `attainment_years` columns; don't stage 5.1/5.2 |
| 10 | "Typical" hides alternative paths (RN: 24.9% of RNs hold an associate's) | judgment calls | Show attainment next to requirement; possible hand-kept `alternative_entry` note (decide later) |
| 11 | Table 5.2 labels indented with 2 spaces | 8 | Strip (only if 5.2 is ever used) |

## 7. Proposed staging tables
- **`stg_bls__ep_entry_requirements`**: one row per `soc_code`, 831 rows. `edition`, `soc_code`, `soc_title`, `education` + `education_rank`, `experience` + `experience_rank`, `training` + `training_rank`, `has_ooh_page`, `source_file`
- **`stg_bls__ep_attainment`**: one row per `soc_code × attainment_level` (long), 832 × 7 = 5,824 rows. `edition`, `attainment_years` (`2023-24`), `soc_code`, `attainment_level`, `attainment_rank`, `pct_of_workers`, `acs_inexact`, `source_file`
- **Filters:** none (all jobs are national; NYC relevance comes from the join)
