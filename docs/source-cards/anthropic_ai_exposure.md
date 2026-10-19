# Source card: AI exposure by job, Anthropic Economic Index "observed exposure"

**Explored in:** options check in `notebooks/14-profile-ai-exposure.ipynb` (D7), profiled and loaded in `notebooks/31-load-anthropic-ai-exposure.ipynb` · Verdict: main AI score (D7 revised); reflects one company's users, national, exposure ≠ job loss

## 1. What it is
- **Publisher / dataset:** Anthropic Economic Index, "Labor market impacts of AI" (Massenkoff & McCrory, Mar 2026); Hugging Face `Anthropic/EconomicIndex`, folder `labor_market_impacts/`
- **Files:** `skills/anthropic_ai_exposure/job_exposure.csv`, `task_penetration.csv`, `README.md`, pinned to commit `4e5f69f`
- **Retrieved:** 2026-10-14 · Edition: Mar 2026, Claude usage data mapped to O\*NET tasks
- **How it was collected:** observed use: starts from Eloundou et al.'s task labels and keeps only tasks seen in work-related use of Claude (automated use counts fully, assisted half), weighted by time spent on each task
- **Covers / missing:** 756 SOC 2018 detailed jobs. No score for "All Other" jobs, BLS group codes, or some large jobs such as home health and personal care aides (31-1121/31-1122)
- **License / terms:** data CC-BY (README)
- **Documentation:** [Labor market impacts](https://www.anthropic.com/research/labor-market-impacts), dataset README

## 2. Shape
- **Rows × columns:** jobs 756 × 3; tasks 17,998 × 2
- **One row =** job: `occ_code` unique ; task: task text, unique after dropping 6 exact repeats
- **Codes used:** SOC 2018, detailed (all 756 found in the BLS SOC 2018 structure); tasks have no ID and no job code, only the O\*NET task text
- **Time span:** one edition
- **NYC slice:** none; NYC enters through NYS DOL employment weights in core

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `observed_exposure` | **The D7 score**: share of a job's time-weighted tasks seen in work use of Claude | decimal 0–1 | 411 of 756 jobs are exactly 0 (band "not seen yet") |
| `penetration` | Share of a task's exposure seen in Claude use | decimal 0–1 | 1,348 of 17,992 tasks above 0 |
| `task` | O\*NET task statement | text | 100% match the task text in `stg_eloundou__task_exposure`, which carries the job code |

## 4. What it answers
- **Answers:** S12: how much of each job's work people already hand to AI, per job and (weighted by NYC jobs) per group
- **Can't answer / limits:** what other AI tools are used for; NYC task mixes; whether jobs will shrink

## 5. Tie-out
- No published total to tie to. Every row kept (756 → 756; 17,998 → 17,992 after exact repeats)
- Agreement with Eloundou β per SOC job: Pearson 0.64, rank 0.70 (D7 recorded 0.65 / 0.72 on a slightly different pooling)

## 6. Issues list
| # | Issue | Rows affected | Treatment |
|---|---|---|---|
| 1 | One task repeated (4 times in each of two capitalizations) | 6 rows | Drop exact repeats; keep both capitalizations (each matches its own O\*NET row) |
| 2 | Tasks have no job code | all tasks | Join on text through `stg_eloundou__task_exposure` (100% match) |
| 3 | 7 jobs score above their Eloundou β | 7 jobs | Kept: β counts tasks equally, observed exposure weights by time |
| 4 | Unscored jobs | 8% of degree-reachable NYC jobs | "Not rated"; stretch goal: rebuild from tasks to fill (core-build-plan §3) |
| 5 | Apostrophe differs from BLS title (33-3051) | 1 job | Kept as published; core uses BLS titles |

## 7. Staging tables
- **`stg_anthropic__job_exposure`**: key `soc_code`; `occ_code → soc_code : text`, `title : text`, `observed_exposure : double`; 756 rows
- **`stg_anthropic__task_penetration`**: key `task`; `task : text`, `penetration : double`; 17,992 rows
