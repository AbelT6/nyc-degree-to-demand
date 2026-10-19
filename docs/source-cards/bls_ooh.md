# Source card: BLS Occupational Outlook Handbook (XML compilation), one-line job descriptions

**Explored in:** `notebooks/15-profile-bls-ooh.ipynb` · Verdict: use for the job page's description line, with the hand-checked overrides in `ref/ref_job_description_override.csv` and the O\*NET fallback for 13 jobs

## 1. What it is
- **Publisher / dataset:** U.S. Bureau of Labor Statistics, *Occupational Outlook Handbook* (OOH), the whole handbook as one XML file
- **Files:** `skills/bls_ooh/xml-compilation_2026-10-16.xml` (13.9 MB, dated snapshot: BLS overwrites the file in place)
- **Retrieved:** 2026-10-16 · Edition: 2025–35 projections, May 2025 wages; file "last updated 8/26/2026", every profile published 2026-08-27
- **How it was collected:** editorial text written by BLS economists for each profile; SOC codes assigned to profiles by BLS
- **Covers / missing:** 343 profiles over 606 SOC codes, about the occupations BLS profiles in the OOH. Not covered: 13 of the 202 named job-page jobs (e.g. 13-2041 Credit Analysts, 21-2011 Clergy, 25-3031 Substitute Teachers) and 20 of the 23 "All other" groups
- **License / terms:** public domain (U.S. government work); BLS asks for a citation
- **Documentation:** [OOH developer information](https://www.bls.gov/ooh/about/ooh-developer-info.htm). The download needs the project's descriptive User-Agent (`src/sources.py`); bls.gov refuses a browser one

## 2. Shape
- **Rows × columns:** 606 profile × SOC rows from 343 `<occupation>` elements; kept per row: profile code, title, `<description>`, SOC code, number of SOC codes in the profile, publish date
- **One row =** profile × SOC code; `soc_code` alone is unique (no code sits in two profiles)
- **Codes used:** SOC 2018, detailed, plus 6 broad or BLS group codes (`13-1020`, `13-2020`, `29-2010`, `31-1120`, `39-7010`, `51-2090`)
- **Time span:** one edition
- **NYC slice:** none (national text); joins to the job page's jobs on `soc_code`

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `occupation_code` | BLS profile ID (e.g. `B047`) | text | unique per profile |
| `title` | profile title ("Police and Detectives") | text | can name several jobs |
| `description` | **the one-line sentence**: what people in the job do, third person, plain language | text | 42–347 characters, median 113; 315 one sentence, 25 two (one per job); 3 carry HTML entities |
| `soc_coverage/soc_code` | SOC codes the profile covers | text | 1 to 35 per profile; *Military Careers* has none |
| `what_they_do/section_body` | the profile's main text (HTML) | html | used only in the hand check: its "types of" paragraphs give one BLS sentence per job type |
| `job_outlook/section_datatable` | projections table (HTML) | html | gives BLS's title for each SOC code; used only in the hand check |

## 4. What it answers
- **Answers:** the job page's first question, "what is this job?", in one sentence under the title (design brief §11.10 R2, option B)
- **Can't answer / limits:** national, written for the profile, not the job: 63 of the 202 named jobs share a profile with other jobs, so the sentence can describe the group or another job (hand-checked, §6)

## 5. Tie-out
- Accountants and Auditors (13-2011): file "Accountants and auditors prepare and examine financial records." = the mockup v4.1 and build plan §5, word for word
- Coverage of the 202 named jobs: 189 (126 own profile, 63 shared), the same as the session-i research count

## 6. Issues list
| # | Issue | Rows affected | Treatment |
|---|---|---|---|
| 1 | Shared profiles: the sentence can name another job (33-3031 Fish and Game Wardens gets "Police officers protect lives and property…") | 63 named jobs | **Hand check (nb 15 §5):** 47 keep, 9 take the half of a two-job sentence about the job, 7 take BLS's "types of" sentence. Verdicts and replacement text in the seed `ref/ref_job_description_override.csv`, each replacement checked word for word against the file. One borderline keep (11-1021) |
| 2 | No profile | 13 named jobs | Fallback: first sentence of the O\*NET 31.0 `.00` definition (all 13 have one; imperative mood; `description_source = 'onet'`) |
| 3 | HTML entities and a non-breaking space in the text | 3 profiles, none on the job page | Decode in staging |
| 4 | BLS typo "the Earth&apos; surface" (17-3031) | 1 profile, not on the job page | Kept as published |
| 5 | Length: the plan's test assumed ≤ 256 characters, but the 25-9044 O\*NET fallback is 258 and staging runs to 307 | 1 job-page row | The rule is the layout's ("at most 2 lines at 12pt", R2): step 4 measures the longest with Windows font metrics; dbt tests the job-page rows at ≤ 260, not staging |
| 6 | One profile with no SOC code (*Military Careers*) | 1 profile | Dropped (it can't join to a job) |

## 7. Proposed staging table
- **Name:** `stg_bls__ooh_description` (notebook 36)
- **Grain / key:** one row per SOC code in the file; key `soc_code`; 606 rows
- **Columns:** `soc_code : text`, `ooh_code : text`, `ooh_title : text`, `description : text` (entities decoded), `n_soc_in_profile : integer`, `publish_date : date`, `source_file : text`
- **Filters:** none (every SOC code, not only the job page's). The override seed is applied in `dim_job` at step 2: seed text when it replaces, else the OOH sentence, else the O\*NET first sentence
