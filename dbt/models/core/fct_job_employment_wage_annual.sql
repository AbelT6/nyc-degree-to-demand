-- core.fct_job_employment_wage_annual: BLS OEWS metro estimates for the New York-Newark-Jersey City MSA (35620),
-- May 2018 - May 2025, landed on dim_job codes.
-- Grain: year x area_key ('ny_metro') x soc_code, at every published level (total 00-0000, 22 major groups, and the
-- lowest published rows OEWS calls "detailed", which include 12 broad / BLS-aggregate codes such as 13-1020).
-- Plan: docs/step4-facts-plan.md §3a (design), §4 item 2 (tests), §5 risks 4-5, §6 Tier 1 default (wages copied,
-- not split); decisions D12 (code chain), D15.
--
-- year      soc_edition   how a source row reaches dim_job (bridge_job_code, first system in the chain that has the code)
-- 2018      2010          soc_2010 -> soc_2010_group -> oews_hybrid (25-3097, 25-3098, 51-2098, 53-1048 are OEWS-only)
-- 2019-20   hybrid        soc_2018 (identity) -> oews_hybrid (24 BLS aggregates split onto their SOC 2018 parts)
-- 2021-25   2018          soc_2018 (identity)
--
-- Counts are split: employment = sum over sources of employment x weight (weights for a source sum to 1, so the
-- yearly totals are conserved). Wages are statistics of a distribution and cannot be apportioned, so a part inherits
-- its source row's hourly / annual mean and percentiles unchanged (quality_flag = 'split'). When two or more source
-- rows land on one target (21 SOC 2018 codes in 2018, e.g. 15-1252 <- 15-1132 + 15-1133) each wage column is the
-- employment-weighted mean over the sources that publish it, weights = the contributed employment, plain mean if a
-- contributing source has no employment ('combined'). published = one source at weight 1, values as published.
-- RSEs, jobs_per_1000 and location_quotient are kept only where they still describe the row (one source; and for the
-- ratios, weight 1). Real-dollar columns = nominal x fct_cpi_annual.deflator_to_2025 for ny_metro and the same year.
-- series_note marks the breaks the mart must footnote: 2022 top-code cap raised, 2024 MSA redrawn (Pike County, PA
-- out), 2025 no top-coding and RSE redefined as model error. Values are unrounded numerics; the mart rounds.

{% set wage_cols = ['hourly_mean', 'annual_mean',
                    'hourly_p10', 'hourly_p25', 'hourly_p50', 'hourly_p75', 'hourly_p90',
                    'annual_p10', 'annual_p25', 'annual_p50', 'annual_p75', 'annual_p90'] %}

with src as (
    select * from {{ source('staging', 'stg_bls__oews_metro_occupations') }}
),

bridge as (
    select code_system, source_code, soc_code, weight::numeric as weight, weight_basis
    from {{ ref('bridge_job_code') }}
    where code_system in ('soc_2018', 'soc_2010', 'soc_2010_group', 'oews_hybrid')
),

chain as (
    select * from (values
        ('2010', 'soc_2010', 1), ('2010', 'soc_2010_group', 2), ('2010', 'oews_hybrid', 3),
        ('hybrid', 'soc_2018', 1), ('hybrid', 'oews_hybrid', 2),
        ('2018', 'soc_2018', 1)
    ) as v (soc_edition, code_system, priority)
),

-- The first system in the edition's chain that carries the code.
resolved as (
    select year, occ_code, code_system
    from (
        select
            s.year, s.occ_code, c.code_system,
            row_number() over (partition by s.year, s.occ_code order by c.priority) as rn
        from src as s
        join chain as c on c.soc_edition = s.soc_edition
        where exists (select 1 from bridge as b where b.code_system = c.code_system and b.source_code = s.occ_code)
    ) as x
    where rn = 1
),

