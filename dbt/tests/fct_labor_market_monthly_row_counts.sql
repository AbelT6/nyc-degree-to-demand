-- Row accounting per source (plan §3f): JOLTS and LAUS rows = their staging tables (every staged area resolves to
-- dim_area, nothing dropped); UI rows = 2 measures x (5 borough rows + 1 nyc row) per staged NYC month; nyc sum
-- rows carry no series_id; UI annual rows do not exist.
select 'jolts' as problem, count(*)::text || ' vs staging ' || (select count(*) from {{ source('staging', 'stg_bls__jolts') }})::text as detail
from {{ ref('fct_labor_market_monthly') }}
where source_key = 'bls_jt'
having count(*) <> (select count(*) from {{ source('staging', 'stg_bls__jolts') }})
union all
select 'laus', count(*)::text || ' vs staging ' || (select count(*) from {{ source('staging', 'stg_bls__laus') }})::text
from {{ ref('fct_labor_market_monthly') }}
where source_key = 'bls_la'
having count(*) <> (select count(*) from {{ source('staging', 'stg_bls__laus') }})
union all
select 'ui', count(*)::text
from {{ ref('fct_labor_market_monthly') }}
where source_key = 'nysdol_ui_beneficiaries'
having count(*) <> 2 * (select count(*) from {{ source('staging', 'stg_nysdol__ui_beneficiaries') }} where is_nyc)
                 + 2 * (select count(distinct (year, month)) from {{ source('staging', 'stg_nysdol__ui_beneficiaries') }} where is_nyc)
union all
select 'ui_series_or_period', count(*)::text
from {{ ref('fct_labor_market_monthly') }}
where source_key = 'nysdol_ui_beneficiaries' and (series_id is not null or period_type <> 'month' or seasonal <> 'U')
having count(*) > 0
union all
select 'annual_month_convention', count(*)::text
from {{ ref('fct_labor_market_monthly') }}
where (period_type = 'month') <> (month between 1 and 12) or (period_type <> 'month') <> (month = 0 and period = 'M13')
having count(*) > 0
