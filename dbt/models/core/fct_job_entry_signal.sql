-- core.fct_job_entry_signal: three independent estimates of how open a job is to newcomers, side by side (D5: shown
-- as a range, never merged into one number). Grain: soc_code x measure, measure in
--   bls_experience   BLS EP Table 5.4 work experience in a related occupation (None / <5 years / 5+ years), national
--   acs_young_share  share of employed NYC residents in the job aged 22-29 (ACS PUMS, 90% MOE from 80 replicates)
--   onet_newcomer    share of O*NET respondents who needed <= 1 month of related experience (RW categories 1-2)
-- Plan: docs/step4-facts-plan.md §3b (design, band cutoffs written before results), §4 item 6 (tests); decision D5.
--
-- How source codes reach dim_job:
--   bls_experience   soc_code is SOC 2018, identity (831 codes, all in dim_job)
--   acs_young_share  socp is a 6-char Census code; left(2)||'-'||right(4) is used directly when dim_job has it,
--                    else bridge_job_code code_system = acs_socp allocates the group code onto its parts by weight
--                    (the two paths cover 100% of employed persons; profiled)
--   onet_newcomer    staging carries the SOC of each O*NET-SOC code; the .00 record is used if rated, else the
--                    plain mean over the rated specialties (quality_flag onet_base / onet_mean)
--
-- Common columns: value (rank 1-3 for BLS, a share in [0, 1] for the other two), band (text, per-measure cutoffs),
-- moe_90 (ACS only), n (BLS null; ACS unweighted person rows; O*NET respondents), n_young (ACS only: unweighted
-- contributing person rows aged 22-29, same counting rule as n, so D5's "jobs with 30+ young persons" is
-- reproducible; suppression stays on n), suppressed (ACS n < 30, then value,
-- band and moe_90 are null; O*NET = the publisher's "recommend suppress" flag on the categories used, value kept,
-- false where O*NET publishes no flag), quality_flag, source_key, note. Unrounded numerics; the mart rounds.

with job as (
    select soc_code from {{ ref('dim_job') }}
),

-- ---- 1. BLS work experience ----------------------------------------------------------------------------------
bls as (
    select
        soc_code,
        'bls_experience'                    as measure,
        experience_rank::numeric            as value,
        case experience
            when 'None'              then 'none'
            when 'Less than 5 years' then 'under_5_years'
            when '5 years or more'   then '5_years_plus'
        end                                 as band,
        null::numeric                       as moe_90,
        null::numeric                       as n,
        null::numeric                       as n_young,
        false                               as suppressed,
        'published'                         as quality_flag,
        'bls_ep_education'                  as source_key,
        'BLS EP Table 5.4 (' || edition || ') typical work experience in a related occupation: ' || experience
                                            as note
    from {{ source('staging', 'stg_bls__ep_entry_requirements') }}
),

-- ---- 2. ACS young share --------------------------------------------------------------------------------------
persons as (
    select
        socp,
        age,
        weight::numeric as weight
        {% for r in range(1, 81) %}
        , pwgtp{{ r }}::numeric as pwgtp{{ r }}
        {% endfor %}
    from {{ source('staging', 'stg_census__acs_pums_person') }}
    where employment_status in ('1', '2')
      and socp is not null
),

socp_codes as (
    select distinct socp from persons
),

-- A socp whose SOC-shaped spelling exists in dim_job lands there whole; the rest go through the acs_socp bridge.
direct as (
    select c.socp, j.soc_code
    from socp_codes as c
    join job as j on j.soc_code = left(c.socp, 2) || '-' || right(c.socp, 4)
),

landing as (
    select socp, soc_code, 1::numeric as part_weight, 'direct' as path
    from direct
    union all
    select b.source_code as socp, b.soc_code, b.weight::numeric as part_weight, 'allocated' as path
    from {{ ref('bridge_job_code') }} as b
    where b.code_system = 'acs_socp'
      and not exists (select 1 from direct as d where d.socp = b.source_code)
),

contributions as (
    select
        l.soc_code,
        l.path,
        p.age between 22 and 29 as is_young,
        p.weight * l.part_weight as w0
        {% for r in range(1, 81) %}
        , p.pwgtp{{ r }} * l.part_weight as w{{ r }}
        {% endfor %}
    from persons as p
    join landing as l on l.socp = p.socp
),