-- One row per source row x target. Counts are weighted; wages are carried as published.
contributions as (
    select
        s.year,
        b.soc_code,
        s.occ_code as source_code,
        r.code_system,
        b.weight,
        b.weight_basis,
        s.occ_level,
        s.employment::numeric * b.weight      as employment,
        s.employment_rse_pct::numeric         as employment_rse_pct,
        s.jobs_per_1000::numeric              as jobs_per_1000,
        s.location_quotient::numeric          as location_quotient,
        s.mean_rse_pct::numeric               as mean_rse_pct,
        {% for c in wage_cols %}
        s.{{ c }}::numeric as {{ c }},
        {% endfor %}
        s.annual_only,
        s.hourly_only,
        s.is_top_coded
    from src as s
    join resolved as r on r.year = s.year and r.occ_code = s.occ_code
    join bridge as b on b.code_system = r.code_system and b.source_code = s.occ_code
),

bridged as (
    select
        year,
        soc_code,
        max(occ_level) as occ_level,
        -- null when any contributing source is suppressed, never a partial sum.
        case when count(*) = count(employment) then sum(employment) end as employment,
        case when count(*) = 1 then max(employment_rse_pct) end as employment_rse_pct,
        case when count(*) = 1 and max(weight) = 1 then max(jobs_per_1000) end as jobs_per_1000,
        case when count(*) = 1 and max(weight) = 1 then max(location_quotient) end as location_quotient,
        case when count(*) = 1 then max(mean_rse_pct) end as mean_rse_pct,
        {% for c in wage_cols %}
        case
            when count(*) = 1 then max({{ c }})
            when count({{ c }}) = 0 then null
            when count(*) filter (where {{ c }} is not null and employment is null) > 0
              or sum(employment) filter (where {{ c }} is not null) = 0
                then avg({{ c }})
            else sum({{ c }} * employment) filter (where {{ c }} is not null)
                 / sum(employment) filter (where {{ c }} is not null)
        end as {{ c }},
        {% endfor %}
        bool_or(annual_only)  as annual_only,
        bool_or(hourly_only)  as hourly_only,
        bool_or(is_top_coded) as is_top_coded,
        case
            when count(*) > 1 then 'combined'
            when max(weight) < 1 then 'split'
            else 'published'
        end as quality_flag,
        case
            when count(*) = 1 and max(weight) = 1 then max(source_code)
            else string_agg(code_system || ':' || source_code || '*' || round(weight, 4)::text, ', ' order by source_code)
        end as source_codes,
        string_agg(distinct weight_basis, ', ') as weight_basis
    from contributions
    group by year, soc_code
),

deflator as (
    select year, deflator_to_2025
    from {{ ref('fct_cpi_annual') }}
    where area_key = 'ny_metro'
)

select
    b.year,
    'ny_metro' as area_key,
    b.soc_code,
    b.occ_level,
    b.employment,
    b.employment_rse_pct,
    b.jobs_per_1000,
    b.location_quotient,
    b.hourly_mean,
    b.annual_mean,
    b.mean_rse_pct,
    b.hourly_p10,
    b.hourly_p25,
    b.hourly_p50,
    b.hourly_p75,
    b.hourly_p90,
    b.annual_p10,
    b.annual_p25,
    b.annual_p50,
    b.annual_p75,
    b.annual_p90,
    b.annual_mean * d.deflator_to_2025 as annual_mean_2025usd,
    b.annual_p10  * d.deflator_to_2025 as annual_p10_2025usd,
    b.annual_p25  * d.deflator_to_2025 as annual_p25_2025usd,
    b.annual_p50  * d.deflator_to_2025 as annual_p50_2025usd,
    b.annual_p75  * d.deflator_to_2025 as annual_p75_2025usd,
    b.annual_p90  * d.deflator_to_2025 as annual_p90_2025usd,
    b.annual_only,
    b.hourly_only,
    b.is_top_coded,
    b.quality_flag,
    case b.year
        when 2022 then 'topcode_cap_change'
        when 2024 then 'area_delineation_2024'
        when 2025 then 'no_topcode'
    end as series_note,
    b.source_codes,
    b.weight_basis,
    'bls_oews_metro' as source_key
from bridged as b
join deflator as d on d.year = b.year
