-- fct_labor_market_monthly is unique at source_key x area_key x measure_code x seasonal x year x period_type x month
-- (plan §3f; month = 0 on annual rows).
select source_key, area_key, measure_code, seasonal, year, period_type, month, count(*) as n
from {{ ref('fct_labor_market_monthly') }}
group by 1, 2, 3, 4, 5, 6, 7
having count(*) > 1
