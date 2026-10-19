# Source card: O\*NET OnLine "In Demand Software Skills", % of job ads per job (Lightcast)

**Explored in:** `notebooks/16-profile-onet-in-demand.ipynb` · Verdict: use for "Skills employers ask for" on the job page (`.00` profile's list per job); national postings, one year; publishing gated on O\*NET confirming the percentages' reuse terms

## 1. What it is
- **Publisher / dataset:** National Center for O\*NET Development (U.S. DOL, ETA), O\*NET OnLine's per-job page "In Demand Software Skills"; percentages from Lightcast job postings
- **Files:** `skills/onet_in_demand/In_Demand_<code>_2026-10-16.csv` + `.html` for 254 O\*NET-SOC codes (508 files, 11.0 MB). Snapshot: O\*NET refreshes the page in place; only the HTML page states the window
- **Retrieved:** 2026-10-16, 16:45–16:58 UTC, 1.5 s between requests (`robots.txt` allows `/link/demand/`) · Reference period: postings from January 1 to December 31, 2025 (stated on all 254 pages)
- **How it was collected:** O\*NET's In Demand flags (the same as O\*NET 31.0's) plus, per product, "the ratio of unique postings which mention the skill to all unique postings linked to the O\*NET-SOC occupation" (O\*NET's page note). Postings, not a survey: covers jobs advertised online in the U.S.
- **Covers / missing:** the O\*NET-SOC codes under the 202 named job-page jobs (254 codes under 198 jobs). The 4 broad or BLS group codes have no O\*NET profile; "All other" groups weren't downloaded
- **License / terms:** O\*NET OnLine content is CC BY 4.0. Whether the Lightcast-derived percentages are covered is unconfirmed (email to O\*NET pending). If not, fall back to the 31.0 flags, unranked
- **Documentation:** [13-2011 example page](https://www.onetonline.org/link/demand/13-2011.00); [O\*NET Technology Skills definitions](https://www.onetcenter.org/dictionary/30.0/text/technology_skills.html); [Hot Technologies and In Demand report](https://www.onetcenter.org/reports/Hot_Technologies_Demand.html)

## 2. Shape
- **Rows × columns:** 1,302 rows × 3 (`Percentage`, `Software Skill`, `Hot Technology`) on 204 of the 254 pages; the other 50 are header-only
- **One row =** O\*NET-SOC code × product; `onet_soc_code + product` unique 
- **Codes used:** O\*NET-SOC 2019 (`13-2011.00`); SOC 2018 = the first 7 characters
- **Time span:** one window, calendar 2025
- **NYC slice:** none; national postings

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `Percentage` | share of the job's unique U.S. postings that mention the product | whole % | 4 to 76; lists come sorted high to low; ties in 105 codes |
| `Software Skill` | product name as O\*NET stores it | text | 306 end in " software" (dropped for display); some put the acronym last ("Structured query language SQL") |
| `Hot Technology` | the product is a Hot Technology across all jobs' postings | "Yes" / blank | blank = no (144 rows) |
| page: "N software skills shown" | number of products on the page | int | equals the CSV rows on all 254 |
| page: "Source: Lightcast … between … and …" | the postings window | text | the same on all 254 |

## 4. What it answers
- **Answers:** "What do employers ask for?" for the job page: up to 6 products ranked by share of job ads (Accountants: Microsoft Excel 28%, Microsoft Office 17%, Intuit QuickBooks 8%…; Data Scientists: Python 66%, SQL 51%, R 34%…)
- **Can't answer / limits:** national, not NYC; software only (no soft skills or certifications); a share of ads that mention the product, not a requirement; online postings over-represent office jobs

## 5. Tie-out
- **The product set equals the O\*NET 31.0 In Demand flags on 254 of 254 pages**, both ways: the 204 flagged codes all have a list, and the 50 unflagged pages show none. The Hot Technology mark agrees with 31.0 on all 1,302 rows. (The build plan asked for this check on all codes, not 5.)
- 13-2011 top 6 = the mockup v4.1 and build plan §5, product for product and % for %

## 6. Issues list
| # | Issue | Rows affected | Treatment |
|---|---|---|---|
| 1 | **Several O\*NET profiles under one SOC job, each with its own posting pool | 31 named jobs have more than one profile | Proposed: show the `.00` profile's list only. Specialty lists differ (they share 0–6 of their top 6 with `.00`), and shares from different pools can't be added or averaged. Effect: 162 jobs get a list, not the plan's 164**: Registered Nurses (only *Advanced Practice Psychiatric Nurses* has a list: Teams 7%, Google Meet 7%) and 17-3024 (only *Robotics Technicians*) get the empty state, so it covers 40 jobs, not 38. To confirm at the gate |
| 2 | Ties, including at the 6th place (20 codes) | 105 codes | Rank by % then O\*NET's row order (not alphabetical: it most likely follows the unrounded share). Deterministic |
| 3 | Trailing " software" in names | 306 rows | Dropped for display in the mart ("Microsoft Office", "SAP"); staging keeps O\*NET's name |
| 4 | Long names: 8 over 32 characters in a top 6 (longest 86, a VHDL tool) | 13 jobs | Truncation test at step 4 (the same as long major names, Desktop test 6) |
| 5 | Reuse terms for the percentages | all | Gate before publishing; ask O\*NET now. Fallback: the 31.0 flags, unranked |
| 6 | The window lives only on the HTML page | all | Parsed per page into `window_start` / `window_end`; the same on all 254 |

## 7. Proposed staging table
- **Name:** `stg_onet__in_demand_pct` (notebook 36)
- **Grain / key:** O\*NET-SOC code × product; key `onet_soc_code + product`; 1,302 rows
- **Columns:** `onet_soc_code : text`, `soc_code : text` (first 7 characters), `product : text` (O\*NET's name), `pct_of_job_ads : integer`, `is_hot_technology : boolean`, `csv_order : integer` (O\*NET's row order, the tie-break), `window_start : date`, `window_end : date`, `retrieved_at : date`, `source_file : text`
- **Filters:** none in staging (specialty codes kept). The `.00` rule, the top 6 and the display name belong to the mart view `job_skill_demand` (step 2)
