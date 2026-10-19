# How we explore, document and consolidate the data

Written before exploration began. Applies to: everything in this repository.

This is the working method for the v1 rebuild: how each raw source is explored, how the findings are written down, and how the sources are later consolidated into one PostgreSQL database for Power BI. It is built on published practice (sources at the bottom), adapted to this project's data.

---

## 1. Principles

1. **Raw data is read-only.** Every notebook reads `data/raw/` and never writes to it. Provenance (URL, date, SHA-256) lives in `data/raw/manifest.csv`. *Cookiecutter Data Science:* "Don't ever edit your raw data. Especially not manually."
2. One source at a time, the same steps every time. Each source gets its own exploration notebook that follows the template in §3, so any two sources can be compared section by section.
3. Findings are written for people, not left in cell outputs. Each notebook ends with a source card (a short markdown file in `docs/source-cards/`), modeled on *Datasheets for Datasets*: what the data is, how it was collected, what one row means, what it can and can't answer.
4. **Explore before deciding.** Exploration notebooks change nothing. They produce an issues list (issue → rows affected → proposed treatment). Treatments are decided and applied later, in staging.
5. Notebooks must run top to bottom. A study of 1.4M GitHub notebooks found only about 24% ran without errors, mostly because of hidden state and out-of-order execution (Pimentel et al. 2019). Rule: *Restart & Run All* before any notebook is reviewed or committed.
6. **No copy-pasted code across notebooks.** When the same helper shows up in a second notebook, it moves into `src/`.
7. Every number answers five questions before anyone sees it (D45): what it is, what kind of number it is (counted, agency estimate, projection, our estimate, someone's scale), when and where, compared with what, and how sure we are. The kinds table, the rounding by kind and the bias checks are in `design-brief.md` §4.6. This applies to notebook findings and docs as well as the report.

## 2. The overall shape: ELT in four layers

We land files untouched, load them into the database, and transform with SQL. That makes it ELT (extract, load, transform), the pattern dbt and modern warehouses use.

| Layer | What's in it | Where | Rule |
|---|---|---|---|
| **raw** | Files exactly as published + manifest | `data/raw/` (on disk) | Never edited |
| **staging** | One table per source file: renamed, typed, cleaned, filtered to scope | PostgreSQL schema `staging`, tables `stg_<source>__<entity>` | 1:1 with source. Renaming, type casting, basic computations and categorizing are allowed. No joins, no aggregations (dbt staging guide) |
| **core** | Shared dimensions (job, major, industry, area, time, college, career cluster), crosswalk bridges, and facts at a declared grain | schema `core` | Kimball star schema. Every fact row carries its source and release |
| **mart** | One view per dashboard question | schema `mart` | What Power BI reads. No logic in Power BI that belongs here |

We use the layer *idea*, not three physical copies of everything. Critics of "medallion" layering point out that forcing every dataset through every stage wastes storage and adds steps (see sources). Staging can be views, and small reference files can go straight to core.

## 3. Template for every exploration notebook

File name: `NN-at-explore-<source>.ipynb` in `notebooks/` (number, initials, description; Cookiecutter convention).

| # | Section | What it answers | Typical checks |
|---|---|---|---|
| 0 | **Source header** | Publisher, dataset, file(s), retrieved date, edition, license, how it was collected (survey / administrative / model) | Read from the manifest + the publisher's documentation page (linked) |
| 1 | **Load as text** | Can we read it cleanly? | `dtype=str, keep_default_na=False`; row and column counts; encoding |
| 2 | **What one row is** | The grain | State the presumed key → verify it's unique. If it isn't, find out why (summary rows? duplicates? multiple editions?) |
| 3 | **Column profile** | What's in each column | Blank rate, distinct count, top values, value patterns (e.g. `NN-NNNN` for SOC). These are the *single-column* profiling tasks in Abedjan et al. |
| 4 | **Codes, hierarchy and special values** | Which code system and edition (SOC 2010/2018, CIP 2010/2020, NAICS 2017/2022); summary rows; suppression or sentinel markers (`*`, `**`, `#`, `-1`, `N/A`) and what the docs say they mean | Pattern counts per code level; cross-reference with the publisher's documentation |
| 5 | **Coverage** | Which places, years and populations; how big the NYC slice is | Distinct areas/years; NYC row counts; gaps in the time series |
| 6 | **Relationships** | Will it join to the other sources? | Match rate of its codes against the reference lists (e.g. SOC codes vs. the 2018 SOC list); these are the *multi-column / inclusion dependency* checks |
| 7 | **Tie-out** | Do the numbers match what the publisher reports? | One published total reproduced from the file |
| 8 | **Fitness for purpose** | Which brief question it answers, how well, and what it can't do | Against brief §3 and §4 |
| 9 | Issues list + proposed staging table | What has to change, and what the clean table will look like | Table: issue → rows affected → proposed treatment. Then: `stg_` name, grain, key, columns kept, types |

Sections 2, 6 and 7 are where real problems show up. Don't skip them for "simple" sources.

## 4. From exploration to one database

After each source is explored, we fill in the bus matrix in `source-map.md`. It's Kimball's tool for consolidation: rows are the measurements we have (facts), columns are the shared dimensions they can be sliced by. A filled cell means "this fact can be joined to that dimension", which is exactly what the "pick an industry" / "pick a major" → job page design (brief S4) needs.

Then, for each fact table, Kimball's four steps:
1. **Pick the process** (e.g. "NYS DOL projects employment by job").
2. **Declare the grain** (e.g. one row = one job × one area × one projection edition).
3. **Pick the dimensions** that are true at that grain (job, area, edition).
4. **Pick the facts** (base employment, projected employment, annual openings).

We design the PostgreSQL schema only after all v1 sources have source cards (brief O3). Designing it earlier means guessing at grains we haven't verified.

## 5. Tooling decisions

| Decision | Options | When |
|---|---|---|
| What runs the transform step | Decided (D9): B, notebooks for staging + dbt-core for core/mart | Done |
| Data-quality test tool | **dbt tests** for core/mart (follows D9); row-count asserts in the staging load notebooks | Done |
| Schema names | `staging / ref / core / mart` (`schema-design.md`) | Done |

## 6. Research note

**Decision:** How should a portfolio-grade, government-data ELT project organize per-source exploration, documentation and consolidation?

**Found:**
- Raw data immutable; analysis as a DAG; notebooks for exploration but source code for reuse; notebook naming `<step>-<initials>-<description>` ([Cookiecutter Data Science v2](https://cookiecutter-data-science.drivendata.org/), [Opinions](https://cookiecutter-data-science.drivendata.org/opinions/))
- Document every dataset's motivation, composition, collection process and recommended uses, for both the people who build it and the people who use it ([Gebru et al., *Datasheets for Datasets*, CACM 64(12), 2021](https://arxiv.org/abs/1803.09010))
- Profiling splits into single-column (nulls, distinct values, types, patterns) and multi-column tasks (unique column combinations = keys, functional and inclusion dependencies = joins) ([Abedjan, Golab & Naumann, *Profiling relational data: a survey*, VLDB Journal 2015](https://hpi.de/oldsite/fileadmin/user_upload/fachgebiete/naumann/publications/2015/dataprofiling_main.pdf))
- Staging is 1:1 with sources; rename, cast and categorize there; no joins or aggregations; name `stg_[source]__[entity]s`; data moves from "source-conformed" to "business-conformed" ([dbt: How we structure our dbt projects](https://docs.getdbt.com/best-practices/how-we-structure/1-guide-overview), [staging](https://docs.getdbt.com/best-practices/how-we-structure/2-staging))
- Dimensional design in four steps: process → grain → dimensions → facts ([Kimball & Ross via Wikipedia: Dimensional modeling](https://en.wikipedia.org/wiki/Dimensional_modeling), [Holistics: Kimball's dimensional modeling](https://holistics.io/books/setup-analytics/kimball-s-dimensional-data-modeling))
- Counter-evidence: layered "medallion" pipelines get criticized for duplicate copies, forced stages, and being used as a substitute for real modeling ([Modern Data 101](https://moderndata101.substack.com/p/data-products-a-case-against-medallion), [Learn Analytics Engineering](https://learnanalyticsengineering.substack.com/p/why-medallion-architecture-is-not))
- Counter-evidence on notebooks: only ~24% of 864k executed GitHub notebooks ran without error, mainly from hidden state and out-of-order runs ([Pimentel et al., MSR 2019](https://2019.msrconf.org/details/msr-2019-papers/36/A-Large-scale-Study-about-Quality-and-Reproducibility-of-Jupyter-Notebooks))

**Options:**
- **A)** Free-form EDA notebooks, then design the database.
- **B)** Templated per-source exploration + datasheet-style source cards + a bus matrix, then a Kimball star schema in staging/core/mart layers.

**Going with:** B. With ~21 sources from 8 publishers, a fixed template is the only way to compare them. The bus matrix turns "how do we consolidate this?" into a table we fill in as we go. Rejected A because free-form EDA across this many sources produces findings nobody can compare, and it hides grain problems like the mixed projection editions found in notebook 01.

**Confidence:** high on the method; medium on the tooling (§5 is still open). Would change if: a source turns out not to be tabular enough for the template (the NYSED HTML pages may need a lighter version).
