-- core.fct_job_projection: NYS DOL long-term occupational projections for NYC, all four editions, on dim_job codes.
-- Grain: edition x soc_code (soc_code at any level; group rows kept so the mart can roll up and tests can tie out).
-- Plan: docs/step3-d1-fill-plan.md §5 (design), §3 (fill rule); decisions D1, D12, D15.
--
-- edition    code system   how a source row reaches dim_job (bridge_job_code, first system that has the code)
-- 2016-26    SOC 2010      soc_2010 -> soc_2010_group (15-1100, 31-1000) -> oews_hybrid (OEWS-only codes 25-3097 ...)
-- 2018-28    SOC 2010      same chain
-- 2020-30    hybrid        soc_2018 (identity) -> oews_hybrid (20 BLS aggregates split onto their parts)
-- 2022-32    hybrid        same chain, minus the 11 collapsed rows (publisher_defect), plus the imputed part rows (D1)
--
-- quality_flag: published = one source row, weight 1, values as published; split = weighted from one or more
-- SOC 2010 / hybrid codes (sums conserved); imputed = D1 fill. Values are unrounded numerics; the mart rounds.

with src as (
    select * from {{ source('staging', 'stg_nysdol__occupation_projections') }}
),

bridge as (
    select code_system, source_code, soc_code, weight::numeric as weight, weight_basis
    from {{ ref('bridge_job_code') }}
    where code_system in ('soc_2018', 'soc_2010', 'soc_2010_group', 'oews_hybrid')
),

chain as (
    select * from (values
        ('2010', 'soc_2010', 1), ('2010', 'soc_2010_group', 2), ('2010', 'oews_hybrid', 3),
        ('2018', 'soc_2018', 1), ('2018', 'oews_hybrid', 2)
    ) as v (soc_edition, code_system, priority)
),

-- The first system in the edition's chain that carries the code.
resolved as (
    select edition, soc_code, code_system
    from (
        select
            s.edition, s.soc_code, c.code_system,
            row_number() over (partition by s.edition, s.soc_code order by c.priority) as rn
        from src as s
        join chain as c on c.soc_edition = s.soc_edition
        where exists (select 1 from bridge as b where b.code_system = c.code_system and b.source_code = s.soc_code)
    ) as x
    where rn = 1
),

-- One row per source row x target: the collapsed 2022-32 rows are left out here and come back as imputed parts.
contributions as (
    select
        s.edition,
        s.base_year,
        s.projected_year,
        b.soc_code,
        s.soc_code as source_code,
        r.code_system,
        b.weight,
        b.weight_basis,
        s.is_leaf,
        s.base_employment::numeric          * b.weight as base_employment,
        s.projected_employment::numeric     * b.weight as projected_employment,
        s.employment_change::numeric        * b.weight as employment_change,
        s.pct_change::numeric                          as pct_change_published,
        s.annual_openings_avg::numeric      * b.weight as annual_openings_avg,
        s.growth_openings_avg::numeric      * b.weight as growth_openings_avg,
        s.separation_openings_avg::numeric  * b.weight as separation_openings_avg
    from src as s
    join resolved as r on r.edition = s.edition and r.soc_code = s.soc_code
    join bridge as b on b.code_system = r.code_system and b.source_code = s.soc_code
    where not (s.edition = '2022-2032' and s.quality_flag = 'publisher_defect')
),

bridged as (
    select
        edition,
        base_year,
        projected_year,
        soc_code,
        bool_or(is_leaf) as is_leaf,
        sum(base_employment)            as base_employment,
        sum(projected_employment)       as projected_employment,
        sum(employment_change)          as employment_change,
        case
            when count(*) = 1 and max(weight) = 1 then max(pct_change_published)
            when sum(base_employment) > 0 then (sum(projected_employment) - sum(base_employment)) / sum(base_employment) * 100
        end as pct_change,
        sum(annual_openings_avg)        as annual_openings_avg,
        sum(growth_openings_avg)        as growth_openings_avg,
        sum(separation_openings_avg)    as separation_openings_avg,
        case when count(*) = 1 and max(weight) = 1 then 'published' else 'split' end as quality_flag,
        case
            when count(*) = 1 and max(weight) = 1 then max(source_code)
            else string_agg(code_system || ':' || source_code || '*' || round(weight, 4)::text, ', ' order by source_code)
        end as source_codes,
        string_agg(distinct weight_basis, ', ') as weight_basis
    from contributions
    group by edition, base_year, projected_year, soc_code
),

-- D1 fill for 2022-32 (plan §3 steps 6-8): split each group's fill across its candidates' parts.
parts as (
    select * from {{ ref('int_projection_fill_2022_parts') }}
),

fill as (
    select fill_group, base_filled, projected_filled, openings_filled
    from {{ ref('audit_projection_fill_2022') }}
),

metro as (
    select occ_code, employment::numeric as employment
    from {{ source('staging', 'stg_bls__oews_metro_occupations') }}
    where year = 2025 and soc_edition = '2018' and employment is not null
),

