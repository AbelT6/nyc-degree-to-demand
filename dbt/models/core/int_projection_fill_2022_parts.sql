-- Ephemeral (no table): the D1 fill candidates for the NYS DOL 2022-32 edition and their SOC 2018 parts,
-- one row per candidate x part (24 candidates, 60 parts). Read by audit_projection_fill_2022 (group arithmetic)
-- and fct_job_projection (part split). Plan: docs/step3-d1-fill-plan.md §3 steps 1-3; decision D15.
{{ config(materialized='ephemeral') }}

with src as (
    select edition, soc_code, soc_level, is_leaf, quality_flag
    from {{ source('staging', 'stg_nysdol__occupation_projections') }}
    where edition in ('2020-2030', '2022-2032')
),

dim as (
    select soc_code, minor_code from {{ ref('dim_job') }}
),

bridge as (
    select code_system, source_code, soc_code, weight, weight_basis
    from {{ ref('bridge_job_code') }}
    where code_system in ('oews_hybrid', 'group_parts')
),

structure as (
    select soc_code, minor_code from {{ source('staging', 'stg_bls__soc_2018_structure') }}
    where level = 'detailed'
),

bls_aggregates as (
    select distinct oes_2019 as soc_code
    from {{ source('staging', 'stg_bls__oews_hybrid') }}
    where is_bls_aggregate
),

-- Step 1: a candidate is (a) a 2022-32 row flagged publisher_defect, or (b) a 2020-30 leaf with no 2022-32 row that
-- is a BLS projection aggregate or a broad group, none of whose parts has a 2022-32 row.
candidates as (
    select soc_code, 'collapsed' as candidate_kind
    from src
    where edition = '2022-2032' and quality_flag = 'publisher_defect'

    union all

    select l.soc_code,
        case when l.soc_level = 'broad' then 'missing_broad' else 'missing_aggregate' end
    from src as l
    where l.edition = '2020-2030'
      and l.is_leaf
      and not exists (select 1 from src as c where c.edition = '2022-2032' and c.soc_code = l.soc_code)
      and (l.soc_level = 'broad' or l.soc_code in (select soc_code from bls_aggregates))
      and not exists (
          select 1
          from bridge as b
          join src as c on c.edition = '2022-2032' and c.soc_code = b.soc_code
          where b.source_code = l.soc_code
            and b.code_system = case when l.soc_level = 'broad' then 'group_parts' else 'oews_hybrid' end
      )
),

-- Step 2: parts and within-candidate weights from bridge_job_code (oews_hybrid for aggregates, group_parts for
-- broad groups; D12 weight chain).
parts as (
    select
        c.soc_code as fill_candidate,
        c.candidate_kind,
        b.soc_code as part_code,
        b.weight::numeric as weight,
        b.weight_basis,
        s.minor_code as part_minor_group
    from candidates as c
    join bridge as b
        on b.source_code = c.soc_code
       and b.code_system = case when c.candidate_kind = 'missing_broad' then 'group_parts' else 'oews_hybrid' end
    join structure as s on s.soc_code = b.soc_code
),

-- Step 3: the candidate's group is the minor group of its parts. When the parts span two minor groups (39-9098:
-- 39-4012 + 39-9099) the candidate is filled from the group its own code sits in (39-9000, where NYS DOL publishes
-- the row): the minor group whose non-zero prefix matches the code wins.
candidate_group as (
    select fill_candidate, part_minor_group as fill_group
    from (
        select
            fill_candidate,
            part_minor_group,
            row_number() over (
                partition by fill_candidate
                order by (fill_candidate like rtrim(part_minor_group, '0') || '%') desc, part_minor_group
            ) as rn
        from parts
        group by fill_candidate, part_minor_group
    ) as x
    where rn = 1
)

select
    g.fill_group,
    p.fill_candidate,
    p.candidate_kind,
    p.part_code,
    p.weight,
    p.weight_basis
from parts as p
join candidate_group as g on g.fill_candidate = p.fill_candidate
