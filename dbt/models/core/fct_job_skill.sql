-- core.fct_job_skill: O*NET knowledge (33 elements), essential skills (10) and transferable skills (25) ratings on
-- the Importance (IM, 1-5) and Level (LV, 0-7) scales, rolled from O*NET-SOC profiles to dim_job SOC codes.
-- Grain: soc_code x domain x element_id x scale (136 rows per rated job).
-- Plan: docs/step4-facts-plan.md §3b (design), §4 item 7 (tests); card onet.md issues 2-3 (roll-up rules).
--
-- How O*NET-SOC records reach dim_job:
--   onet_base     the SOC has a .00 record: its values are used as published (761 of 785 rated SOC codes)
--   onet_mean     no .00 record: plain mean of value, n, std_error, ci_low, ci_high over the rated specialties
--                 (24 codes, up to 9 specialties); suppress / not_relevant = any true; rated_date = max
--   pooled_parts  the 5 BLS aggregates in dim_job (soc_level = bls_aggregate) get the group_parts-weighted mean of
--                 their parts' rolled-up rows; weights renormalised over the parts that O*NET rates (25-9049 and
--                 53-1049 "all other" parts have no O*NET profile)
-- n_specialties = number of O*NET-SOC records of the SOC carrying the element (all of them, used or not); for
-- pooled_parts it is the sum over the rated parts. suppress / not_relevant are false where O*NET publishes no flag
-- (not_relevant exists only on LV; suppress is blank for Occupational Expert and some Analyst-Transition ratings).
-- Unrounded numerics; the mart rounds.

with src as (
    select * from {{ source('staging', 'stg_onet__descriptor_rating') }}
),

flagged as (
    select
        *,
        bool_or(onet_soc_code like '%.00') over (partition by soc_code) as has_base,
        count(*) over (partition by soc_code, domain, element_id, scale) as n_specialties
    from src
),

-- Step 1: SOC-level rows. The .00 record when it exists, else every rated specialty averaged.
rolled as (
    select
        soc_code,
        domain,
        element_id,
        max(element_name)                       as element_name,
        scale,
        avg(value::numeric)                     as value,
        avg(n::numeric)                         as n,
        avg(std_error::numeric)                 as std_error,
        avg(ci_low::numeric)                    as ci_low,
        avg(ci_high::numeric)                   as ci_high,
        coalesce(bool_or(suppress), false)      as suppress,
        coalesce(bool_or(not_relevant), false)  as not_relevant,
        max(rated_date)                         as rated_date,
        case when bool_or(has_base) then 'onet_base' else 'onet_mean' end as rollup_rule,
        max(n_specialties)                      as n_specialties,
        string_agg(distinct rating_source, ', ') as rating_source,
        max(onet_release)                       as onet_release
    from flagged
    where (has_base and onet_soc_code like '%.00') or not has_base
    group by soc_code, domain, element_id, scale
),

-- Step 2: the BLS aggregates, pooled from their parts' SOC-level rows.
aggregate_parts as (
    select b.source_code as soc_code, b.soc_code as part_code, b.weight::numeric as weight
    from {{ ref('bridge_job_code') }} as b
    join {{ ref('dim_job') }} as j on j.soc_code = b.source_code and j.soc_level = 'bls_aggregate'
    where b.code_system = 'group_parts'
),

pooled as (
    select
        a.soc_code,
        r.domain,
        r.element_id,
        max(r.element_name)                                                                   as element_name,
        r.scale,
        sum(r.value * a.weight) / sum(a.weight)                                               as value,
        sum(r.n * a.weight) / sum(a.weight)                                                   as n,
        sum(r.std_error * a.weight) / sum(a.weight) filter (where r.std_error is not null)    as std_error,
        sum(r.ci_low * a.weight)    / sum(a.weight) filter (where r.ci_low is not null)       as ci_low,
        sum(r.ci_high * a.weight)   / sum(a.weight) filter (where r.ci_high is not null)      as ci_high,
        bool_or(r.suppress)                                                                   as suppress,
        bool_or(r.not_relevant)                                                               as not_relevant,
        max(r.rated_date)                                                                     as rated_date,
        'pooled_parts'                                                                        as rollup_rule,
        sum(r.n_specialties)                                                                  as n_specialties,
        string_agg(distinct r.rating_source, ', ')                                            as rating_source,
        max(r.onet_release)                                                                   as onet_release
    from aggregate_parts as a
    join rolled as r on r.soc_code = a.part_code
    group by a.soc_code, r.domain, r.element_id, r.scale
),

unioned as (
    select * from rolled
    union all
    select * from pooled
)

select
    soc_code,
    domain,
    element_id,
    element_name,
    scale,
    value,
    n,
    std_error,
    ci_low,
    ci_high,
    suppress,
    not_relevant,
    rated_date,
    rollup_rule,
    n_specialties,
    rating_source,
    onet_release,
    'onet' as source_key
from unioned
