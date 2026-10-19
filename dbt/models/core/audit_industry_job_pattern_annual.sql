-- core.audit_industry_job_pattern_annual: New York State staffing pattern by pattern sector and year, from the BLS
-- OEWS research estimates (state x industry), sector level, May 2019 - May 2025, landed on dim_job codes.
-- Grain: year x pattern_sector x soc_code (20 pattern sectors a year: 19 NAICS sectors + 99 government excluding
-- schools, hospitals and the Postal Service). The second input of decision D8; kept as a table for auditing.
-- Plan: docs/step4-facts-plan.md §2a (OEWS research row), §3a, §5 risks 2-3, §6.2; decisions D8, D3.
--
-- year      soc_vintage   how a research occ_code reaches dim_job (bridge_job_code, first system in the chain that has the code)
-- 2019-20   hybrid        soc_2018 (identity, 698-708 codes) -> oews_hybrid (24 BLS aggregates split onto their SOC 2018 parts)
-- 2021-25   2018          soc_2018 (identity)
-- Profiling: 0 unresolved codes in any year. The rows the research file calls "detailed" include 7 broad codes
-- (13-1020 ...) and the 5 BLS aggregates dim_job keeps (21-1018 ...); they are carried at those levels.
--
-- Only o_group = 'detailed' cells with a published tot_emp enter; suppressed cells (300-441 a year, counted in
-- n_suppressed) are excluded, so share_of_sector renormalises over the published jobs and sums to 1 per
-- sector-year. pattern_coverage = published detailed jobs / the sector-year's o_group = 'total' tot_emp (before
-- renormalising) says how much of the sector the shares describe: 0.99+ for the big sectors, 0.69-0.84 for
-- agriculture (11) and mining (21), which have under 600 NYC private jobs between them. emp is the weighted NY
-- employment (tot_emp x bridge weight, summed per target), unrounded.

with src as (
    select year, naics, occ_code, soc_vintage, tot_emp, o_group
    from {{ source('staging', 'stg_bls__oews_research_ny') }}
    where i_group = 'sector'
),

detailed as (
    select * from src
    where o_group = 'detailed'
),

bridge as (
    select code_system, source_code, soc_code, weight::numeric as weight, weight_basis
    from {{ ref('bridge_job_code') }}
    where code_system in ('soc_2018', 'oews_hybrid')
),

chain as (
    select * from (values
        ('hybrid', 'soc_2018', 1), ('hybrid', 'oews_hybrid', 2),
        ('2018', 'soc_2018', 1)
    ) as v (soc_vintage, code_system, priority)
),

-- The first system in the vintage's chain that carries the code.
resolved as (
    select year, occ_code, code_system
    from (
        select
            s.year, s.occ_code, c.code_system,
            row_number() over (partition by s.year, s.occ_code order by c.priority) as rn
        from (select distinct year, occ_code, soc_vintage from detailed) as s
        join chain as c on c.soc_vintage = s.soc_vintage
        where exists (select 1 from bridge as b where b.code_system = c.code_system and b.source_code = s.occ_code)
    ) as x
    where rn = 1
),

contributions as (
    select
        d.year,
        d.naics as pattern_sector,
        b.soc_code,
        d.occ_code as source_code,
        r.code_system,
        b.weight,
        b.weight_basis,
        d.tot_emp::numeric * b.weight as emp
    from detailed as d
    join resolved as r on r.year = d.year and r.occ_code = d.occ_code
    join bridge as b on b.code_system = r.code_system and b.source_code = d.occ_code
    where d.tot_emp is not null
),

bridged as (
    select
        year,
        pattern_sector,
        soc_code,
        sum(emp) as emp,
        case when count(*) = 1 and max(weight) = 1 then 'published' else 'split' end as quality_flag,
        case
            when count(*) = 1 and max(weight) = 1 then max(source_code)
            else string_agg(code_system || ':' || source_code || '*' || round(weight, 4)::text, ', ' order by source_code)
        end as source_codes
    from contributions
    group by year, pattern_sector, soc_code
),

sector_year as (
    select
        year,
        naics as pattern_sector,
        sum(tot_emp::numeric) filter (where o_group = 'detailed')        as detailed_emp,
        max(tot_emp::numeric) filter (where o_group = 'total')           as total_emp,
        count(*) filter (where o_group = 'detailed' and tot_emp is null) as n_suppressed
    from src
    group by year, naics
)

select
    b.year,
    b.pattern_sector,
    coalesce(a.industry_key, b.pattern_sector)                        as industry_key,
    b.soc_code,
    b.emp,
    b.emp / sum(b.emp) over (partition by b.year, b.pattern_sector)   as share_of_sector,
    s.detailed_emp / s.total_emp                                      as pattern_coverage,
    s.n_suppressed::integer                                           as n_suppressed,
    b.quality_flag,
    b.source_codes,
    'bls_oews_research'                                               as source_key
from bridged as b
join sector_year as s
    on s.year = b.year and s.pattern_sector = b.pattern_sector
left join {{ ref('industry_code_alias') }} as a
    on a.code_system = 'oews_research' and a.source_code = b.pattern_sector
