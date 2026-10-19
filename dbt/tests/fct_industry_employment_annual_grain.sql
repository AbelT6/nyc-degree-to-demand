-- fct_industry_employment_annual is unique at year x area_key x ownership x industry_key (plan docs/step4-facts-plan.md §3d, §4).
select year, area_key, ownership, industry_key, count(*) as n
from {{ ref('fct_industry_employment_annual') }}
group by 1, 2, 3, 4
having count(*) > 1
