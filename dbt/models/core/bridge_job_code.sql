-- core.bridge_job_code: any job code a source uses -> dim_job rows, with weights that sum to 1 per
-- code_system x source_code. Plan: docs/step2-bridges-plan.md §2. Split weights: decision D12.
--
-- code_system        source codes                              target rows                 weight
-- soc_2018           every dim_job row                         itself                      1
-- soc_2010           BLS crosswalk (900 pairs) + group rows    SOC 2018 detailed / groups  D12 chain, basis 2021
-- soc_2010_group     15-1100, 31-1000 (seed)                   SOC 2018 minor group        1
-- oews_hybrid        OEWS 2019/2018 hybrid codes not in dim    SOC 2018 detailed parts     D12 chain, basis 2025
-- group_parts        every non-detailed dim_job row            its detailed members        D12 chain, basis 2025
-- acs_socp           ACS PUMS SOCP: plain codes + X/Y groups   SOC 2018 detailed           D12 chain, basis 2022
-- onet_soc           O*NET-SOC 2019 codes                      SOC 2018 detailed           1
--
-- Facts pick the system from their own soc_edition: 2010-coded series use soc_2010 then soc_2010_group;
-- hybrid-coded series (OEWS 2019-20, NYS DOL 2020-30 and 2022-32) use soc_2018 then oews_hybrid.

with dim as (
    select soc_code, soc_level from {{ ref('dim_job') }}
),

detailed as (
    select soc_code from dim where soc_level = 'detailed'
),

-- Aggregate -> parts, as in dim_job: BLS's own list (hybrid file), broad/minor/major -> structure children.
aggregate_parts as (
    select distinct a.soc_code as source_code, h.soc_2018 as soc_code
    from dim as a
    join {{ source('staging', 'stg_bls__oews_hybrid') }} as h
        on h.oes_2019 = a.soc_code or h.soc_2010 = a.soc_code
    where a.soc_level = 'bls_aggregate'
),

structure_parts as (
    select g.soc_code as source_code, s.soc_code
    from {{ source('staging', 'stg_bls__soc_2018_structure') }} as s
    join dim as g on g.soc_level in ('major', 'minor', 'broad')
        and g.soc_code in (s.major_code, s.minor_code, s.broad_code)
    where s.level = 'detailed'
    union all
    select '00-0000', soc_code from detailed
),

-- A SOC 2010 code whose 2018 parts are exactly one BLS aggregate's parts (25-9041 Teacher Assistants ->
-- 25-9042/43/49 = aggregate 25-9045) lands on the aggregate row, where every fact publishes it.
soc_2010_pairs as (
    select x.soc_2010 as source_code, coalesce(agg.source_code, x.soc_2018) as soc_code
    from {{ source('staging', 'stg_bls__soc_2010_2018') }} as x
    left join (
        select a.source_code, a.soc_code
        from aggregate_parts as a
        where (select array_agg(soc_code order by soc_code) from aggregate_parts p where p.source_code = a.source_code)
            = (select array_agg(soc_2018 order by soc_2018) from {{ source('staging', 'stg_bls__soc_2010_2018') }} y
               where y.soc_2010 in (select soc_2010 from {{ source('staging', 'stg_bls__soc_2010_2018') }} z where z.soc_2018 = a.soc_code))
    ) as agg on agg.soc_code = x.soc_2018
    group by 1, 2
),

