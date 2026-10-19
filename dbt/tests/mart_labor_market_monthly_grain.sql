-- mart.labor_market_monthly grain: one row per month_start x measure_key x seasonal.
select month_start, measure_key, seasonal, count(*) as n
from {{ ref('mart_labor_market_monthly') }}
group by 1, 2, 3
having count(*) > 1
