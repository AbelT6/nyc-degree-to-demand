-- The live In Demand lists (staging.stg_onet__in_demand_pct, retrieved 2026-10-16) name exactly the products O*NET 31.0
-- flags as in demand (staging.stg_onet__software.is_in_demand), code by code, for every O*NET-SOC code under the named
-- job-page jobs (254 codes; nb 16 §4, card onet_in_demand.md §5). Both directions: a flagged product missing from the
-- live list, or a listed product not flagged, is a row. Flags are OR'd per (code, product), as core.fct_job_software does.
with codes as (
    select o.onet_soc_code
    from {{ source('staging', 'stg_onet__occupation') }} as o
    join {{ ref('mart_job_profile') }} as p on p.soc_code = o.soc_code
    where not p.is_all_other
),

flags as (
    select s.onet_soc_code, s.product
    from {{ source('staging', 'stg_onet__software') }} as s
    join codes as c on c.onet_soc_code = s.onet_soc_code
    group by 1, 2
    having bool_or(s.is_in_demand)
),

live as (
    select d.onet_soc_code, d.product
    from {{ source('staging', 'stg_onet__in_demand_pct') }} as d
)

select coalesce(f.onet_soc_code, l.onet_soc_code) as onet_soc_code, coalesce(f.product, l.product) as product,
       case when l.product is null then 'flagged in 31.0, not on the live list' else 'on the live list, not flagged in 31.0' end as problem
from flags as f
full join live as l on l.onet_soc_code = f.onet_soc_code and l.product = f.product
where f.product is null or l.product is null
