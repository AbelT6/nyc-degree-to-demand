{{ config(materialized='ephemeral') }}
-- core.int_grad_outcome_person_cut (ephemeral): the ACS PUMS person rows behind fct_grad_outcome, landed on dim_job
-- and expanded to one row per person x job part x age band x cut. fct_grad_outcome aggregates these; the singular
-- tests recompute group totals from here (suppressed fact rows carry null workers).
-- Plan: docs/step4-facts-plan.md §3e, §6.1; decisions D2 (the link check), D4 (ref_fod_cip), D5 (suppression at n < 30).
--
-- Population: NYC residents (every staging row), employment_status 1 or 2 (civilian employed), not enrolled, socp
-- present. Period 2020-2024 (one pooled 5-year file; weights are the period average).
--
-- Job landing (two paths, together 100% of employed persons):
--   direct     left(socp, 2) || '-' || right(socp, 4) is a dim_job.soc_code (463 codes; detailed, or a broad / minor
--              group where the Census code is a group) -> part_weight 1
--   allocated  else bridge_job_code rows with code_system = 'acs_socp' (57 Census group codes split onto their parts
--              by weight) -> one row per part, part_weight = weight; is_allocated = true
-- A person's contribution to a target row is weight x part_weight, and the same with each replicate weight.
--
-- Age bands 22-27, 28-34, 22-34, 35-64 (a person aged 22-34 is in two bands; ages 16-21 and 65+ are in none).
-- Cuts (group_1 x group_2):
--   field_x_soc_major  fod1 x the landed job's major group (bachelor's and graduate holders only: fod exists only there)
--   degree_x_soc       'all' x the landed soc_code (all four degree levels)
--   field_total        fod1 x 'all'
--   field_x_linked     fod1 x linked / not_linked / job_not_detailed, for the 78 fields in ref_fod_cip. A job is
--                      linked when bridge_major_job has a bachelor's-level (award_level 5) row for that soc_code whose
--                      cip_code is, or is under, one of the field's cip2020 codes. A broad or minor landing cannot be
--                      judged (bridge_major_job is detailed), so it is job_not_detailed rather than not_linked.
-- is_ftyr = full-time year-round (usual_hours >= 35, weeks_worked >= 50, a 1-52 count) with positive earnings; the
-- earnings measures are computed on these rows only.

with persons as (
    select
        serialno || '-' || sporder as person_id,
        age,
        degree_level,
        fod1,
        socp,
        weight::numeric as weight,
        {% for r in range(1, 81) %}
        pwgtp{{ r }}::numeric as pwgtp{{ r }},
        {% endfor %}
        earnings_2024usd::numeric as earnings_2024usd,
        (usual_hours >= 35 and weeks_worked >= 50 and earnings_2024usd > 0) as is_ftyr,
        fod_imputed,
        occ_imputed,
        wage_imputed
    from {{ source('staging', 'stg_census__acs_pums_person') }}
    where employment_status in ('1', '2')
      and not enrolled
      and socp is not null
),

codes as (
    select distinct socp from persons
),

direct as (
    select c.socp, d.soc_code
    from codes as c
    join {{ ref('dim_job') }} as d on d.soc_code = left(c.socp, 2) || '-' || right(c.socp, 4)
),

landing as (
    select socp, soc_code, 1::numeric as part_weight, false as is_allocated
    from direct
    union all
    select b.source_code as socp, b.soc_code, b.weight::numeric as part_weight, true as is_allocated
    from {{ ref('bridge_job_code') }} as b
    where b.code_system = 'acs_socp'
      and b.source_code in (select socp from codes)
      and not exists (select 1 from direct as d where d.socp = b.source_code)
),

landed as (
    select
        p.*,
        l.soc_code,
        l.part_weight,
        l.is_allocated,
        j.major_code,
        j.soc_level
    from persons as p
    join landing as l on l.socp = p.socp
    join {{ ref('dim_job') }} as j on j.soc_code = l.soc_code
),

bands as (
    select * from (values ('22-27', 22, 27), ('28-34', 28, 34), ('22-34', 22, 34), ('35-64', 35, 64))
        as v (age_band, age_lo, age_hi)
),

fields as (
    select distinct fod1p from {{ ref('ref_fod_cip') }}
),

-- (field, detailed job) pairs that D2 links at the bachelor's level, through the D4 field -> CIP table.
linked_pairs as (
    select distinct r.fod1p, m.soc_code
    from {{ ref('ref_fod_cip') }} as r
    join {{ ref('bridge_major_job') }} as m
      on m.award_level = 5
     and (m.cip_code = r.cip2020 or left(m.cip_code, length(r.cip2020)) = r.cip2020)
),

-- One row per person x job part (person_id x soc_code is unique: bridge parts are distinct codes).
slim as (
    select person_id, soc_code, fod1, major_code, soc_level
    from landed
),

cut_keys as (
    select person_id, soc_code, 'field_x_soc_major' as cut, fod1 as group_1, major_code as group_2
    from slim
    where fod1 is not null
    union all
    select person_id, soc_code, 'degree_x_soc', 'all', soc_code
    from slim
    union all
    select person_id, soc_code, 'field_total', fod1, 'all'
    from slim
    where fod1 is not null
    union all
    select
        s.person_id,
        s.soc_code,
        'field_x_linked',
        s.fod1,
        case
            when s.soc_level <> 'detailed' then 'job_not_detailed'
            when lp.soc_code is not null then 'linked'
            else 'not_linked'
        end
    from slim as s
    join fields as f on f.fod1p = s.fod1
    left join linked_pairs as lp on lp.fod1p = s.fod1 and lp.soc_code = s.soc_code
)

select
    '2020-2024' as period,
    k.cut,
    k.group_1,
    k.group_2,
    b.age_band,
    l.degree_level,
    l.person_id,
    l.soc_code,
    l.part_weight,
    l.is_allocated,
    l.is_ftyr,
    l.earnings_2024usd,
    l.fod_imputed,
    l.occ_imputed,
    l.wage_imputed,
    l.weight,
    {% for r in range(1, 81) %}
    l.pwgtp{{ r }}{{ "," if not loop.last }}
    {% endfor %}
from landed as l
join bands as b on l.age between b.age_lo and b.age_hi
join cut_keys as k on k.person_id = l.person_id and k.soc_code = l.soc_code
