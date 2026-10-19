# Source map and bus matrix

Built from the notebook 01 first look; every row confirmed by notebooks 02–14. A ✓ means the source's own notebook confirmed the link. Method: `framework.md` §4.

## 1. What each v1 source is for

| # | Source (key in `src/sources.py`) | Answers | One row = (to verify) | Format · how we get it | Explore in |
|---|---|---|---|---|---|
| 1 | NYS DOL projections (`nysdol_projections`, `_archive`) | Q1 growing/shrinking jobs, openings | area × edition × job | CSV · Socrata + Wayback | 02 |
| 2 | BLS OEWS metro (`bls_oews_metro`) | Q1 jobs over time, Q4 pay over time | area × job × year | xlsx in zip · bulk | 03 |
| 3 | NYS DOL wages (`nysdol_oews_regions`) | Q4 starting pay in NYC | area × job (one vintage) | CSV · Socrata | 03 |
| 4 | BLS education & training (`bls_ep_education`) | Q2 degree / experience each job needs | job (national, one edition) | xlsx · bulk | 04 |
| 5 | IPEDS completions + directory (`ipeds_*`) | Q3 graduates per major per year, all NYC colleges | college × major × major number × award level × year | CSV in zip · bulk | 05 |
| 6 | CUNY Programs (`cuny_programs`) | Q3 CUNY graduates to 2024-25 | program (IRP × college × award) × measure × period | CSV · Socrata | 05 |
| 7 | CIP→SOC, CIP 2010→2020, SOC 2010→2018, SOC 2018 structure, OEWS hybrids (`nces_cip`, `bls_soc_crosswalk`, `bls_soc_structure`, `bls_oews_hybrid`) | Bridges: major ↔ job, old ↔ new codes | code pair | xlsx / CSV · bulk | 06 |
| 8 | QCEW (`nysdol_qcew_annual`) | Q1 employers and jobs by industry and borough | area type × area × ownership × industry × year | CSV · Socrata | 07 |
| 9 | QWI (`census_qwi`) | Q1/Q4 hiring by industry, age, education | county × industry × age or education × quarter | CSV.gz · bulk | 08 |
| 10 | CES (`nysdol_ces`) | Q1 monthly jobs by industry | area × series × month | CSV · Socrata | 07 |
| 11 | BEA county GDP (`bea_county_gdp`) | Q1 industry output by borough | area × industry line (years wide) | CSV in zip · bulk | 07 |
| 12 | BLS industry → job matrix (`bls_ind_occ_matrix`) | 2035 shares inside an industry, self-employed (national) | industry × job (national) | xlsx · bulk | 09 |
| 12a | BLS OEWS research estimates, NY (`bls_oews_research`) | **Bridge: industry ↔ job (S4)**, NY staffing patterns 2019–2025 | NAICS × NAICS level × job × year | xlsx · bulk | 09 |
| 12b | BLS QCEW county files (`bls_qcew_county`) | NYC government jobs by sector (for the bridge) | county × ownership × industry × year | CSV · BLS open data | 09 |
| 13 | ACS PUMS (`acs_pums`) + published tables for the tie-out (`acs_summary_tables`) | Q2/Q4 what NYC grads actually do and earn; S11 underemployment; O1 young-worker share | person (`SERIALNO + SPORDER`) | CSV in zip · bulk | 10 |
| 14 | O*NET 31.0 (`onet`) | Q2 skills, knowledge, software per job; O1 newcomer share; S12 join key | job × descriptor × scale (national; SOC = first 7 characters) | CSV in zip · bulk | 11 |
| 15 | CPI-U NY metro (`bls_cu`) | Q4 real (inflation-adjusted) pay | series × period (`M13` = annual average) | tab-separated text · bulk | 12 |
| 16 | Career Clusters crosswalks, Advance CTE (`career_clusters`) | S6 umbrellas (cluster → sub-cluster → job / sector), S7 featured areas | job × sub-cluster, major × sub-cluster, sector × sub-cluster (links only, no counts) | xlsx · bulk | 13 |
| 17 | AI exposure, Eloundou et al. (`eloundou_ai_exposure`, D7) | S12 AI exposure per job | O*NET job × task ; job scores rebuild exactly | CSV/TSV · GitHub, pinned commit | 14 |

The order follows brief §9. Numbers can shift if a source needs splitting.

## 2. Bus matrix: facts × shared dimensions

Rows are the measurements, and columns are the dimensions every table should share (conformed dimensions). A filled cell means the fact can be sliced by that dimension.

