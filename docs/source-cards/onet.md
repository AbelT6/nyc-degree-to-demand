# Source card: O*NET 31.0 Database

**Explored in:** `notebooks/11-profile-onet.ipynb` · Verdict: use for skills, knowledge, software, job zone and experience per job; national only, ~23 respondents per job for education/experience, a few new jobs not rated yet

## 1. What it is
- **Publisher / dataset:** National Center for O*NET Development for the U.S. Department of Labor (ETA), *O*NET 31.0 Database* (CSV)
- **Files:** `skills/onet/db_31_0_csv.zip` (45 tables), `db_30_0_text.zip` (previous release: last with Tools Used; used to see what changed), `2019_to_SOC_Crosswalk.xlsx` (O*NET-SOC 2019 → SOC 2018; re-downloaded 2026-10-12, the first copy was the HTML page), `Education_CIP_to_ONET_SOC.xlsx`
- **Retrieved:** 2026-10-12 · Edition: 31.0, August 2026
- **How it was collected:** survey + expert ratings. Workers rate knowledge, activities, education, experience (72–73%), occupational experts fill hard-to-sample jobs (27–28%), analysts rate skills and abilities. Software lists from postings and employer data. Each job is resurveyed every ~5–10 years
- **Covers / missing:** 1,016 O*NET jobs, ratings for 910. United States only, no NYC profile, no counts, no wages
- **License / terms:** CC BY 4.0 (credit O*NET and U.S. DOL/ETA)
- **Documentation:** [31.0 data dictionary](https://www.onetcenter.org/dictionary/31.0/csv/), [taxonomy](https://www.onetcenter.org/taxonomy.html)

## 2. Shape
- **Rows × columns:** 45 tables, 1.12M rows. v1 uses: skills (63,700), knowledge (60,060), education (11,495), training & experience (26,812), job zones (923), software (31,821), occupations (1,016)
- **One row =** job × descriptor × scale (ratings) or job × question × answer category (shares). All keys unique 
- **Codes used:** O*NET-SOC 2019 (`15-1252.00`); SOC 2018 = first 7 characters (confirmed for all 1,016 codes)
- **Time span:** one release; each rating has its own date (2004–2026, half from 2022+)
- **NYC slice:** none (national). Joined to NYC jobs by SOC: 98.4% of NY metro employment gets a profile (88.4% exact, 10.0% via BLS group/aggregate parts)

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `O*NET-SOC Code` | Job | text | `.00` = SOC job; `.01+` = O*NET specialty |
| `Element ID`, `Element Name` | Descriptor (skill, knowledge area, question) | text | 35 skills = 10 essential `2.A` + 25 transferable `2.B` |
| `Scale ID` | `IM` importance 1–5, `LV` level 0–7, `RL` education categories, `RW` experience categories | text | |
| `Category` | Answer category (education 1–12, experience 1–11) | int | Value = % of workers giving that answer |
| `Data Value` | The rating or share | decimal | |
| `N`, `Standard Error`, CI bounds | Sample size and precision | decimal | Median N: 8 analysts (skills), 22–23 workers (knowledge, education, experience) |
| `Recommend Suppress`, `Not Relevant` | O*NET's own quality flags | Y/N | Suppress: 8.2% of knowledge, ≤ 4% elsewhere |
| `Date`, `Domain Source` | When and by whom it was rated | text | |
| `Hot Technology`, `In Demand` | Software flags | Y/N | 8,753 distinct products |

## 4. What it answers
- **Answers:** Q2 what a job takes (top skills, knowledge, software, job zone); O1 junior vs senior, as one estimate ("newcomer share" = workers who needed ≤ 1 month of related experience; 752 jobs, 86% of NYC employment); a second opinion on BLS entry education; the join key for the S12 AI score.
- **Can't answer / limits:** nothing NYC-specific; one profile per job (no junior/senior split inside a job); no counts or pay; 47 newer jobs (1.6% of NYC employment, incl. financial and investment analysts `13-2051`) have no skill ratings yet; its CIP → job table is just the NCES crosswalk (no help for D2).

## 5. Tie-out
- No published totals to reproduce. Checked against BLS (2025 edition, nb 04) instead:
- Education: same level for 68% of 612 jobs; O*NET higher 21%, lower 10% (expected: workers' attainment vs BLS entry requirement).
- Experience: workers needing ≤ 1 month related experience, median 23% / 13% / 0.1% for BLS "none / < 5 years / 5+ years" (728 jobs). Direction right at every step.
- 31.0 vs 30.0 skills: identical 35 skills; 62,580 rows match; values changed only for 141 jobs re-rated in 2026.

## 6. Issues list
| # | Issue | Rows affected | Proposed treatment (decided in staging) |
|---|---|---|---|
| 1 | O*NET-SOC vs SOC 2018 | all | `soc_code = left(code, 7)` |
| 2 | Several profiles per SOC job | 76 SOC jobs | `.00` if rated, else average of rated specialties (gap vs averaging: 0.16 on 1–5) |
| 3 | BLS group/aggregate codes in OEWS | 12 NYC codes, 10% of jobs | Average of rated parts, via nb 06 aggregate → parts bridge (core) |
| 4 | Jobs not rated yet | 47 NYC codes, 1.6% | Show tasks, software, job zone; label "not yet rated by O*NET" |
| 5 | Suppress / not-relevant flags | ≤ 8.2% | Keep as booleans; hide in dashboard |
| 6 | Ratings 2004–2026 | all | Keep `rated_date`; show it |
| 7 | Skills split into two tables | 63,700 | Stack with `skill_type` |
| 8 | Work styles rebuilt (new scales) | 37k | Not in v1 |
| 9 | ~23 respondents per job (RL, RW) | 19k | Show bands, not exact % |
| 10 | O*NET CIP → job = NCES crosswalk | 8,501 | Don't load |

## 7. Proposed staging tables
- **`stg_onet__occupation`** (1,016): `onet_soc_code`, `soc_code`, `title`, `description`, `has_ratings`
- **`stg_onet__descriptor_rating`** (123,760; skills + knowledge, `IM`/`LV`): `onet_soc_code`, `soc_code`, `domain`, `element_id`, `element_name`, `scale`, `value`, `n`, `std_error`, `ci_low`, `ci_high`, `suppress`, `not_relevant`, `rated_date`, `rating_source`
- **`stg_onet__education_experience`** (19,007; `RL` + `RW`): `question`, `category`, `category_label`, `share_pct`, `n`, `suppress`, `rated_date`
- **`stg_onet__job_zone`** (923): `job_zone`, `rated_date`
- **`stg_onet__software`** (31,821): `product`, `commodity_id`, `commodity_title`, `is_hot_technology`, `is_in_demand`
- All carry `onet_release = '31.0'`. No filters (national; joined to NYC jobs in core).