national as (
    select
        soc_code,
        employment_2025_k::numeric * 1000 as employment_2025,
        employment_change_pct::numeric    as pct_change,
        annual_openings_k::numeric        as openings_k,
        employment_2025_k::numeric        as employment_k
    from {{ source('staging', 'stg_bls__ep_occupation_projections') }}
    where occupation_type = 'Line item'
),

-- Step 6: candidate size in OEWS NY metro 2025 units; a part with no metro row is sized as BLS national 2025 x the
-- group's metro / national ratio over the parts that have both.
sized_parts as (
    select
        p.*,
        m.employment as metro_employment,
        n.employment_2025 as national_employment,
        n.pct_change as national_pct_change,
        n.openings_k / n.employment_k as national_openings_rate
    from parts as p
    left join metro as m on m.occ_code = p.part_code
    join national as n on n.soc_code = p.part_code
),

group_ratio as (
    select fill_group, sum(metro_employment) / sum(national_employment) as metro_to_national
    from sized_parts
    where metro_employment is not null
    group by fill_group
),

part_size as (
    select
        s.*,
        coalesce(s.metro_employment, s.national_employment * r.metro_to_national) as size_metro_units
    from sized_parts as s
    join group_ratio as r on r.fill_group = s.fill_group
),

shares as (
    select
        *,
        weight
            * sum(size_metro_units) over (partition by fill_group, fill_candidate)
            / sum(size_metro_units) over (partition by fill_group) as share
    from part_size
),

-- Step 7: base by share; projected and openings by the BLS national rates, rescaled to the group's fill.
raw as (
    select
        s.*,
        f.base_filled * s.share as base_employment,
        f.base_filled * s.share * (1 + s.national_pct_change / 100) as projected_raw,
        f.base_filled * s.share * s.national_openings_rate          as openings_raw,
        f.projected_filled,
        f.openings_filled
    from shares as s
    join fill as f on f.fill_group = s.fill_group
),

scaled as (
    select
        *,
        projected_raw * projected_filled / sum(projected_raw) over (partition by fill_group) as projected_employment,
        openings_raw * openings_filled / sum(openings_raw) over (partition by fill_group)    as annual_openings_raw
    from raw
),

-- Step 8: derived columns follow the published identities. A part whose openings fall below its growth openings
-- (BLS publishes 0.0 thousand openings for tiny occupations, so the national rate is 0) is lifted to growth, and the
-- lift is taken back from the group's other parts in proportion to their openings, so separations are never
-- negative and the group still ties exactly.
floored as (
    select
        *,
        (projected_employment - base_employment) / 10 as growth_openings_avg,
        greatest(annual_openings_raw, (projected_employment - base_employment) / 10) as openings_floored,
        greatest((projected_employment - base_employment) / 10 - annual_openings_raw, 0) as lift
    from scaled
),

rebalanced as (
    select
        *,
        case
            when lift > 0 then openings_floored
            else openings_floored
                * (1 - sum(lift) over (partition by fill_group)
                       / sum(case when lift > 0 then 0 else openings_floored end) over (partition by fill_group))
        end as annual_openings_avg
    from floored
),

imputed as (
    select
        '2022-2032' as edition,
        2022 as base_year,
        2032 as projected_year,
        part_code as soc_code,
        true as is_leaf,
        base_employment,
        projected_employment,
        projected_employment - base_employment as employment_change,
        case when base_employment > 0 then (projected_employment - base_employment) / base_employment * 100 end as pct_change,
        annual_openings_avg,
        growth_openings_avg,
        annual_openings_avg - growth_openings_avg as separation_openings_avg,
        'imputed' as quality_flag,
        'fill:' || fill_candidate as source_codes,
        weight_basis,
        fill_group,
        fill_candidate
    from rebalanced
),

unioned as (
    select
        edition, base_year, projected_year, soc_code, is_leaf,
        base_employment, projected_employment, employment_change, pct_change,
        annual_openings_avg, growth_openings_avg, separation_openings_avg,
        quality_flag, source_codes, weight_basis,
        null::text as fill_group, null::text as fill_candidate
    from bridged
    union all
    select
        edition, base_year, projected_year, soc_code, is_leaf,
        base_employment, projected_employment, employment_change, pct_change,
        annual_openings_avg, growth_openings_avg, separation_openings_avg,
        quality_flag, source_codes, weight_basis, fill_group, fill_candidate
    from imputed
)

select
    edition,
    base_year,
    projected_year,
    soc_code,
    is_leaf,
    base_employment,
    projected_employment,
    employment_change,
    pct_change,
    annual_openings_avg,
    growth_openings_avg,
    separation_openings_avg,
    quality_flag,
    case when edition = '2020-2030' then 'covid_base' end as edition_flag,
    source_codes,
    weight_basis,
    fill_group,
    fill_candidate
from unioned
