-- core.dim_job: one row per job code that core facts land on.
-- Plan and rules: docs/step1-dimensions-plan.md. Grain: docs/schema-design.md §2.
-- Rows = SOC 2018 hierarchy (1,447) + 5 BLS reporting aggregates + 00-0000 = 1,453.
-- SOC 2010 and OEWS hybrid codes are not rows here; bridge_job_code (step 2) maps them onto these.

with structure as (
    select soc_code, soc_title, level as soc_level, major_code, minor_code, broad_code
    from {{ source('staging', 'stg_bls__soc_2018_structure') }}
),

-- BLS EP codes outside the SOC structure are the 5 reporting aggregates
-- (21-1018, 25-2052, 25-9045, 51-2028, 53-1047). Each sits inside one broad group.
aggregates as (
    select
        e.soc_code,
        e.soc_title,
        'bls_aggregate' as soc_level,
        left(e.soc_code, 2) || '-0000' as major_code,
        left(e.soc_code, 4) || '000' as minor_code,
        left(e.soc_code, 6) || '0' as broad_code
    from {{ source('staging', 'stg_bls__ep_entry_requirements') }} as e
    where not exists (select 1 from structure as s where s.soc_code = e.soc_code)
),

codes as (
    select * from structure
    union all
    select * from aggregates
    union all
    select '00-0000', 'All Occupations', 'total', null, null, null
),

-- The detailed SOC 2018 codes a reporting code stands for:
-- aggregates use BLS's own list (OEWS hybrid file; 25-2052 appears there as a SOC 2010 code
-- split into 25-2055/25-2056, the others as oes_2019 aggregates), broad codes use their children.
parts as (
    select distinct a.soc_code, h.soc_2018 as part_code
    from aggregates as a
    join {{ source('staging', 'stg_bls__oews_hybrid') }} as h
        on h.oes_2019 = a.soc_code or h.soc_2010 = a.soc_code
    union
    select broad_code, soc_code
    from structure
    where soc_level = 'detailed'
),

-- A detailed code is its own member; aggregates and broad codes pool their parts.
members as (
    select soc_code, soc_code as part_code from codes where soc_level = 'detailed'
    union all
    select soc_code, part_code from parts
),

-- O*NET job zone. Detailed rule: the .00 record (the SOC job itself) wins;
-- without one, the most common zone, ties to the lower.
jz_raw as (
    select
        soc_code,
        job_zone,
        onet_soc_code like '%.00' as is_base,
        count(*) over (partition by soc_code, job_zone) as n_same
    from {{ source('staging', 'stg_onet__job_zone') }}
),

jz_detailed as (
    select
        soc_code,
        coalesce(
            max(job_zone) filter (where is_base),
            (array_agg(job_zone order by n_same desc, job_zone))[1]
        ) as job_zone,
        min(job_zone) as job_zone_min,
        max(job_zone) as job_zone_max,
        case
            when bool_or(is_base) then 'onet_base'
            when count(distinct job_zone) > 1 then 'onet_mode'
            else 'onet_single'
        end as job_zone_rule
    from jz_raw
    group by soc_code
),

-- Pooled rule for aggregates and broad codes: most common of the parts' zones, ties to the lower.
jz_pooled_rows as (
    select
        m.soc_code,
        d.job_zone,
        count(*) over (partition by m.soc_code, d.job_zone) as n_same
    from members as m
    join jz_detailed as d on d.soc_code = m.part_code
    where m.soc_code <> m.part_code
),

jz_pooled as (
    select
        soc_code,
        (array_agg(job_zone order by n_same desc, job_zone))[1] as job_zone,
        min(job_zone) as job_zone_min,
        max(job_zone) as job_zone_max,
        'pooled_parts' as job_zone_rule
    from jz_pooled_rows
    group by soc_code
),

job_zone as (
    select * from jz_detailed
    union all
    select * from jz_pooled
),

-- Eloundou β rebuilt from task labels with the nb 14 rule that ties out exactly:
-- E1 = 1, E2 = 0.5; core task weight 1, supplemental or blank 0.5. Pooled over members.
tasks as (
    select
        soc_code,
        case gpt4_label when 'E1' then 1.0 when 'E2' then 0.5 else 0.0 end as exposure,
        case when task_type = 'Core' then 1.0 else 0.5 end as weight
    from {{ source('staging', 'stg_eloundou__task_exposure') }}
),

beta as (
    select m.soc_code, sum(t.exposure * t.weight) / sum(t.weight) as ai_beta_gpt4
    from members as m
    join tasks as t on t.soc_code = m.part_code
    group by m.soc_code
),

anthropic as (
    select soc_code, observed_exposure
    from {{ source('staging', 'stg_anthropic__job_exposure') }}
),

entry as (
    select
        soc_code,
        edition as ep_edition,
        education as entry_education,
        education_rank as entry_education_rank,
        experience as entry_experience,
        experience_rank as entry_experience_rank,
        training as entry_training,
        training_rank as entry_training_rank
    from {{ source('staging', 'stg_bls__ep_entry_requirements') }}
),

-- Featured areas (brief S7, D11): four flags, because a job can sit in several clusters (D6).
featured as (
    select
        soc_code,
        bool_or(cluster_name = 'Digital Technology') as in_tech,
        bool_or(cluster_name = 'Healthcare & Human Services') as in_health,
        bool_or(cluster_name in ('Financial Services', 'Management & Entrepreneurship', 'Marketing & Sales')) as in_business,
        bool_or(cluster_name = 'Education') as in_education
    from {{ source('staging', 'stg_cte__soc_subcluster') }}
    group by soc_code
)

select
    c.soc_code,
    c.soc_title,
    c.soc_level,
    c.major_code,
    c.minor_code,
    c.broad_code,
    c.soc_title ilike '%all other%' as is_all_other,

    e.ep_edition,
    e.entry_education,
    e.entry_education_rank,
    e.entry_experience,
    e.entry_experience_rank,
    e.entry_training,
    e.entry_training_rank,
    coalesce(e.entry_education in ('Associate''s degree', 'Bachelor''s degree'), false) as is_degree_entry,

    z.job_zone,
    z.job_zone_min,
    z.job_zone_max,
    z.job_zone_rule,
    z.job_zone is not null as onet_rated,

    a.observed_exposure as ai_observed_exposure,
    case
        when a.observed_exposure is null then 'Not rated'
        when a.observed_exposure = 0 then 'Not seen yet'
        when a.observed_exposure < 0.10 then 'Low'
        when a.observed_exposure < 0.30 then 'Medium'
        else 'High'
    end as ai_band,
    round(b.ai_beta_gpt4::numeric, 4) as ai_beta_gpt4,

    coalesce(f.in_tech, false) as in_tech,
    coalesce(f.in_health, false) as in_health,
    coalesce(f.in_business, false) as in_business,
    coalesce(f.in_education, false) as in_education
from codes as c
left join entry as e on e.soc_code = c.soc_code
left join job_zone as z on z.soc_code = c.soc_code
left join anthropic as a on a.soc_code = c.soc_code
left join beta as b on b.soc_code = c.soc_code
left join featured as f on f.soc_code = c.soc_code
