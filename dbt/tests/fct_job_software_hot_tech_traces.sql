-- Plan §4 item 8: every hot-technology flag traces to a staging row carrying it for the same SOC and product, and
-- every staging hot-technology row survives the union; no (soc_code, product) pair is lost or invented.
with f as (
    select * from {{ ref('fct_job_software') }}
),
s as (
    select soc_code, product, bool_or(is_hot_technology) as is_hot_technology
    from {{ source('staging', 'stg_onet__software') }}
    group by soc_code, product
)
select f.soc_code, f.product, 'fact hot flag without a staging row' as reason
from f
left join s on s.soc_code = f.soc_code and s.product = f.product
where f.is_hot_technology and not coalesce(s.is_hot_technology, false)
union all
select s.soc_code, s.product, 'staging pair or hot flag missing from fact'
from s
left join f on f.soc_code = s.soc_code and f.product = s.product
where f.soc_code is null or (s.is_hot_technology and not f.is_hot_technology)
