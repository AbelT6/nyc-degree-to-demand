# Data pipeline

*48 staging tables tie out to their source copies, dbt builds 41 core tables and 35 mart views, and all 1,137 tests pass. I explored the core layer in seven notebooks before designing any page, and the Power BI report (10 pages, including a page for each of the 225 jobs and each of 545 majors) is built and tested. See "Where it stands" at the end.*

This project asks a simple question: when a CUNY student picks a major, how well does it line up with the jobs New York City is actually adding? Answering it means pulling together data that was never meant to be combined. Job projections come from the state, wages from the federal government, graduate counts from the Department of Education and from CUNY itself, and each of these uses its own codes, geographies and calendars. This document covers how I collected that data, what I had to reconcile to make it fit together, and how it gets into PostgreSQL in a form I can trust.

Related docs: [schema-design.md](schema-design.md) for the target data model, [source-map.md](source-map.md) for which source answers which question, [decisions.md](decisions.md) for the main judgment calls, [framework.md](framework.md) for the method, and [docs/source-cards/](docs/source-cards/) for a one-page profile of each source.

## 1. The sources

I started wide. The first pass downloaded 45 candidate datasets (206 files, about 3 GB) covering jobs, hiring, licensing, graduates, outcomes, pay, skills and job postings. I profiled each one, then kept the 19 below for version 1. The rest were dropped because they didn't cover NYC, had too little history, overlapped a better source, or (in the case of job postings) weren't government data. They stay in `data/raw/` in case a later version needs them.

| What it tells us | Source | Coverage | How I got it |
|---|---|---|---|
| Which jobs NYC expects to grow, and annual openings | NYS DOL long-term occupational projections | NYC, four editions: 2016–26, 2018–28, 2020–30, 2022–32 | Socrata API for the current edition. The API only serves the latest one, so I pulled the three older editions from Internet Archive snapshots of the same endpoint |
| Extra 2022–32 columns (entry education, recent wages) | NYS DOL regional projections workbook | NYC, 2022–32 | Excel file from dol.ny.gov |
| Employment and pay by job over time | BLS Occupational Employment and Wage Statistics (OEWS) | New York metro area, May 2018 to May 2025 | Yearly zip archives from bls.gov |
| Entry, median and experienced pay in NYC | NYS DOL occupational wages | NYC (5 boroughs), current release | Socrata API |
| What education and experience each job requires | BLS Employment Projections, education and training tables | National, current edition | Excel from bls.gov |
| Graduates per major at every NYC college | IPEDS completions and institution directory | Award years 2015 to 2024 | Yearly zip files from NCES |
| CUNY graduates and enrollment by program | CUNY programs dataset | Academic years 2008–09 to 2024–25 | Socrata API |
| Which majors lead to which jobs, and old-to-new code mappings | NCES CIP–SOC crosswalk and CIP 2010→2020; BLS SOC 2010→2018, SOC 2018 structure, OEWS hybrid codes | Code tables | Excel and CSV from NCES and BLS |
| Jobs, employers and wages by industry and borough | NYS DOL QCEW | NYC counties, 2000–2025 | Socrata API |
| Government jobs by sector | BLS QCEW county files | The 5 NYC counties | BLS open data files |
| Hires and separations by industry, age and education | Census Quarterly Workforce Indicators (QWI) | NYC counties, quarterly | Compressed CSV from the LEHD site |
| Monthly jobs by industry | NYS DOL Current Employment Statistics | NYC, monthly since 1990 | Socrata API |
| Economic output by industry | BEA GDP by county | The 5 NYC counties | Zip from BEA |
| Which jobs make up each industry | BLS OEWS research estimates for New York; BLS national industry–occupation matrix | NY state 2019–2025; national 2024 and 2034 | Excel from bls.gov |
| What NYC graduates actually do and earn | Census ACS Public Use Microdata (PUMS) | New York residents, 2020–2024 five-year file | Zip from the Census FTP site |
| Skills, knowledge and software for each job | O\*NET 31.0 | National | Zip from the O\*NET Resource Center |
| Inflation adjustment | BLS CPI-U, New York metro | Monthly and annual | BLS flat files |
| Grouping majors, jobs and industries into career areas | Advance CTE Career Clusters crosswalks | Code tables | Excel from careertech.org |
| How exposed each job is to AI | Eloundou et al. (2024), "GPTs are GPTs", *Science* | National, by task | The authors' GitHub repository, pinned to one commit |

