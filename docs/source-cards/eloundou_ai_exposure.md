# Source card: AI exposure by job, Eloundou et al. "GPTs are GPTs"

**Explored in:** `notebooks/14-profile-ai-exposure.ipynb` · Verdict: use as the one AI score (D7); a research estimate from 2023 GPT-4 labels, national, exposure ≠ job loss

## 1. What it is
- **Publisher / dataset:** Eloundou, Manning, Mishkin, Rock, "GPTs are GPTs: Labor market impact potential of LLMs", *Science* 384 (2024); data at GitHub `openai/GPTs-are-GPTs`
- **Files:** `skills/eloundou_ai_exposure/occ_level.csv`, `full_labelset.tsv`, `README.md`, `LICENSE.txt`, pinned to commit `0471612`
- **Retrieved:** 2026-10-13 · Edition: labels made 2023 on O*NET 27.x tasks
- **How it was collected:** model + expert rating of every O*NET task (E0 none / E1 LLM alone halves the time / E2 LLM + software built on it would), by GPT-4 and by human annotators
- **Covers / missing:** 923 O*NET jobs = 798 SOC 2018 jobs. "All Other" jobs have no score. National; no city version (the score describes tasks, not places)
- **License / terms:** MIT (© 2024 OpenAI)
- **Documentation:** [arXiv 2303.10130](https://arxiv.org/abs/2303.10130), [*Science*](https://www.science.org/doi/10.1126/science.adj0998), repo README

## 2. Shape
- **Rows × columns:** jobs 923 × 8; tasks 19,265 × 16
- **One row =** job: `O*NET-SOC Code` unique ; task: `O*NET-SOC Code + Task ID` unique 
- **Codes used:** O*NET-SOC 2019 (all current in O*NET 31.0); SOC 2018 = first 7 characters
- **Time span:** one edition
- **NYC slice:** none; NYC enters through NYS DOL employment weights. 99.0% of NYC employment scored (97.0% exact + 2.1% BLS group codes pooled from their parts)

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `dv_rating_beta` | **The D7 score:** GPT-4 β = share of task time exposed, E1 = 1, E2 = 0.5 | decimal 0–1 | Rebuilds exactly from tasks (core 1, supplemental 0.5) |
| `human_rating_beta` | Same, human annotators | decimal 0–1 | Rank correlation with GPT-4: 0.90 |
| `gpt4_exposure`, `human_exposure_agg` | Task label E0 / E1 / E2 | text | |
| `Task Type` | Core / Supplemental | text | 1,312 blank (weighted 0.5) |
| `Task ID` | O*NET task ID | decimal text → int | 97.2% still in O*NET 31.0 |

## 4. What it answers
- **Answers:** S12: how much of a job's work an LLM could speed up, per job, and (weighted by NYC jobs) per cluster, major or education level
- **Can't answer / limits:** whether jobs will be lost or wages fall; anything newer than GPT-4 (2023); NYC-specific task mixes

## 5. Tie-out
- Published job scores vs rebuilt from the task labels: 923 of 923 match (GPT-4 and human), weighted core 1 / supplemental 0.5

## 6. Issues list
| # | Issue | Rows affected | Proposed treatment (decided in staging) |
|---|---|---|---|
| 1 | Leftover index column; `Task ID` decimal text | all tasks | Drop; cast to int |
| 2 | `Task Type` blank | 1,312 tasks | Keep; weight 0.5 |
| 3 | O*NET jobs, not SOC | 923 → 798 | Pooled task mean in core |
| 4 | BLS group codes | 5 NYC codes, 2.1% | Pool their SOC 2018 parts |
| 5 | "All Other" unscored | 21 NYC codes, 1.0% | "Not rated" |
| 6 | GPT-4 vs human gaps for some jobs | e.g. software developers 0.87 vs 0.45 | Show GPT-4; human β kept for a note |
| 7 | 2023 GPT-4 vintage | all | Label year and model |

## 7. Proposed staging table
- **Names:** `stg_eloundou__task_exposure`, `stg_eloundou__job_exposure`; core `job_ai_exposure` (SOC 2018 + BLS group codes)
- **Grain / key:** O*NET job × task; O*NET job; SOC job
- Columns kept → new name : type: `O*NET-SOC Code → onet_soc_code : char(10)`, `Task ID → task_id : int`, `Task Type → task_type : text`, `gpt4_exposure → gpt4_label : char(2)`, `human_exposure_agg → human_label : char(2)`, job scores `dv_rating_* → beta_gpt4` etc. : numeric
- **Filters:** none (19,265 in → 19,265 out)
