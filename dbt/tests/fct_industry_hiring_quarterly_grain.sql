-- fct_industry_hiring_quarterly is unique at year x quarter x area_key x industry_key x breakdown x group_code (plan docs/step4-facts-plan.md §3d).
select year, quarter, area_key, industry_key, breakdown, group_code, count(*) as n
from {{ ref('fct_industry_hiring_quarterly') }}
group by 1, 2, 3, 4, 5, 6
having count(*) > 1
