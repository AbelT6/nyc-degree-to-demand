-- core.bridge_major_job: detailed CIP 2020 major x award level x SOC 2018 job, for the links that pass the D2 filter
-- at 15% (460 associate's + 3,413 bachelor's = 3,873 rows, D57). Grain: cip_code x award_level x soc_code.
-- Plan: docs/step2b-major-bridges-plan.md §6; decisions D2, D13, D14, D16.
--
-- Two weights per major x level, each summing to 1 over the major's passing jobs (D2: shown as a range):
--   weight_equal     1 / n_jobs_in_major
--   weight_openings  the job's NYC annual openings (int_job_openings_2022) / the sum over the major's passing jobs;
--                    null for the whole group when that sum is 0 (10 associate's and 18 bachelor's majors).
--                    D58: a group job the major is linked to only in part counts its openings x link_part_share.
-- All Other jobs keep their weight and are flagged (is_all_other; D11, D16 option A), so the mart can split
-- named from catch-all jobs without recomputing.

with passing as (
    select *
    from {{ ref('int_major_job_filter') }}
    where passes_filter_15
),

openings as (
    select soc_code, openings_nyc, openings_basis
    from {{ ref('int_job_openings_2022') }}
),

jobs as (
    select soc_code, is_all_other
    from {{ ref('dim_job') }}
),

weighted as (
    select
        p.cip_code,
        p.award_level,
        p.soc_code,
        p.passes_filter_10,
        p.passes_filter_20,
        p.pass_basis,
        p.attainment_pct,
        p.attainment_inexact,
        o.openings_nyc,
        o.openings_basis,
        p.link_part_share,
        sum(o.openings_nyc * p.link_part_share) over (partition by p.cip_code, p.award_level) as openings_in_major,
        count(*) over (partition by p.cip_code, p.award_level) as n_jobs_in_major,
        j.is_all_other
    from passing as p
    join openings as o on o.soc_code = p.soc_code
    join jobs as j on j.soc_code = p.soc_code
)

select
    cip_code || '|' || award_level::text as major_award_key,
    cip_code,
    award_level,
    soc_code,
    passes_filter_10,
    passes_filter_20,
    pass_basis,
    attainment_pct,
    attainment_inexact,
    openings_nyc,
    openings_basis,
    case when openings_in_major > 0 then openings_nyc * link_part_share / openings_in_major end as weight_openings,
    1.0 / n_jobs_in_major as weight_equal,
    is_all_other,
    n_jobs_in_major,
    link_part_share
from weighted