### How the download works

Everything is downloaded by one script, `src/sources.py`, run from `notebooks/00-download-data.ipynb`. Each source is declared once with its URL and a short key, and the script saves the file exactly as the publisher released it. I don't clean anything at this stage. For every file it writes a line to `data/raw/manifest.csv` with the URL, the download time, the file size and a SHA-256 hash. If a publisher quietly revises a file later (BEA revises its GDP figures every year, and NYS DOL overwrites its wage table annually), I can tell which version a number came from.

A few things needed work. bls.gov rejects requests that don't look like they come from a browser, so the script sends a descriptive user agent with normal browser headers. Socrata datasets are exported in full through their CSV endpoint. The archived projection editions use the Wayback Machine's raw-snapshot URLs, which return the original file and not the archive's HTML wrapper. When I pulled NYC payroll data, I left out employee names on purpose.

## 2. Profiling each source before loading it

Before writing any load code, I explored each source in its own notebook (`notebooks/01` to `14`) and wrote down what I found in a source card. Every card follows the same template: what one row means, which years and areas it covers, which codes it uses, a list of known problems, and the exact tables to build from it. The load step then builds what the card says, so the reasons behind each cleaning rule are written down before the rule exists.

Some of what turned up:

- The 2022–32 NYC projections publish some jobs only under combined codes, so they can't be compared with earlier editions job by job. I wrote a documented rule to split them back out (decision D1). Each filled-in row will carry a flag saying it was estimated, not published.
- There is no published count of NYC jobs by occupation over time. BLS publishes one for the New York metro area, which is about twice the size of the city. I decided to estimate NYC numbers from city industry employment combined with New York staffing patterns, label them as estimates, and show the metro figure beside them (D8).
- A job code ending in 8 isn't always a temporary "hybrid" code, because SOC 2018 has real codes that end in 8. Identifying hybrids has to use BLS's official list, not a pattern.
- The Census survey only asks about field of degree for people with a bachelor's or higher. That means it can't check where CUNY associate's graduates end up, and the dashboard has to say so.

## 3. What has to be reconciled

Most of the engineering effort goes here. The sources agree on what they measure but not on how they label it.

**Job codes.** The sources use six different code systems: SOC 2010, SOC 2018, the temporary hybrid codes BLS used in 2019 and 2020, a handful of BLS combined codes still in current files, O\*NET's eight-character codes, and the grouped codes in the Census microdata. All of them map to SOC 2018 detailed codes through a set of crosswalks. When one old code splits into several new ones, it gets weights that must add up to 1, and the pipeline checks that they do. Every job code in every NYC slice I tested maps to SOC 2018.

**Major codes.** IPEDS used CIP 2010 until 2019 and CIP 2020 after that. Every NYC major maps one-to-one, so the history lines up. CUNY's own program file uses internal program codes and 55 different spellings of award names, which I mapped to standard award levels. It also reports 26 CUNY units that correspond to 20 federal institution IDs, so I built that mapping by hand. The Census microdata uses its own field-of-degree codes. No public crosswalk from those to CIP exists, so I built one: 78 fields and 142 links, kept as a reviewed CSV in `ref/`.

**Majors to jobs.** The official crosswalk lists every job a major could lead to, including some that need a graduate degree. For an associate's or bachelor's major, I only keep jobs whose typical entry requirement matches the degree. Each graduate is then split across those jobs by NYC openings, with an equal split shown alongside as a range (D2). Industries connect to jobs through New York staffing patterns (D3).

**Geography.** Some sources describe New York City and others the New York metro area. These never get mixed: they're separate rows in the area table, and every number is labeled with its geography. Counties are matched on FIPS codes for the five boroughs.

**Time.** Projection editions, calendar years, quarters, months and academic years all exist in the data. I keep each one as a plain column on the table that uses it.

**Money.** Wages from different years are converted to 2025 dollars using the New York metro consumer price index, so pay can be compared over time.

**Where each number came from.** Every row carries a `source_key` that points back to the publisher, the edition and the file it came from.

The crosswalks and reference tables are loaded as dbt seeds, and the core layer applies them (section 5).

### The hand-built reference tables

Three mappings could not be downloaded, so I built them by hand. They live as CSV files in `ref/`, and `dbt seed` loads them into the `ref` schema:

