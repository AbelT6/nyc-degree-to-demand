# Project brief

Written before any data work, and kept as the scope I built against. Notebooks and SQL refer to its questions (Q), scope rules (S) and open questions (O).

## 1. Why

CUNY's push to get every student from graduation into a job (CUNY Beyond), and the current conversation about jobs in the age of AI, both rest on one practical question that students, career counselors and faculty ask all the time. I wanted to answer it with real public data, built the way a data team would build it: a tested pipeline, a database, and a report people can use without help.

## 2. Users

- Career counselors and other CUNY staff who advise students.
- Students, and anyone curious about NYC jobs and graduates.
- Design rule: usable by many people without being overwhelming.

## 3. The question

> **After CUNY, where are the jobs in NYC, and are graduates ready for them?**

| # | Question |
|---|---|
| Q1 | Which industries and jobs are growing or shrinking in NYC, over time (2019 → latest), including hiring? |
| Q2 | What does each job take to get in: degree, major, experience, skills? |
| Q3 | How many graduates finish those majors each year, and is that going up or down? |
| Q4 | What does a beginner earn, and how hard is it to get hired? |
| Q5 | How is AI likely to change the job? |

## 4. Scope

| # | Rule | Detail |
|---|---|---|
| S1 | Place | New York City (5 boroughs). New York State or the metro area only where NYC isn't published, and labeled |
| S2 | Data | Government data for every number where it exists; any other source is labeled as such. No scraping |
| S3 | History | 2019 (the pre-COVID baseline) → latest (2025). Projections are allowed and labeled |
| S4 | Center of the model | **The job.** Two ways in, by industry and by major, landing on the same job page |
| S5 | Degrees | Associate's and bachelor's |
| S6 | Groupings | The National Career Clusters Framework (Advance CTE, 2024), which maps jobs, majors and industries to the same clusters |
| S7 | Featured areas | Data for all jobs, with Tech, Healthcare, Business and Education featured |
| S8 | Industry vs job | Kept separate. Every chart says whether it counts people doing a job (occupation data) or employers in an industry (industry data) |
| S9 | Supply | Graduates from all NYC colleges, with CUNY highlighted. CUNY alone would make fields look less crowded than they are |
| S10 | Hottest jobs | Two lists, no blended score: most openings, and fastest growing |
| S11 | "Crowded field" rule | Jobs growing or shrinking × many or few graduates per opening; only "shrinking and many" counts as crowded. Rules and cutoffs written down before looking at results; fair words ("more competition", never "bad major") |
| S12 | AI | One published research score of AI exposure per job, labeled as research, not government data |
| S13 | Integrity | Every number labeled with source and year. Every load ties to published totals. No silent type conversion. Survey estimates from too few responses suppressed. Estimates always labeled |

## 5. How it's built

Raw files → notebooks that profile and load each source → PostgreSQL (`staging`) → dbt (`core`, `mart`, with tests) → Power BI. One numbered notebook per step, with markdown cells explaining the problem, the fix and why.

## 6. Dashboard direction

Research first on making professional data digestible: a guided story, then open exploration (the "martini glass"); overview first, zoom and filter, details on demand; the right chart for each question; colors and theme last.

## 7. Open questions at the start (all resolved)

| # | Question | Resolved |
|---|---|---|
| O1 | Junior vs senior: no public source splits openings by level | D5: show a range of three estimates |
| O2 | Which sources are in v1 | Settled while profiling (notebooks 01–16) |
| O3 | Database layout | `staging` → `core` → `mart` ([schema-design.md](schema-design.md)) |
| O4 | Headline starting pay | NYS DOL "entry wage" for NYC; pay over time from OEWS medians adjusted with CPI |
| O5 | Hand-built crosswalks | D4: ACS field of degree → CIP, 142 rows, built by hand (`ref/ref_fod_cip.csv`) |
