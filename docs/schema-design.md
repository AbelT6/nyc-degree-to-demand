# Schema design: PostgreSQL (brief O3)

Built from the 18 source cards (section 7 of each), D1–D7 and the bus matrix in `source-map.md`.

---

## 0. Three facts that shape the design

| Question | Finding | What it means for us |
|---|---|---|
| Can CUNY's Power BI service read a PostgreSQL DB on my laptop? | The PostgreSQL connector "is supported for cloud connection and via virtual network data gateway or on-premises data gateway"; Import and DirectQuery both supported; Npgsql built into Desktop ([Microsoft Learn, updated 2026-10-09](https://learn.microsoft.com/en-us/power-query/connectors/postgresql)) | A DB on a laptop is not reachable from the service without an on-premises gateway (CUNY IT may not allow one). v1 plan: Import mode. The data lives inside the published semantic model; when a source updates (once or twice a year), I refresh in Desktop and republishes. No gateway, no cloud DB. Revisit at O7 if scheduled refresh is wanted (then: gateway, or a hosted Postgres) |
| Does dbt run on our Python 3.14 venv? | PyPI metadata (checked): `dbt-core 1.12.5` and `dbt-postgres 1.11.0` both list Python 3.14 ([dbt-core](https://pypi.org/project/dbt-core/), [dbt-postgres](https://pypi.org/project/dbt-postgres/)). The dbt docs FAQ table still stops at 3.13 ([dbt Python compatibility](https://docs.getdbt.com/faqs/Core/install-python-compatibility)), and a forum post reports a 3.14 crash on an older dbt-core | `pip install --dry-run dbt-core dbt-postgres` in our `.venv` resolves cleanly (dbt-core 1.12.5, dbt-postgres 1.11.0, all wheels except one small sdist). Real install not done yet. Fallback: a separate 3.13 venv only for dbt |
| Which PostgreSQL? | 18.6 is current; `winget show PostgreSQL.PostgreSQL.18` → `18.6-5` (EDB installer, [postgresql.org Windows](https://www.postgresql.org/download/windows/)) | Install PostgreSQL 18 on Windows (needs admin / UAC prompt). Python talks to it with `psycopg 3.3` (has 3.14 wheels) |

## 1. Layers and schemas

| Schema | Holds | Built by | Power BI sees it? |
|---|---|---|---|
| `staging` | One table per source file, typed and filtered to scope, 1:1 with the source card's section 7. No joins, no aggregation | Notebooks (`2x-at-load-<source>.ipynb`): read `data/raw/`, apply the issues list, `COPY` into Postgres, assert row counts | No |
| `ref` | Hand-built tables: `ref_fod_cip` (D4), CUNY unit → UNITID map, award-name → level map | CSV in `ref/` loaded as-is (dbt seeds if dbt) | No |
| `core` | Conformed dimensions, bridges, facts at a declared grain (Kimball). All business rules (D1, D2, D3, D5, D6, CPI deflator, ACS MOE) live here | SQL (dbt models or plain SQL files, see §6) | No |
| `mart` | One view per dashboard question, already filtered to the S10 associate/bachelor's scope and labeled | SQL | **Yes, only this schema**, through a read-only role `powerbi_reader` |

Naming: lowercase snake_case; `stg_<publisher>__<entity>`, `dim_`, `bridge_`, `fct_`; mart views named after the question.

## 2. Conformed dimensions (core)

| Table | Grain / key | Rows (approx.) | Main columns | Notes |
|---|---|---|---|---|
| `dim_job` | one SOC code at any level: `soc_code` | ~1,450 (SOC 2018 structure) + 5 BLS aggregates | `soc_title`, `soc_level` (major/minor/broad/detailed/bls_aggregate), `major_group`, `minor_group`, `broad_group`, BLS EP `entry_education`, `entry_experience`, `entry_training` (+ ranks), O*NET `job_zone`, `onet_rated` flag, AI `ai_beta_gpt4`, `ai_band`, `ai_scored` flag | Hub of the model (brief S4). Entry requirements and AI are single-edition national attributes, so they sit on the dim (type 1) with edition columns |
| `dim_major` | `cip_code` (CIP 2020, `NN.NNNN`) | ~2,850 | `cip_title`, `cip_2digit` + title, `cip_4digit` + title, `has_job_link` | 2010 codes reach it through `bridge_cip_2010_2020` |
| `dim_industry` | `naics_code` | ~25 | `naics_title`, `level` (sector / supersector), `supersector_code` | v1 uses 2-digit sectors (nb 07: NAICS 2022 detail breaks) |
| `dim_area` | `area_key` | ~10 | `area_name`, `area_type` (`nyc`, `borough`, `ny_metro`, `ny_state`, `us`), `county_fips` | NYC and the NY metro are separate rows and never mixed (metro ≈ 2× NYC) |
| `dim_college` | `unitid` | ~120 NYC | `name`, `borough`, `sector`, `control`, `is_cuny`, latest-year directory | Year-specific directory stays in staging |
| `dim_award_level` | `award_level` | ~6 | `label`, `in_v1_scope` (associate, bachelor's) | |
| `dim_career_cluster` | `subcluster_id` | 72 | `cluster_name` (14), `subcluster_name`, `featured_area` (S7: Tech / Health / Business / Education) | |
| `dim_source` | `source_key` | ~20 | publisher, dataset, release/edition, URL, retrieved date, `is_government`, label text | Every fact row carries `source_key` (S13: every number labeled) |

Time stays as plain columns (`year`, `quarter`, `month`, `edition`); Power BI gets a calendar from `mart`.

## 3. Bridges (core)

| Table | Grain | From | Rule |
|---|---|---|---|
| `bridge_job_code` | `source_code_system × source_code → soc_code` with `weight` | nb 06 | SOC 2010, OEWS hybrids, BLS aggregates, ACS SOCP groups, O*NET-SOC → SOC 2018 detailed. Weights sum to 1 per source code (asserted) |
| `bridge_cip_2010_2020` | `cip_2010 → cip_2020` | NCES | 1:1 for every NYC major (nb 06) |
| `bridge_major_job` | `cip_code × award_level × soc_code` | NCES CIP↔SOC + BLS 5.3/5.4 | **D2**: `passes_filter_10/15/20`, `weight_openings` (NYC annual openings, 2022-32 edition after the D1 fill), `weight_equal`. Weights sum to 1 per major × level (asserted). Majors with no passing job → flag `transfer_pathway` per award level |
| `bridge_industry_job` | `naics_sector × soc_code` | OEWS research NY 2025 + national matrix | **D3**: `share_ny_2025` (headline), `share_us_2035` (projection only), `source_key` |
| `bridge_job_cluster` | `soc_code × subcluster_id` | Advance CTE | **D6** many-to-many, as published |
| `bridge_industry_cluster` | `naics_sector × subcluster_id` | Advance CTE | sectors 54 and 92 sit in two clusters |
| `bridge_major_cluster` | `cip_code × award_level × subcluster_id` | derived | **D6**: clusters of the major's D2-passing jobs |
| `ref.ref_fod_cip` | `fod1p × cip_code` | hand-built | **D4**, 78 fields / 142 links |

## 4. Facts (core)

| Fact | Grain (one row =) | Measures | Source / decision |
|---|---|---|---|
| `fct_job_projection` | edition × area (NYC) × soc_code | base / projected employment, change, annual openings (growth, separation) | NYS DOL; D1 fill for 2022-32 (`quality_flag` published / imputed) |
| `fct_job_employment_wage_annual` | year × area (NY metro) × soc_code | employment, RSE, hourly/annual mean + p10–p90, real 2025 $ columns | BLS OEWS metro 2019–2025, hybrids bridged |
| `fct_job_employment_nyc_est` | year × area (NYC) × soc_code | estimated employment (2019–2025) | **D8**: QCEW NYC sectors × OEWS research NY staffing pattern, same year. Labeled "estimate"; metro OEWS shown beside it |
| `fct_job_wage_nyc` | vintage × area (NYC) × soc_code | entry / median / experienced wage, floor flags | NYS DOL; O4 headline starting pay |
| `fct_job_attainment` | soc_code × attainment_level | % of workers | BLS 5.3 (feeds D2) |
| `fct_job_entry_signal` | soc_code × measure (`bls_experience`, `acs_young_share`, `onet_newcomer`) | value, band, MOE / n | **D5** three estimates side by side |
| `fct_job_skill` | soc_code × element × scale | importance / level, n, SE, suppress | O*NET 31.0, rolled up from O*NET-SOC |
| `fct_job_software` | soc_code × product | hot / in-demand flags | O*NET |
| `fct_degree_awards` | year × unitid × cip_code × major_number × award_level | awards. Graduate counts use 1st major only (the rule nb 05 tied out exactly to CUNY's published counts); 2nd majors kept for a "majors" view | IPEDS 2015–2024 (2024 provisional) |
| `fct_cuny_program` | academic year × cuny_college × irp_code × award_name | graduates, enrollment; `unitid` as an attribute | CUNY Programs (to 2024-25). Key is the CUNY unit, not UNITID: 6 of 26 units (journalism, SPS, …) share a parent UNITID, so a UNITID key would collide |
| `fct_industry_employment_annual` | year × area (borough / NYC) × ownership × naics | establishments, employment, wages | QCEW (NYS DOL + BLS county for government by sector) |
| `fct_industry_hiring_quarterly` | quarter × borough × naics_sector × age group | hires, new hires, separations, new-hire earnings | QWI |
| `fct_industry_employment_monthly` | month × NYC × supersector | employment | CES ("latest months" only) |
| `fct_industry_gdp` | year × borough × line | GDP current / real | BEA (context only) |
| `fct_grad_outcome` | fod × soc_code × age band × degree level (NYC residents) | weighted count, MOE from 80 replicate weights, `n_unweighted`, `suppressed` (< 30 rows) | ACS PUMS; person-level rows stay in staging, only aggregates in core |
| `fct_cpi_annual` | year × area | index, deflator to 2025 | CPI-U NY metro |

**Additivity rule:** many measures can't be summed in Power BI: medians and percentiles (OEWS, NYS DOL wages), shares (BLS 5.3, O*NET), ACS MOEs (estimates add, MOEs don't), and anything through a many-to-many bridge (D6 clusters, D3 industry shares). Each such column is marked non-additive in the model docs, and `mart` pre-computes every cut the pages show instead of letting Power BI aggregate them.

**Grain rule:** every fact gets a `unique` test on its declared key and `relationships` tests to each dimension. Row counts are reconciled to the staging layer and to the published totals already found in nbs 02–14.

### Gap found in review: no NYC job counts over time (brief S10 "actual 5-year growth")

No source has NYC-only employment by job by year. OEWS publishes the NY metro only (checked: the May 2025 MSA file has `35620` and no metro divisions); NYS DOL wages are one overwritten vintage; projections give NYC base-year employment only every two years, across three code systems, with the 2022 base hit by the D1 defect. Options to decide before `fct_job_employment_wage_annual` is final:
- **A)** Show actual growth for the NY metro (OEWS 2019→2025), clearly labeled metro. Simple, published, but not NYC.
- **B)** Estimate NYC jobs by year = NYC sector employment by year (QCEW) × NY staffing pattern by sector (OEWS research, same year, the D3 bridge). This is the same method NYS DOL uses for its projections, and nb 09 tested the pattern against NYC (13.9 index). Labeled "estimate".
- **C)** Compare NYC base employment across projection editions (2018 → 2022): NYC, but only 4 years, COVID in the middle, and it mixes code systems.

Decided (D8): B, with A shown next to it as a check. New fact `fct_job_employment_nyc_est`: year × NYC × soc_code, `employment_est`, `method = 'qcew_x_oews_research'`.

## 5. Mart (sketch only)

The page plan comes after the data part, so this list is a placeholder. It shows that the core above can answer each brief question:

- `mart.job_profile`: one row per job: openings, growth, NYC pay, entry requirements, D5 band, AI band, clusters (Q1, Q2, Q4, Q5)
- `mart.hottest_jobs`: the two S10 lists, associate/bachelor's reachable only
- `mart.major_supply_demand`: graduates per opening as a range (D2 openings-weighted vs equal), all NYC + CUNY
- `mart.crowded_field_grid`: S11 four-box grid, with the cutoffs written down before results
- `mart.industry_trend`: QCEW / QWI / CES by sector and borough (S8 label "employers in this area")
- `mart.grad_outcome`: ACS check of what NYC grads actually do, with MOE

## 6. What runs the core and mart SQL (framework §5): dbt, decided (D9)

**Options:**
- **A) Plain SQL files** run in order by a notebook (a build notebook), with checks as SQL asserts in the notebook. Fewest moving parts.
- B) dbt-core + dbt-postgres for core and mart (staging loads stay in notebooks). Built-in `unique`, `not_null`, `relationships` and `accepted_values` tests cover the double-check table, and the generated lineage docs show a recruiter the whole flow. Costs one tool to learn and a `profiles.yml`. It is SQL files, not Python scripts, so it doesn't break the "notebooks for Python" rule.

**Recommendation: B.** About 30 core tables with many joins and several rules (D1, D2, D6) depend on each other, so the dependency order and tests matter. dbt does both, and it is the standard tool for the "PostgreSQL → Power BI" skill the brief wants to show. Rejected A because hand-ordering 30 files and writing our own test runner rebuilds half of dbt badly. Would change if: dbt fails on Python 3.14 in the test install (then use a 3.13 venv for dbt only, or fall back to A).

## 7. Security and access

- Superuser `postgres` only for admin. Role `pipeline_writer` owns `staging/ref/core/mart`.
- Role `powerbi_reader`: `USAGE` + `SELECT` on `mart` only. Power BI never sees staging or core.
- Listen on `localhost` only (the default). Passwords live in a git-ignored `.env`, never in the repo.