| Table | Rows | What it maps |
|---|---|---|
| `ref_fod_cip` | 142 | ACS field of degree → CIP 2020 program series (78 fields; each link is `primary` or `partial`) |
| `cuny_unit_unitid` | 26 | CUNY college names in the program files → IPEDS college ID |
| `cuny_award_level` | 55 | CUNY award names (AA, AS, BA, ...) → award level and IPEDS award code |

Codes are stored as text so leading zeros survive (CIP `09.01`). Twelve dbt tests check keys, allowed values and that every college ID exists in IPEDS. Separately, I confirmed that every CIP series in the map exists in the NCES CIP 2020 list, every field-of-degree code appears in the ACS data, and every award name in the CUNY graduate file has a mapping.

## 4. Loading the staging layer

The database is organized in four layers, and each layer has one job:

```
data/raw/          files exactly as published, never edited
   │  load notebooks 20–36 (Python)
   ▼
staging            one table per source entity, cleaned and typed, no joins
ref                hand-built mappings, kept as CSV in git and loaded by dbt
core               dimensions, bridges and facts with all business rules (dbt)
mart               one view per dashboard question; the only layer Power BI reads
```

Notebooks 20 to 36 read the raw files, apply the cleaning rules from each source card, and pass each finished table to one function, `stage()` in `src/staging.py`. Keeping that step in one function means every table gets the same checks:

1. The table's key has to be unique and can't be empty. The row count has to match the number on the source card, and column names have to be lowercase. If any of these fail, the notebook stops.
2. A typed Parquet copy is saved to `data/interim/staging/`. This let me build and review the whole pipeline before the database existed.
3. Inside a single transaction, the table is recreated with explicit PostgreSQL types and bulk-loaded with `COPY`. A primary key is added, the rows are counted again inside the database, and a comment is attached recording the source and the notebook that loaded it. A column that mixes text and numbers is rejected rather than guessed at.
4. A line goes into `_load_log.csv` with the table, row count, key, source, notebook and time.

The result is 48 staging tables with 1,393,258 rows (counted in the database). The largest is the Census microdata at 279,311 people and 108 columns, followed by the New York staffing patterns at 204,386 rows. The last two, loaded by notebook 36 for the job page, are the job descriptions from the BLS Occupational Outlook Handbook and the share of U.S. job ads naming each software, from O\*NET OnLine.

## 5. Building the core layer with dbt

dbt (dbt-core 1.12.5 with dbt-postgres) turns staging into `core`: conformed dimensions, bridges that connect jobs, majors, industries and career clusters, and fact tables at the grain each question needs. I built it in four steps, and each step started with a written plan and a readiness check against the database (`step1-dimensions-plan.md` through `step4-facts-plan.md`). The plan said what the data could and couldn't support before I wrote a model, and each plan ends with an "as built" section that records what changed during the build and why.

`core` holds 41 tables and 707,490 rows: the dimensions (jobs, majors, colleges, award levels, industries, areas, career clusters, sources), the bridges, 19 fact tables (projections, NYC jobs by year, wages, CUNY programs, degree awards, graduate outcomes, entry requirements, skills and software, industry employment, hiring and output, job postings, the labor market, prices) and a few audit tables that keep the inputs of each estimate visible.

The rules that matter most live here, each with a decision record:

- NYC jobs by occupation (D8, D18). No one publishes this series, so the model estimates it from NYC payroll jobs by industry and New York's staffing patterns. Its estimate adds up to the published NYC total in every year, it is labeled as an estimate wherever it appears, and the published metro series sits beside it.
- The 2022–32 projection fill (D1, D15). Jobs the state published only under combined codes are split back out by a written rule, and every filled row is flagged.
- **Majors to jobs (D2, D16).** A major links only to jobs whose entry requirement matches the degree, and each graduate is split across them by NYC openings, with an equal split kept as a second weight.
- Majors whose graduates spread out (D20). I tested the major-to-job links against where NYC graduates of each field actually work (Census microdata). For five large fields, including Psychology, Political Science and Criminal Justice, graduates held the linked jobs at close to the rate of all bachelor's holders (a lift under 1.5; Psychology's was 1.0), so the link carried little information. Those majors are marked "dispersed" and aren't counted as supply for any one job.

## 6. Exploring before designing

Before designing a single page, I read `core` in seven notebooks (40 to 46), one per question from the project brief: jobs, industries, graduates against openings, entry requirements and pay, graduate outcomes, AI exposure against job postings, and AI exposure by major. The rules for each analysis, including the cutoffs for labels like "crowded", were written down before the notebook ran (`explore-plan.md` §3), so a result couldn't move its own goalposts.

