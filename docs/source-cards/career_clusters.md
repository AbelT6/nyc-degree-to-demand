# Source card: National Career Clusters® Framework crosswalks (Advance CTE)

**Explored in:** `notebooks/13-profile-career-clusters.ipynb` · Verdict: use for jobs and industries; for majors, build the clusters from our own filtered major → job links (candidate D6)

## 1. What it is
- **Publisher / dataset:** Advance CTE, *National Career Clusters Framework Crosswalk: CIP, SOC, NAICS, Cluster, and Sub-Cluster* (modernized framework, released Oct 2024; adopted by O*NET Apr 2025)
- **Files:** `skills/career_clusters/Full_Framework_Crosswalk.xlsx` (combined), `…_SOC-Career-Clusters.xlsx`, `…_CIP-Career-Clusters.xlsx`, `…_NAICS-Career-Clusters-Subclusters.xlsx`
- **Retrieved:** 2026-10-13 · Edition: uploaded 2025-09 (no version number in the files)
- **How it was collected:** expert assignment of SOC 2018 jobs to sub-clusters; CIP 2020 programs brought in through the NCES CIP ↔ SOC crosswalk; NAICS sectors by hand
- **Covers / missing:** 851 job codes (839 SOC 2018 + 12 BLS aggregates, which cover the 28 missing SOC jobs), 1,946 of 2,325 CIP 2020 programs, all 20 NAICS sectors. No counts
- **License / terms:** free to download and use; "National Career Clusters" is Advance CTE's registered trademark, so credit it by name
- **Documentation:** each workbook's *Overview* sheet; [crosswalk page](https://careertech.org/resource/framework-crosswalk/); [guidebook](https://careertech.org/resource/guidebook-modernized-national-career-clusters-framework/)

## 2. Shape
- **Rows × columns:** SOC 1,203 × 4; CIP 4,725 × 4; NAICS 112 × 4; combined 6,688 × 8
- **One row =** one link. Keys unique : `SOC + sub-cluster`, `CIP + sub-cluster`, `sub-cluster + NAICS`. Combined `SOC + CIP + sub-cluster` has 2 exact duplicates
- **Codes used:** SOC 2018 (+ OEWS aggregates `31-1120`, `29-2010`, `13-1020` …), CIP 2020 6-digit, NAICS 2-digit sectors (`31-33` style)
- **Time span:** one edition, no time dimension
- **NYC slice:** none needed; joins on codes. Covers 100% of NYC employment, 99.99% of NYC projected openings, 97% of NYC 2024 associate's and bachelor's awards

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `Career Cluster` | One of 14 clusters | text | |
| `Sub-Cluster` | One of 71 sub-clusters in the files (the site lists 72: Digital Technology's *Unmanned Vehicle Technology* has no crosswalk rows); names unique across clusters | text | `water systems` lower case once in the NAICS file |
| `SOC Code` | Job | text `NN-NNNN` | 12 BLS aggregates |
| `CIP Code (2020)` | Major / program | text `NN.NNNN` | Leading zeros: read as text |
| `2-Digit NAICS` | Industry sector | text | Combined file packs two sectors in one cell (`"62, 81"`); use the NAICS file |

## 4. What it answers
- **Answers:** S6 umbrellas: cluster → sub-cluster → job, and sector → cluster. S7 featured areas
- **Can't answer / limits:** no "primary" cluster for the 125 jobs in several clusters (12% of NYC employment). Major → cluster is derived from the NCES CIP ↔ SOC links, so it inherits the professor problem (D2): 73% of NYC awards are tagged Education only through `25-1xxx` jobs. NAICS only at sector level

## 5. Tie-out
- No counts to tie. The four files agree exactly with each other; 14 clusters / 72 sub-clusters match the guidebook; 5,705 of 5,775 CIP ↔ SOC pairs are the NCES crosswalk (the other 70 are recoded to OEWS aggregates)

## 6. Issues list
| # | Issue | Rows affected | Proposed treatment (decided in staging) |
|---|---|---|---|
| 1 | Combined file: 14 header rows, 2 duplicates | 16 rows | Use the separate files |
| 2 | 12 SOC codes are BLS aggregates | 12 jobs | nb 06 aggregate → parts bridge |
| 3 | NYS DOL hybrid codes missing | 11 codes, 0.01% of openings | nb 06 hybrid bridge |
| 4 | Major clusters carry the D2 professor problem | most CIPs | **Candidate D6:** derive from D2-filtered major → job links |
| 5 | Jobs in several clusters, no primary | 125 jobs, 12% of NYC jobs | **Candidate D6:** many-to-many; never sum clusters |
| 6 | `water systems` case | 1 row | Not fixed in staging (both spellings loaded); `core.dim_career_cluster` matches case-insensitively, 71 sub-clusters (plan §7) |
| 7 | Sectors 54, 92 in two clusters | 2 sectors | Show both |
| 8 | "Other" / "General" CIPs not covered | ~2.9% of NYC awards | "No cluster" |
| 9 | No version number | all | Manifest hash + date; recheck yearly |

## 7. Proposed staging table
- **Names:** `stg_cte__cluster` (72), `stg_cte__soc_subcluster` (1,203), `stg_cte__naics_subcluster` (112), `stg_cte__cip_subcluster` (4,725, reference only if D6 agreed)
- **Grain / key:** sub-cluster; job × sub-cluster; sector × sub-cluster; major × sub-cluster
- Columns kept → new name : type: `Career Cluster → cluster_name : text`, `Sub-Cluster → subcluster_name : text`, `SOC Code → soc_code : char(7)`, `CIP Code (2020) → cip_code : char(7)`, `2-Digit NAICS → naics_sector : text`
- **Filters:** none (rows in = rows out, except the 16 combined-file rows, which aren't used)
