# Source card: NYS DOL long-term occupational projections (NYC)

**Explored in:** `notebooks/02-profile-nysdol-projections.ipynb` · Verdict: use with limits (the current edition has a publisher defect; fill decided: C + D)

## 1. What it is
- **Publisher / dataset:** NYS Department of Labor, *Long-Term Occupational Employment Projections* (data.ny.gov `pqm4-9qqb`)
- **Files:** `jobs/nysdol_projections/pqm4-9qqb_2026-10-12.csv` (NYC 2022-32) and 3 Wayback captures in `jobs/nysdol_projections_archive/` (NYC 2016-26, 2018-28, 2020-30)
- **Retrieved:** 2026-10-12 · Editions: 2016-26, 2018-28, 2020-30, 2022-32 (published every 2 years; the portal keeps only the latest)
- **How it was collected:** a model: industry projections × OEWS staffing patterns, with openings from the BLS separations method ([technical notes](https://dol.ny.gov/long-term-occupational-projections-technical-notes), [BLS separations](https://www.bls.gov/emp/documentation/separations.htm))
- **Covers:** jobs (not people) by employer location, NYC as one region. Whether self-employed workers are included isn't stated. Immigration, new occupations and shocks aren't modeled
- **License / terms:** NY Open Data
- **Documentation:** links above, plus the [projections page](https://dol.ny.gov/long-term-occupational-projections)

## 2. Shape
- **Rows × columns:** ~6,600–6,760 per file × 11. NYC: 655 / 637 / 626 / 657 rows by edition
- **One row =** SOC code × edition (NYC). Key `edition + SOC` is unique after dropping 1 exact duplicate
- **Codes used:** SOC 2010 (2016-26, 2018-28) and SOC 2018 (2020-30, 2022-32), plus BLS projection-aggregate codes ending in 8 (e.g. 15-1256, 13-2098)
- **Time span:** base 2016 → projected 2032, in 10-year windows
- **NYC slice:** `Area = 'New York City'`. Each file also carries statewide rows from the *next* edition

## 3. Key columns
| Column | Meaning | Type | Notes |
|---|---|---|---|
| `Period` | Edition, e.g. `2022 - 2032` | text | Spacing varies by edition |
| `SOC` | Occupation code, any level | text | Leading `'` in the 2016-26 and 2018-28 files; levels stacked |
| `Base Year` / `Projected Year` | **Employment** in the base and projected year | int | Misleading names. Rounded to 10s; NYC minimum 250 |
| `Change`, `Percent` | 10-year change | int / num | Negative for declining jobs |
| `Total Annual Openings` | Growth + separations, 10-year average | int | Exact identity in 2020-30 and 2022-32; ±10 in older editions |
| `Growth` / `Replacement Annual Openings` | Change ÷ 10 / exits + transfers | int | Growth is negative for declining jobs |

## 4. What it answers
- **Answers:** Q1, which NYC jobs grow or shrink and how many openings a year (the only NYC-specific projection)
- **Can't answer / limits:** nothing below NYC; no education level; openings are a 10-year average; 2022-32 is defective for aggregate codes; 2020-30 is distorted by its COVID base year

## 5. Tie-out
- Internal identities: exact for 2020-30 and 2022-32; rounding noise (≤10) for 2016-26 and 2018-28
- Leaves vs total: 98.6% / 98.0% / 97.1% / 92.2% (2022-32 )
- External: Software Developers, NYC 2022-32 = 600 vs NYS DOL wage table (OEWS 2025) = 74,710 
- Official NYS DOL regional xlsx (2022-32, NYC sheet) has the same values (600 / 590 / 730), so the defect is in the publication, not the portal extract
- Published NYC total: 4,850,820 (2022) → 5,435,330 (2032), 605,681 openings/yr, from the official regional xlsx (`data/raw/jobs/nysdol_projections_xlsx/`, downloaded 2026-10-13, key `nysdol_projections_xlsx`). Full tie-out: all 10 regions, every row (NYC 657), base, 2032 and openings identical to the CSV, no rows only in one file. The xlsx is a second publication of the same numbers, so the Tableau check is dropped

## 6. Issues list
See notebook §9 for the full list of 13. The ones that decide design:

| # | Issue | Rows affected | Proposed treatment |
|---|---|---|---|
| 1 | Files mix 2 editions | all | Edition from `Period` on each row |
| 7 | Levels stacked, ragged hierarchy | all | `soc_level` + per-edition `is_leaf`; sum leaves only |
| 8–9 | SOC 2010 vs 2018; projection-aggregate codes | 2 editions; ~10–20 codes each | Map in core via crosswalks (nb 06) |
| 10 | **2022-32 aggregate-code defect** (Software Devs, Financial Analysts, Web Devs collapsed; Project Mgmt and Data Scientists missing; 379k jobs unassigned) | 2022-32 | **Decided: C + D.** Staging flags `publisher_defect`; core fills each group's unassigned residual by NYC OEWS shares × BLS national rates, flagged `imputed` (see `docs/decisions.md`) |
| 11 | 2020-30 COVID base year | 2020-30 | Flag the edition; exclude it from growth rankings by default |

## 6b. Extra columns in the regional xlsx (2022-32 only)
The xlsx adds what the CSV lacks: 2026 wages (mean, median, entry, experienced), BLS entry education / experience / training, most common attainment, NYS DOL "Employment Prospects" (Very Favorable … Very Unfavorable) and the NYS 2020-30 rate. NYC: 540 detailed jobs, 32 with no entry wage, 12 with blank education.
- Employment Prospects is broken for the defect codes: Software Developers, Financial Analysts and Web Developers are rated "Unfavorable" because NYS DOL computed it from the collapsed 600 / 590 / 730 jobs. Load it as published, flag it, and never show it for `publisher_defect` rows.
- Wages and education here duplicate NYS DOL wages (nb 03) and BLS EP (nb 04); those stay the sources of record. Load the xlsx as `stg_nysdol__projections_xlsx` for Employment Prospects and as the tie-out.

## 7. Proposed staging table
- **Name:** `stg_nysdol__occupation_projections`
- **Grain / key:** `(edition, soc_code)`, NYC only
- **Columns:** `edition`, `base_year`, `projected_year`, `soc_code`, `soc_edition`, `soc_title`, `soc_level`, `is_leaf`, `base_employment`, `projected_employment`, `employment_change`, `pct_change`, `annual_openings_avg`, `growth_openings_avg`, `separation_openings_avg`, `quality_flag`, `source_file`
- **Filters:** `Area = 'New York City'`; 2,576 rows in → 2,575 out (−1 exact duplicate)