| Fact (measurement) | Job (SOC) | Major (CIP) | Industry (NAICS) | Area | Time | College | Age / education | Career cluster* |
|---|---|---|---|---|---|---|---|---|
| Projected employment & openings | (+ projection-aggregate bridge) | | | NYC region | edition | | | via SOC |
| Employment & pay over time | (SOC 2010 / hybrid / 2018) | | (cross-industry) | NY metro, not NYC | year | | | via SOC |
| Entry / median / experienced wage | ✓ | | | NYC (5 boroughs) | one vintage (2026Q1 wages) | | | via SOC |
| Entry requirements (education, experience, training) | (joins all NYC wage jobs) | | | US only | edition 2025 | | | via SOC |
| Degrees awarded | | (CIP 2010 to 2019, CIP 2020 from 2020) | | NYC (each year's directory) | award year 2015–24 (2024 provisional) | UNITID, CUNY = `F1SYSCOD` 136010 | award level | via CIP (97.1% of 2024 awards link to a job) |
| CUNY graduates & enrollment | | (CIP 2020, history recoded) | | NYC | AY 2008–25 / Fall 2008–25 | 26 units → 20 UNITIDs (hand map) | award level (mapped from 55 award names) | via CIP |
| Establishments, jobs, wages by industry | | | ✓ | borough | year | | | via NAICS |
| Hires & separations | | | sector | borough | quarter | | ✓ | via NAICS |
| Monthly jobs by industry | | | supersector | NYC | month | | | via NAICS |
| GDP by industry | | | line code | borough | year | | | via NAICS |
| What grads actually do & earn | (62% exact SOC; groups via `ref_socp_soc`) | bachelor's+ only, needs hand-built FOD1P→CIP | NAICS sector (first 2 chars) | NYC residents, borough / PUMA | 2020–24 pooled (one period) | | age × degree level | via SOC/CIP |
| Skills per job | (O*NET-SOC → SOC, 98.4% of NYC employment) | | | US only | release 31.0 | | | via SOC |
| AI exposure (research estimate, D7) | (O*NET-SOC → SOC, pooled tasks; 99.0% of NYC employment) | via major → job (D2) | | US only (task-based) | one edition (2023 labels) | | | via SOC |
| Prices | | | | NY metro | month | | | |

\*Career cluster attaches through the Advance CTE crosswalk (nb 13): jobs and sectors directly; majors through their D2-filtered jobs (D6) (Advance CTE's own CIP → cluster file carries the professor problem).

**Bridges (many-to-many):** major ↔ job (CIP→SOC crosswalk), industry ↔ job (OEWS research estimates for New York; BLS matrix for 2035, nb 09), SOC 2010 → 2018, CIP 2010 → 2020, O*NET-SOC → SOC, and ACS FOD1P → CIP (hand-built, brief O5).

What the matrix already tells us: Job (SOC) is the dimension with the most facts on it, which confirms brief S4 ("the job is the center"). Majors reach jobs only through the CIP→SOC bridge, and industries only through the BLS matrix. Those two bridges carry the whole "two ways in" design, so they get the most careful exploration (notebook 06).

**Confirmed so far (notebooks 02–03):** the hybrid / projection-aggregate SOC codes (`15-1256`, `13-2098`, `13-1198` …) show up in both the projections and OEWS 2019–20, so notebook 06 builds one code bridge (SOC 2010 → hybrid → SOC 2018) for both sources. And the "Area" dimension needs two kinds of area that must never be mixed up: the NYC region (projections, NYS DOL wages) and the New York metro (BLS OEWS), which is about twice as big.

**Confirmed in notebook 04:** BLS entry requirements join every NYS DOL NYC wage job on SOC with no bridge, and 528 of 543 NYC 2022-32 projection leaves. The 15 misses (hybrids like `15-1256`, split codes, suppressed minor groups) are the same ones notebook 06's bridge must handle. A trailing `8` is not a hybrid marker: SOC 2018 has real detailed codes ending in 8 (`29-1218`), so notebook 06 has to use BLS's hybrid list. *(Notebook 06 corrected the other example given here: `21-1018` is a BLS aggregate, not SOC 2018.)*

**Confirmed in notebook 06:** every job code in every NYC slice (projections 2016-26 → 2022-32, OEWS 2018–2025, NYS DOL wages, BLS EP) resolves to SOC 2018 detailed through three bridges: the SOC 2018 structure (groups), SOC 2010→2018, and BLS's hybrid list. Five BLS aggregates (`21-1018`, `25-2052`, `25-9045`, `51-2028`, `53-1047`) are still in the current files, so the job dimension keeps them as rows. Every NYC IPEDS major maps to CIP 2020 one-to-one. Resolved by D2: degree-level filter + openings-weighted / equal split, shown as a range.


**Confirmed in notebook 10:** ACS PUMS joins Job through `SOCP`: 62% of NYC workers on an exact SOC 2018 code, 82% to one BLS entry level once groups and BLS aggregates are resolved, 18% in groups with mixed entry levels (need a rule). Major only for bachelor's+: ACS asks field of degree only of bachelor's holders, so CUNY associate's programs can't be checked against what graduates do. No public FOD1P → CIP crosswalk exists, so brief O5's hand-built table is required. It's resident-based (NJ/CT commuters are in other state files).
