-- core.audit_major_job_filter: the evidence behind the D2 filter for every NCES CIP-SOC link at both in-scope award
-- levels (11,388 rows, D57). Grain: cip_code x award_level x soc_code. bridge_major_job holds only the rows passing at
-- 15%; this table keeps the rest so the exploration step can recompute weights at 10% or 20% in one query.
-- Plan: docs/step2b-major-bridges-plan.md §6 (decision 3); decisions D2, D14, D16.

select
    cip_code,
    award_level,
    soc_code,
    entry_education,
    entry_match,
    attainment_pct,
    attainment_inexact,
    passes_filter_10,
    passes_filter_15,
    passes_filter_20,
    pass_basis,
    link_part_share
from {{ ref('int_major_job_filter') }}