acs_sums as (
    select
        soc_code,
        count(*)                                         as n,
        count(*) filter (where is_young)                 as n_young,
        bool_and(path = 'direct')                        as all_direct,
        sum(w0)                                          as total_0,
        coalesce(sum(w0) filter (where is_young), 0)     as young_0
        {% for r in range(1, 81) %}
        , sum(w{{ r }})                                      as total_{{ r }}
        , coalesce(sum(w{{ r }}) filter (where is_young), 0) as young_{{ r }}
        {% endfor %}
    from contributions
    group by soc_code
),

-- share_r - share for each replicate; SE = sqrt(4/80 * sum of squares); MOE_90 = 1.645 * SE (PUMS accuracy doc).
acs_est as (
    select
        soc_code,
        n,
        n_young,
        all_direct,
        young_0 / total_0 as share,
        (
            {% for r in range(1, 81) %}
            power(young_{{ r }} / nullif(total_{{ r }}, 0) - young_0 / total_0, 2)
            {% if not loop.last %}+{% endif %}
            {% endfor %}
        ) as sum_sq
    from acs_sums
),

acs as (
    select
        soc_code,
        'acs_young_share'                                       as measure,
        case when n >= 30 then share end                        as value,
        case
            when n < 30      then null
            when share >= 0.30 then 'high'
            when share >= 0.15 then 'mid'
            else 'low'
        end                                                     as band,
        case when n >= 30 then 1.645 * sqrt(4.0 / 80 * sum_sq) end as moe_90,
        n::numeric                                              as n,
        n_young::numeric                                        as n_young,
        n < 30                                                  as suppressed,
        case when all_direct then 'direct' else 'includes_allocated' end as quality_flag,
        'acs_pums'                                              as source_key,
        'ACS PUMS NYC residents employed (ESR 1-2), any age; share aged 22-29; n = unweighted person rows'
            || case when all_direct then '' else '; includes persons allocated from a Census group code' end
            || case when n < 30 then '; suppressed (n < 30)' else '' end as note
    from acs_est
),

-- ---- 3. O*NET newcomer share ---------------------------------------------------------------------------------
rw as (
    select
        onet_soc_code,
        soc_code,
        sum(share_pct) filter (where category in (1, 2))::numeric / 100 as newcomer_share,
        max(n)                                                          as n,
        bool_or(suppress) filter (where category in (1, 2))             as suppress,
        max(onet_release)                                               as onet_release
    from {{ source('staging', 'stg_onet__education_experience') }}
    where question = 'Related Work Experience'
    group by onet_soc_code, soc_code
),

rw_flagged as (
    select *, bool_or(onet_soc_code like '%.00') over (partition by soc_code) as has_base
    from rw
),

onet as (
    select
        soc_code,
        'onet_newcomer'                                         as measure,
        avg(newcomer_share)                                     as value,
        case
            when avg(newcomer_share) >= 0.25 then 'high'
            when avg(newcomer_share) >= 0.10 then 'mid'
            else 'low'
        end                                                     as band,
        null::numeric                                           as moe_90,
        avg(n::numeric)                                         as n,
        null::numeric                                           as n_young,
        coalesce(bool_or(suppress), false)                      as suppressed,
        case when bool_or(has_base) then 'onet_base' else 'onet_mean' end as quality_flag,
        'onet'                                                  as source_key,
        'O*NET ' || max(onet_release) || ' RW categories 1-2 (None, up to 1 month) over '
            || string_agg(onet_soc_code, ', ' order by onet_soc_code)
            || case when coalesce(bool_or(suppress), false) then '; O*NET recommends suppression (low precision)' else '' end as note
    from rw_flagged
    where (has_base and onet_soc_code like '%.00') or not has_base
    group by soc_code
),

unioned as (
    select * from bls
    union all
    select * from acs
    union all
    select * from onet
)

select
    soc_code,
    measure,
    value,
    band,
    moe_90,
    n,
    n_young,
    suppressed,
    quality_flag,
    source_key,
    note
from unioned
