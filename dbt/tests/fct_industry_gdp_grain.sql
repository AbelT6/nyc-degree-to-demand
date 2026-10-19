-- fct_industry_gdp is unique at year x area_key x line_code (plan docs/step4-facts-plan.md §3d).
select year, area_key, line_code, count(*) as n
from {{ ref('fct_industry_gdp') }}
group by 1, 2, 3
having count(*) > 1
