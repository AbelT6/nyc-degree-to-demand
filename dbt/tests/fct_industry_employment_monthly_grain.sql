-- fct_industry_employment_monthly is unique at year x month x series_code (plan docs/step4-facts-plan.md §3d).
select year, month, series_code, count(*) as n
from {{ ref('fct_industry_employment_monthly') }}
group by 1, 2, 3
having count(*) > 1