The exploration changed the design in ways I wouldn't have guessed:

- The pre-registered "crowded field" box (shrinking jobs, many graduates) turned out nearly empty. The real signal was growing jobs that still get more graduates than openings, so that box got its own wording (D19).
- The major-to-job test above produced the "dispersed" rule (D20).
- Three breaks in published series turned up that the data itself doesn't flag. One was a job-tagging change in the job postings data in Aug 2025: Healthcare Practitioners fell 34% in one month. Another was an employer reclassification that recorded about 128,000 "new hires" in Transportation in one quarter of 2024, where a normal quarter has 15,000 to 45,000. The third was New York's move of its home-care program to a single employer in April 2025, which shows up as about 260,000 hires and 277,000 separations in one quarter with flat employment. Each is now a footnote, and the postings comparison starts after its break (D21), so none of them reads as a finding.
- The overview's headline counts only jobs with a 2019 NYC figure, so the comparison is like for like: degree-level jobs +204,310 (+16.8%) since 2019, all other jobs −53,310 (−1.6%) (D37).

## 7. The mart

The `mart` schema is the only thing Power BI reads. It holds 35 views: a small star of conformed dimensions plus one view at the grain of each page (D23), for example `hottest_jobs` for the two jobs lists, `job_profile` for the job page and `overview_kpi` for the overview's numbers. The business rules stay in SQL. The report's measures mostly pick and format values, and the few calculations they do (a percent change between two years, for example) are tied out against SQL.

Caveats are data too. Every footnote lives in a hand-written seed (`ref_footnote`) and fans out to the pages it belongs on in `mart.footnote`. The report reads its footnotes from there instead of typing them, so a note can't drift from the data behind it, and the report's Notes page lists each one in full.

## 8. Database setup and access

`sql/00_setup_database.sql` creates the database, the four schemas and two roles. It can be run again without breaking anything. `pipeline_writer` owns and builds everything. `powerbi_reader` can connect and read the `mart` schema and nothing else, including views dbt adds later. Passwords live in a git-ignored `.env` file and are passed to `psql` when the script runs, so they never appear in code or in git history.

### Installing PostgreSQL on Windows

The usual route is the EDB graphical installer, run silently through `winget`. On my machine it failed every time with "Installer initialization failed", before it wrote a log, even from an elevated shell and with VBScript working. Rather than keep debugging a third-party installer, I used EDB's official binaries zip for the same version (18.6):

1. Extract the server and command-line tools to `C:\PostgreSQL\18` (pgAdmin and Stack Builder left out).
2. `initdb` a cluster in `C:\PostgreSQL\18\data` with UTF-8 encoding, password authentication (`scram-sha-256`), and the superuser password read from `.env` through a temporary file that is deleted right after.
3. Give the `NetworkService` account modify rights on the data folder, then register it as an auto-start Windows service with `pg_ctl register`. That's the same setup the installer would have produced.

This is the only step that needed administrator rights.

dbt (dbt-core 1.12.5 with dbt-postgres 1.11) loads the `ref` tables and will build the `core` and `mart` layers. All 46 staging tables are already declared as dbt sources, with their grain and row count, so lineage can be followed from a dashboard number back to a raw file.

## 9. Testing

Before setting up the real database, I ran the whole load against a temporary PostgreSQL 16 instance and checked:

- The setup script ran twice without errors.
- All 37 tables loaded in about 12 seconds, each with its primary key and comment.
- Row counts, column totals and non-null counts in the database matched the Parquet copies exactly.
- The Power BI role was refused access to `staging` and `public`.
- `dbt debug` passed, and all 37 dbt sources matched a loaded table.
- None of the load notebooks had errors or unrun cells.
- The reference CSVs had no duplicate or blank keys.

### A bug the test caught

The test turned up one real bug. A table could load, pass its row-count check inside the database, and then vanish when the connection closed.

The cause was how psycopg handles transactions. By default, the first query on a connection quietly opens a transaction. If anything queried the connection between two loads, every later load became a savepoint inside that open transaction instead of committing on its own. Closing the connection rolled all of them back. The row-count check didn't catch it, because it ran inside the same transaction and could see the uncommitted rows.

The fix was to open the connection in autocommit mode, so each load is its own committed transaction. The existing notebooks never ran queries between loads, so they weren't affected. But any tie-out query run during QA would have made data disappear with no error.

