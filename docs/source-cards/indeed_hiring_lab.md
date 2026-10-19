# Source card: Indeed Hiring Lab job postings index

**Explored in:** profiled and loaded in `notebooks/33-load-indeed-postings.ipynb` · Verdict: use with limits: national check beside Revelio (D10); an index, not counts; private data

## 1. What it is
- **Publisher / dataset:** Indeed Hiring Lab, `job_postings_tracker` (GitHub)
- **Files:** `postings/indeed_hiring_lab/aggregate_job_postings_US_*.csv`, `job_postings_by_sector_US_*.csv`, `state_job_postings_us_*.csv`, `metro_job_postings_us_*.csv` (snapshot 2026-10-12)
- **How it was collected:** postings on Indeed; 7-day trailing average, each series seasonally adjusted on its own (Bundesbank daily method). Method changed Nov 2024 and the whole history was revised, so files are snapshots
- **License / terms:** CC BY 4.0, cite Indeed Hiring Lab
- **Documentation:** [github.com/hiring-lab/job_postings_tracker](https://github.com/hiring-lab/job_postings_tracker)

## 2. Shape
- **One row =** day × series. Daily, Feb 1 2020 → Oct 2 2026 (2,436 days, no gaps)
- **Index:** Feb 1, 2020 = 100 (every series reads exactly 100 that day )
- **Codes used:** 47 Indeed job categories (not SOC); states as 2-letter codes; metros as CBSA

## 3. Key columns
| Column | Meaning | Notes |
|---|---|---|
| `index_sa` | Seasonally adjusted index | All files |
| `index_nsa` | Not adjusted | National file only |
| `measure` | `total` or `new` postings | National and category files |

## 4. What it answers
- **Answers:** direction of U.S. postings by job category, and NY State / NYC metro postings overall (D10 check)
- **Can't answer:** counts, NYC by job, education level of postings

## 5. Tie-out
- Base day = 100 in all 98 series; no gaps or repeated days. No published counts to tie to.

## 6. Issues list
| # | Issue | Treatment |
|---|---|---|
| 1 | Indeed categories ≠ SOC | Hand-built category → SOC major-group map, one group per category, from Hiring Lab's `sector-job-title-examples.csv` (two example titles per sector; downloaded 2026-10-15 to `postings/indeed_hiring_lab/sector-job-title-examples_2026-10-15.csv`, in the manifest). The examples file is an older taxonomy: 41 of 47 names match the sector file; Aviation, Data & Analytics, IT Infrastructure Operations & Support, IT Systems & Solutions, Mechanical Engineering, Social Science are mapped by name. 11 categories whose two titles sit in different groups take the first title's group and are flagged. Lives in nb 45 §4 (rule explore-plan §3f); becomes a `ref` seed when the mart needs it |
| 2 | Whole history revised when the method changes | Snapshot each run; cite the download date |
| 3 | Other states and metros not needed | Kept only NY State and NYC metro (CBSA 35620) |

## 7. Staging tables
- `stg_indeed__postings_national` (date + measure; 4,872), `stg_indeed__postings_category` (date + measure + category; 228,984), `stg_indeed__postings_area` (date + area_code; 4,872)
