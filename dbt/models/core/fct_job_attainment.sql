-- core.fct_job_attainment: BLS Employment Projections Table 5.3, educational attainment of workers 25+ by occupation,
-- as published (one edition, 2023-24 ACS pooled years). Grain: soc_code x attainment_level (7 levels per job).
-- Plan: docs/step4-facts-plan.md §3b (design), §4 item 5 (tie-outs). No decision rule: values land as published.
--
-- Every staging soc_code is a SOC 2018 code already in dim_job (832 codes incl. 00-0000 "all occupations"), so no
-- bridge is needed. pct_of_workers is the published share (sums to 100 +- 0.2 per job, as BLS rounds); acs_inexact
-- marks jobs whose share BLS borrowed from a broader Census occupation. Unrounded numerics; the mart rounds.

with src as (
    select * from {{ source('staging', 'stg_bls__ep_attainment') }}
)

select
    soc_code,
    attainment_level,
    attainment_rank,
    pct_of_workers::numeric as pct_of_workers,
    acs_inexact,
    edition,
    attainment_years,
    'bls_ep_education' as source_key
from src