pairs as (
    select 'soc_2018' as code_system, soc_code as source_code, soc_code from dim

    union all
    select 'soc_2010', source_code, soc_code from soc_2010_pairs
    union all
    -- group rows and BLS aggregates keep the same code in 2010-coded series (OEWS 2018 publishes 13-1020,
    -- 21-1018, 51-2028 ...), except the two minor groups in the seed and codes the crosswalk itself lists
    select 'soc_2010', soc_code, soc_code from dim where soc_level <> 'detailed'
        and soc_code not in (select soc_2010 from {{ ref('soc_2010_group_map') }})
        and soc_code not in (select soc_2010 from {{ source('staging', 'stg_bls__soc_2010_2018') }})

    union all
    select 'soc_2010_group', soc_2010, soc_code from {{ ref('soc_2010_group_map') }}

    union all
    select distinct 'oews_hybrid', h.oes_2019, h.soc_2018
    from {{ source('staging', 'stg_bls__oews_hybrid') }} as h
    where h.oes_2019 not in (select soc_code from dim)
    union all
    select distinct 'oews_hybrid', h.oes_2018, h.soc_2018
    from {{ source('staging', 'stg_bls__oews_hybrid') }} as h
    where h.oes_2018 not in (select soc_code from dim)
      and h.oes_2018 not in (select oes_2019 from {{ source('staging', 'stg_bls__oews_hybrid') }})

    union all
    select 'group_parts', source_code, soc_code from aggregate_parts
    union all
    select 'group_parts', source_code, soc_code from structure_parts

    union all
    -- ACS: plain six-digit codes are SOC 2018 without the hyphen; X/Y groups come from the seed
    select distinct 'acs_socp', p.socp, left(p.socp, 2) || '-' || right(p.socp, 4)
    from {{ source('staging', 'stg_census__acs_pums_person') }} as p
    where p.socp ~ '^\d{6}$'
      -- plain PUMS codes are detailed codes or whole SOC groups (252020); a group lands on its own dim_job row
      and left(p.socp, 2) || '-' || right(p.socp, 4) in (select soc_code from dim)
    union all
    select 'acs_socp', socp, soc_code from {{ ref('acs_socp_group_map') }}

    union all
    select 'onet_soc', onet_soc_code, soc_code from {{ source('staging', 'stg_onet__occupation') }}
),

basis_year as (
    select * from (values
        ('soc_2010', 2021), ('oews_hybrid', 2025), ('group_parts', 2025), ('acs_socp', 2022)
    ) as v(code_system, oews_year)
),

oews as (
    select year, occ_code, employment
    from {{ source('staging', 'stg_bls__oews_metro_occupations') }}
    where soc_edition = '2018' and employment is not null
),

national as (
    select soc_code, employment_2025_k
    from {{ source('staging', 'stg_bls__ep_occupation_projections') }}
    where occupation_type = 'Line item'
),

sized as (
    select
        p.code_system,
        p.source_code,
        p.soc_code,
        count(*) over (partition by p.code_system, p.source_code) as n_parts,
        o.employment as emp_oews,
        n.employment_2025_k as emp_national
    from pairs as p
    left join basis_year as b on b.code_system = p.code_system
    left join oews as o on o.year = b.oews_year and o.occ_code = p.soc_code
    left join national as n on n.soc_code = p.soc_code
),

grouped as (
    select
        code_system,
        source_code,
        bool_and(emp_oews is not null) and sum(emp_oews) > 0 as use_oews,
        bool_and(emp_national is not null) and sum(emp_national) > 0 as use_national,
        sum(emp_oews) as sum_oews,
        sum(emp_national) as sum_national
    from sized
    group by code_system, source_code
)

select
    s.code_system,
    s.source_code,
    s.soc_code,
    s.n_parts,
    case
        when s.n_parts = 1 then 1.0
        when g.use_oews then s.emp_oews::numeric / g.sum_oews
        when g.use_national then s.emp_national::numeric / g.sum_national
        else 1.0 / s.n_parts
    end as weight,
    case
        when s.n_parts = 1 then 'single'
        when g.use_oews then 'oews_ny_metro_' || b.oews_year
        when g.use_national then 'bls_national_2025'
        else 'equal'
    end as weight_basis
from sized as s
join grouped as g on g.code_system = s.code_system and g.source_code = s.source_code
left join basis_year as b on b.code_system = s.code_system
