# Key decisions

Public data rarely answers a question as asked. These are the judgment calls that shaped the numbers, each with the problem, what I chose, and why. The D-numbers are the IDs I gave decisions during the build (D1 to D65); notebooks, SQL comments and the source cards refer to them. This page covers the ones that matter most; the rest are explained where they apply.

## Data defects and gaps

**D1 · A defect in the state's official projections.** In the NYS Department of Labor's 2022–2032 projections for NYC, every BLS "aggregate" occupation code collapsed. Software Developers and QA showed 600 jobs, where OEWS counts about 80,000. Data Scientists and Project Management were missing. About 379,000 NYC jobs (7.8%) belonged to no published occupation. The official spreadsheet had the same values as the open-data feed, so the defect was in the publication, not my extract. The 2020–2030 edition had the codes, but it started from the COVID trough. *Choice:* keep every published value and trust the group totals, which are complete. Then split each group's missing remainder across the broken codes by their NYC employment (OEWS 2025), grow them with BLS national rates, and rescale so every group still sums to its published total. The filled rows are flagged and shown as estimates. *Why:* the totals stay exact by construction, and the jobs CS, finance and data majors target don't inherit a pandemic baseline.

**D8 · NYC job counts by year don't exist.** OEWS publishes the New York metro area, not the city. *Choice:* estimate NYC jobs by year as NYC industry employment (QCEW) × New York's staffing pattern for each industry (OEWS research estimates), labeled "our estimate," with the published metro line beside it as a check. *Why:* it's the same method NYS DOL uses to build its own projections.

**D12 · Job codes changed in 2018.** 42 SOC 2010 codes split into 2–8 SOC 2018 codes, and BLS publishes no weights for the split. *Choice:* split by each part's share of NY metro employment in 2021 (the first year in the new codes), falling back to national shares, then equal; the basis is recorded per row. *Why:* an equal split would put half of NYC's ~70,000 application developers into QA analysts (~6,000).

**D13 · Small jobs the state doesn't publish for NYC.** 116 of the jobs that matter for the major-to-job link have no NYC projection. *Choice:* estimate NYC openings as national openings × New York's share of national employment, flagged. *Why:* weighting them at zero would silently shift graduates onto the large published jobs.

## Linking majors to jobs

**D2 · The federal crosswalk links majors to too many jobs.** In the CIP–SOC crosswalk (NCES and BLS), 28% of the links, weighted by graduates, point to college teaching jobs, and Liberal Arts links only there. *Choice:* a job counts for a major at a given degree level if BLS's typical entry education is that level, or if at least 15% of the job's workers hold it (tested at 10% and 20%). A major's graduates are split across its jobs by NYC openings, with an equal split as the other end of a range. Majors left with no job are labeled as transfer pathways. *Why:* it keeps the link to jobs a graduate can actually start in.

**D20 · Testing the link against where graduates actually work.** I compared each field's share of young bachelor's holders in its linked jobs with the share for all bachelor's holders (ACS). For five fields, including Psychology (1.03×) and Criminal Justice (1.40×), graduates sit in those jobs at about the population rate. *Choice:* a third link status, "dispersed," and those majors don't count as supply for any one job. *Why:* a crosswalk says what a program prepares for; the census says where people end up. Where they disagree, the report says so.

**D57 · A code mismatch hid four jobs' majors.** The crosswalk links majors to detailed codes, but BLS rates 28 of those only as groups (Clinical Laboratory Technologists and Technicians, for example). Four study jobs showed "no major linked." *Choice:* resolve detailed codes to their BLS group, and count a group linked only in part by that part's share. The pinned dbt tests were updated with the verified new counts.

## Being honest about uncertainty

**D17 · Survey data has small cells.** At field × detailed job, only 45 of 7,086 ACS cells reach 30 responses. *Choice:* four coarser cuts that keep most people, suppression under 30 responses, and 90% margins of error from the 80 replicate weights. *Why:* a number from 12 survey responses shouldn't look like a fact.

**D36 · Small jobs swing wildly.** My NYC estimate for Materials Engineers went from 344 to 50 people (−85%). *Choice:* draw the NYC line only when the estimate is at least 1,000 people in both 2019 and 2025; otherwise show the published metro line and say why. The rule lives in SQL as a flag, not in a visual.

**D45 · Every number answers five questions.** What it is; what kind of number (counted, agency estimate, projection, my estimate, or someone's rating); when and where; compared with what; and how sure. Projections are said with "about" and two significant figures. *Why:* "642 openings a year" reads like a count, but it's a 10-year model average.

**D52 · Which jobs, and who picked them.** The study covers 225 occupations: every one BLS rates as usually starting with an associate's (48) or a bachelor's (177) degree. That's 202 named jobs and 23 "all other" groups. No one picked them by hand. Every page that names them says so.

## Architecture and release

**D9 · dbt for the warehouse.** Notebooks load each source into `staging`; dbt builds `core` and `mart`. *Why:* about 30 core tables depend on each other, and dbt gives build order, tests and lineage out of the box. Hand-ordered SQL with home-made asserts would rebuild half of dbt.

**D23 · The mart is a small star schema.** Thin, conformed dimension views (`dim_job`, `dim_major`, `dim_college`, `dim_cluster`, …), bridge tables for the many-to-many career clusters, and fact views at each page's grain, with the business rules applied in SQL. *Why:* Power BI's slicers can be shared across pages only through shared dimensions, and the rules stay testable in one place instead of being spread through DAX.

**D22 · "Similar jobs" needs one fixed measure.** For jobs with high AI exposure, the job page names nearby jobs with lower exposure. *Choice:* the correlation of O\*NET importance ratings across 68 knowledge and skill elements (close at r ≥ 0.75, the O\*NET Center's own approach), paying no more than 10% less. The rule was written before the result was read.

**D58 · A claims audit before release.** I had every claim in the report checked against its source. Among the fixes: the graduate-degree pay premium came from a ratio of averaged medians (32%); a pooled median gives 23%. A comparison share on the Overview was corrected from 41% to 34%.

**D10, D51 · License compliance.** Job-postings data from Revelio Labs informed the exploration (notebooks 32 and 45). Its terms don't allow republishing, so it's out of the published report and this repository. Every source that does ship is credited in [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
