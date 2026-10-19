-- Split rows conserve the published values (plan §6.5): for 2020-30, the sum over a hybrid code's SOC 2018 parts
-- equals the published aggregate (base, projected, openings), and no part is shared between two hybrid codes.
-- For the two SOC 2010 editions, the fact's leaf sum equals the staging leaf sum (weights sum to 1, so exact).
with hybrid_2020 as (
    select s.soc_code, s.base_employment, s.projected_employment, s.annual_openings_avg
    from {{ source('staging', 'stg_nysdol__occupation_projections') }} as s
    where s.edition = '2020-2030'
      and not exists (select 1 from {{ ref('dim_job') }} d where d.soc_code = s.soc_code)
),

parts as (
    select h.soc_code, b.soc_code as part_code
    from hybrid_2020 as h
    join {{ ref('bridge_job_code') }} as b on b.code_system = 'oews_hybrid' and b.source_code = h.soc_code
),

part_sums as (
    select p.soc_code,
        sum(f.base_employment) as base_sum,
        sum(f.projected_employment) as projected_sum,
        sum(f.annual_openings_avg) as openings_sum
    from parts as p
    join {{ ref('fct_job_projection') }} as f on f.edition = '2020-2030' and f.soc_code = p.part_code
    group by p.soc_code
),

leaf_sums as (
    select s.edition,
        sum(s.base_employment) as staging_leaves,
        (select sum(f.base_employment) from {{ ref('fct_job_projection') }} f where f.edition = s.edition and f.is_leaf) as fact_leaves
    from {{ source('staging', 'stg_nysdol__occupation_projections') }} as s
    where s.is_leaf and s.edition in ('2016-2026', '2018-2028', '2020-2030')
    group by s.edition
)

select 'hybrid_2020_not_conserved' as problem, h.soc_code as detail
from hybrid_2020 as h
left join part_sums as p on p.soc_code = h.soc_code
where p.soc_code is null
   or abs(p.base_sum - h.base_employment) > 1e-6
   or abs(p.projected_sum - h.projected_employment) > 1e-6
   or abs(p.openings_sum - h.annual_openings_avg) > 1e-6
union all
select 'hybrid_2020_part_shared', part_code from parts group by part_code having count(*) > 1
union all
select 'edition_leaf_sum_changed', edition || ' ' || (fact_leaves - staging_leaves)::text
from leaf_sums
where abs(fact_leaves - staging_leaves) > 1e-6
