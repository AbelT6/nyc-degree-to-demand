# Source card: crosswalks (SOC 2018 structure, SOC 2010→2018, OEWS hybrids, CIP 2010→2020, CIP→SOC)

**Explored in:** `notebooks/06-profile-crosswalks.ipynb` · Verdict: use (code bridges); major→job needs a degree-level filter and an allocation rule

## 1. What it is
- **Publisher / dataset:** BLS for the OMB SOC Policy Committee (SOC 2018 structure, SOC 2010→2018 crosswalk); BLS OEWS (2019 hybrid structure); NCES (CIP 2020 list, CIP 2010→2020); NCES + BLS jointly (CIP 2020 ↔ SOC 2018)
- **Files:** `jobs/bls_soc_structure/soc_structure_2018.xlsx`, `jobs/bls_soc_crosswalk/soc_2010_to_2018_crosswalk.xlsx`, `jobs/bls_oews_hybrid/oes_2019_hybrid_structure.xlsx`, `graduates/nces_cip/CIPCode2020.csv`, `graduates/nces_cip/Crosswalk2010to2020.csv`, `graduates/nces_cip/CIP2020_SOC2018_Crosswalk.xlsx`
- **Retrieved:** 2026-10-12 (structure and hybrid file added that day via `src/sources.py`) · Editions: SOC 2018, CIP 2020
- **How it was made:** classifications maintained by committees; the hybrid list is BLS's own aggregation during the SOC changeover; CIP→SOC is expert judgment ("this program prepares people for this job"), not observed outcomes
- **License / terms:** U.S. government works, public domain
- **Documentation:** [SOC 2018](https://www.bls.gov/soc/2018/home.htm), [OEWS and the 2018 SOC](https://www.bls.gov/oes/soc_2018.htm), [CIP 2020](https://nces.ed.gov/ipeds/cipcode/), [CIP–SOC crosswalk](https://nces.ed.gov/ipeds/cipcode/resources.aspx?y=56)

## 2. Shape
| Table | Rows | One row = | Key unique |
|---|---|---|---|
| SOC 2018 structure | 1,447 | one code (23 major, 98 minor, 459 broad, 867 detailed) | `code` |
| SOC 2010→2018 | 900 | one code pair: 766 1:1, 70 split, 32 merge, 32 split + merge | yes |
| OEWS hybrid | 868 | one OEWS 2019 code × its SOC 2018 / OEWS 2018 / SOC 2010 parts | all four codes |
| CIP 2020 list | 2,848 | one code at 2, 4 or 6 digits (incl. old codes that moved or were deleted) | yes |
| CIP 2010→2020 | 2,699 (2,180 detailed) | one code pair; strictly 1:1 for detailed codes | yes |
| CIP-SOC | 6,097 | one link (5,723 real) + 194 majors with no job + 180 jobs with no major | yes |

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| SOC `code`, `level` | SOC 2018 code and level | text | Built from the level column the code sits in; parents carried forward |
| `2010 SOC Code` / `2018 SOC Code` | Code pair | text | 166 titles carry `(#)` / `(##)` footnote marks |
| `OES 2019 Estimates Code` … `NOTES` | Hybrid code and its parts | text | 889 padded cells (titles/notes); 30 codes are neither SOC 2018 nor 2010 |
| `CIPCode2010` / `CIPCode2020` / `Action` | CIP code pair | text in `="…"` | `Deleted` rows repeat the old code as the 2020 code |
| CIP list `Action` | Change type | text | `Moved to` marks the NEW code here, the old code in the crosswalk |
| `CIP2020Code` / `SOC2018Code` | Major ↔ job link | text | `99-9999` / `99.9999` = no match |

## 4. What it answers
- **Answers:** one job list for every source (all 10,389 code uses across 14 NYC slices resolve to SOC 2018 detailed); IPEDS 2015–19 majors on CIP 2020 (lookup, no weights); which jobs each major prepares for (brief S4). D1 is feasible: BLS EP 2025-35 has rates for all 11 SOC 2018 parts of the broken 2022-32 codes
- **Can't answer / limits:** where graduates actually work (ACS PUMS, nb 08). Graduates per job without rules: 28% of award-weighted links from NYC's 2024 associate + bachelor's awards point to postsecondary teaching, and for 9.1% of awards (6,478; largest `24.0101` Liberal Arts, 3,439) it's the only link. Catch-all jobs collect hundreds of majors (`25-1071`: 337). 18% of NYC wage jobs (20% of employment) have no major at all: low-education service jobs, as expected

## 5. Tie-out
- SOC 2018 published size 23 / 98 / 459 / 867 = file ; SOC 2010 840 detailed = file 
- CIP change counts agree between the two NCES files: 460 new, 145 moved, 7 deleted, 1,568 unchanged 
- CIP-SOC no-match rows = the *Unmatched* sheets ; `SOC-CIP` sheet lacks 4 links (`03.0204`) 

## 6. Issues list
| # | Issue | Rows affected | Proposed treatment (decided in staging/core) |
|---|---|---|---|
| 1 | Header rows at different depths | 3 BLS xlsx | Fixed header row; assert names |
| 2 | Codes wrapped in `="…"` | NCES CSVs | Strip; assert pattern |
| 3 | Padded titles/notes | hybrid · 889 cells | Strip |
| 4 | `(#)`/`(##)` title marks | SOC xw · 166 | Strip; `relation` column |
| 5 | SOC 2010→2018 splits | 102 pairs | Weight splits by employment share (decide in core) |
| 6 | BLS aggregates not in SOC 2018, 5 still current (`21-1018`, `25-2052`, `25-9045`, `51-2028`, `53-1047`) | 30 codes | Job dimension rows with `is_bls_aggregate` + bridge to parts |
| 7 | SOC 2010 group codes in old projections | `15-1100`, `31-1000` | Resolve through SOC 2010 detailed members |
| 8 | `Moved to` has opposite meanings in the two NCES files | 290 rows | Use code pairs, never the label alone |
| 9 | `Deleted` rows keep a 2020 code | 7 rows | Null the target |
| 10 | No-match sentinels in the link sheet | 374 rows | Flags on dimensions, not links |
| 11 | `SOC-CIP` misses 4 links | `03.0204` | `CIP-SOC` is master |
| 12 | Postsecondary-teaching and catch-all links | 28% of weighted links | **Degree-level filter + allocation rule** → decision log |
| 13 | Expert judgment, not outcomes | all links | Label as "prepares for"; test with ACS PUMS (nb 08) |

## 7. Proposed staging tables
- **`stg_bls__soc_2018_structure`** (1,447): `soc_code`, `soc_title`, `level`, `major_code`, `minor_code`, `broad_code`
- **`stg_bls__soc_2010_2018`** (900): `soc_2010`, `soc_2018`, titles (marks stripped), `relation`
- **`stg_bls__oews_hybrid`** (868): `oes_2019`, `soc_2018`, `oes_2018`, `soc_2010`, titles, `notes`
- **`stg_nces__cip_2020`** (2,848): `cip_code`, `title`, `level`, `action`, `definition`
- **`stg_nces__cip_2010_2020`** (detailed): `cip_2010`, `cip_2020` (null when deleted), `action`, titles
- **`stg_nces__cip_soc`** (5,723 real links): `cip_2020`, `soc_2018`; no-match lists → `has_job_link` / `has_major_link` flags
- **Core (later):** job dimension = SOC 2018 detailed + 5 permanent aggregates; `bridge_job_code` (any source code → SOC 2018 detailed, with weight); `bridge_major_job` (after the degree-level filter)