### Production load

After installing PostgreSQL 18.6, I ran the setup script and re-ran notebooks 20 to 29 against it. The whole load took about 14 minutes, most of it spent reading seven large Excel workbooks in notebook 26. A separate tie-out script then compared the database with the Parquet copies table by table:

- 37 of 37 tables present, each with a primary key.
- 1,075,888 rows in total, matching the Parquet copies table by table.
- Non-null counts for every column, and the sum of every numeric column, match the Parquet copies.
- `powerbi_reader` is refused on `staging` and can't create objects in `public`.
- All ten load notebooks saved with no errors and no unrun cells.

### Two added sources

Notebooks 31 and 32 staged the two sources added after the readiness check, through the same `stage()` function:

- **Anthropic AI exposure:** 756 jobs and 17,992 tasks. Every job code is a detailed SOC 2018 job. The task file has no job codes, but every task's text matches a task in the Eloundou table, which does have them, so the scores can be rebuilt from tasks later.
- **Revelio postings:** 22,899 New York rows (month × sector × job group). Before filtering to New York, I checked that the 51 states add up exactly to Revelio's U.S. file in all 1,368 month × job group cells, and that the latest three months match its published summary table.
- Profiling found a break in Aug 2025. In one month, healthcare postings fell by a third and office and protective-service postings rose by a fifth, in New York and nationally. This looks like Revelio changing how it tags jobs. The data is staged as published, and the break is logged on the source card to handle in the mart.
- The tie-out script then passed on all 40 tables (1,117,535 rows), and `dbt build` passed 15 of 15.

### Labor market context

Notebooks 33 to 35 added four context sources that had been downloaded but not loaded. Each has its own check:

- **Indeed job postings index** (U.S. total, 47 job categories, New York State, New York metro; daily since Feb 2020): every one of the 98 series reads exactly 100 on the base day, with no missing or repeated days. This is the national check that decision D10 calls for.
- **JOLTS** (openings, hires, quits; U.S. and New York State, 2015+): the annual values match their 12 months. Profiling caught that BLS's annual figure is a 12-month *total* for hires and separations but an *average* for openings and rates. A first check that assumed averages everywhere was off by 74 million, so the table now labels each annual row as a total or an average.
- **LAUS** (labor force and unemployment for NYC, its 5 boroughs, the metro and the state, 2015+): NYC matches the sum of its 5 boroughs within 3 people in all 450 month × measure cells.
- **UI beneficiaries** (all 62 counties, monthly since 2001): complete grid of 64 areas × 308 months, and every value is a multiple of the publisher's stated rounding.
- October 2025 is missing from JOLTS and LAUS because of the federal shutdown. It is stored as NULL with BLS's footnote, not filled.
- The tie-out then passed on all 46 tables (1,391,350 rows), and `dbt build` passed 15 of 15.

### Core and mart

From step 1 of `core` on, every model ships with its tests in the same change. A full `dbt build` loads 20 seeds and builds 41 tables and 35 views in under three minutes, and all 1,137 tests pass. The tests are of two kinds:

- The standard checks on every model: unique and non-null keys, relationships to the dimensions, allowed values.
- 149 hand-written SQL tests that tie numbers back to their sources or to each other. Some examples: NYC first-major degree awards for 2024 match the IPEDS totals (associate's 18,490, bachelor's 54,735; CUNY 11,402 and 23,437), and no award is lost between staging and the fact table; the NYC job estimate's rows match the estimate fact year by year; each number on the overview reproduces the result of the exploration notebook it came from, within a stated tolerance; each footnote reaches at least one page; and the job page's wording keys agree with each other (the sentence under the majors list never contradicts the ratio card above it).

The report adds its own layer of tests on top of this: DAX tie-outs against SQL and a sweep of every job and major page (results in the [README](../README.md#how-its-tested)).

## 10. Running it yourself

```
1. Download the raw data      notebooks/00-download-data.ipynb
2. Set up the database        psql -U postgres -v writer_pw=... -v reader_pw=... -f sql/00_setup_database.sql
3. Load staging               run notebooks/20 to 36 in order
4. Build core and mart        export PG_PIPELINE_PASSWORD=...; cd dbt; dbt build
5. Open the report            powerbi/cuny_degree_demand.pbip in Power BI Desktop, then Home > Refresh
```

All five steps have been run end to end against PostgreSQL 18.6. The report connects as `powerbi_reader`, so it can only see the `mart` views.

