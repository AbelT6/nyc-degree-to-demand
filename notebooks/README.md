# Notebooks

The notebooks run in number order, in three stages: **profile** each raw source (01–16), **load** it into PostgreSQL's `staging` schema (20–36), then **analyze** the finished `core` layer (40–46). The core layer itself is built by dbt (`../dbt`), not here. Each notebook opens with what it does and why, and ends with what it found or loaded. All of them ran top to bottom with no errors.

## Start here

1. [`02-profile-nysdol-projections`](02-profile-nysdol-projections.ipynb): checking the state's official job projections against their own group totals. This is where the defect in the 2022–2032 edition turned up (decision D1).
2. [`23-load-graduates`](23-load-graduates.ipynb): ten years of federal completions data and CUNY's own program file, joined through two hand-built maps, with every load checked against expected row counts.
3. [`42-analyze-supply-demand`](42-analyze-supply-demand.ipynb): graduates against openings for every major, with the "crowded field" rule written down before the results were read.

## 0. Get the data

| # | Notebook |
|---|---|
| 00 | [Download the raw data](00-download-data.ipynb): every file from `src/sources.py`, logged with its URL, date and SHA-256 in `data/raw/manifest.csv` |

## 1. Profile each source (read-only)

| # | Notebook |
|---|---|
| 01 | [Raw data inventory](01-profile-raw-inventory.ipynb): what's on disk, in what format, and how each source was obtained |
| 02 | [NYS DOL long-term occupational projections](02-profile-nysdol-projections.ipynb) (4 NYC editions) |
| 03 | [OEWS wages](03-profile-oews-wages.ipynb) (BLS metro 2018–2025, NYS DOL regional 2026) |
| 04 | [BLS education and training requirements](04-profile-bls-education.ipynb) |
| 05 | [Graduates](05-profile-ipeds-cuny-graduates.ipynb) (IPEDS completions and directory, CUNY programs) |
| 06 | [Crosswalks](06-profile-crosswalks.ipynb) (SOC 2010→2018, OEWS hybrids, CIP 2010→2020, CIP→SOC) |
| 07 | [Industry jobs, pay and output in NYC](07-profile-industry-jobs-output.ipynb) (QCEW, CES, BEA) |
| 08 | [Census QWI](08-profile-qwi-hiring.ipynb): hiring and new-hire pay by industry, age and education |
| 09 | [The industry → job bridge](09-profile-industry-job-bridge.ipynb) (national matrix vs New York research estimates) |
| 10 | [ACS PUMS](10-profile-acs-pums.ipynb): what NYC graduates actually do and earn |
| 11 | [O\*NET 31.0](11-profile-onet.ipynb): skills, knowledge, tools, experience |
| 12 | [CPI-U, New York metro](12-profile-cpi.ipynb), for pay in today's dollars |
| 13 | [National Career Clusters crosswalk](13-profile-career-clusters.ipynb) (Advance CTE) |
| 14 | [AI exposure by job](14-profile-ai-exposure.ipynb) (Eloundou et al.) |
| 15 | [BLS Occupational Outlook Handbook](15-profile-bls-ooh.ipynb): one-line job descriptions |
| 16 | [O\*NET OnLine "In Demand" software](16-profile-onet-in-demand.ipynb): share of job ads per job |

## 2. Load into `staging`

| # | Notebook |
|---|---|
| 20 | [NYS DOL projections](20-load-nysdol-projections.ipynb) |
| 21 | [OEWS wages](21-load-oews-wages.ipynb) |
| 22 | [BLS education requirements and national projections](22-load-bls-education.ipynb) |
| 23 | [Graduates](23-load-graduates.ipynb) (IPEDS, CUNY programs) |
| 24 | [Job and major code references](24-load-crosswalks.ipynb) |
| 25 | [Industry jobs, pay, hiring and output](25-load-industry.ipynb) |
| 26 | [The industry → job bridge](26-load-industry-job-bridge.ipynb) |
| 27 | [ACS PUMS 2020–2024, NYC residents](27-load-acs-pums.ipynb) |
| 28 | [Job content, AI exposure and Career Clusters](28-load-skills-ai-clusters.ipynb) |
| 29 | [CPI-U](29-load-cpi.ipynb) |
| 30 | [A first look at the staged data](30-check-staging.ipynb): a guided tour before any modeling |
| 31 | [Anthropic AI exposure](31-load-anthropic-ai-exposure.ipynb) (observed exposure) |
| 33 | [Indeed Hiring Lab job postings index](33-load-indeed-postings.ipynb) |
| 34 | [BLS JOLTS and LAUS, New York](34-load-bls-jolts-laus.ipynb) |
| 35 | [NYS DOL unemployment insurance beneficiaries](35-load-nysdol-ui.ipynb) |
| 36 | [Job descriptions and O\*NET "In Demand" shares](36-load-ooh-in-demand.ipynb) |

## 3. Analyze `core` (rules written before each notebook ran)

| # | Notebook |
|---|---|
| 40 | [Which jobs is NYC adding?](40-analyze-jobs-demand.ipynb) |
| 41 | [Which industries are growing or shrinking?](41-analyze-industries.ipynb) |
| 42 | [Graduates vs openings, and the crowded-field grid](42-analyze-supply-demand.ipynb) |
| 43 | [What it takes to get in, what a beginner earns, how hard it is to get hired](43-analyze-entry.ipynb) |
| 44 | [What graduates actually do, and the census test of the major → job link](44-analyze-grad-outcomes.ipynb) |
| 46 | [AI exposure by major, and the nearest lower-exposure job with comparable pay](46-analyze-ai-majors.ipynb) |

Notebooks 32 and 45 used job-postings data from Revelio Labs, whose terms don't allow republishing it, so they aren't in this repository.

Question and scope codes in the notebooks (Q1–Q5, S1–S13, O1–O5) refer to the [project brief](../docs/project-brief.md); D-numbers refer to [decisions](../docs/decisions.md).
