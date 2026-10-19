-- fct_job_employment_wage_annual is unique at year x area_key x soc_code (plan docs/step4-facts-plan.md §3a).
select year, area_key, soc_code, count(*) as n
from {{ ref('fct_job_employment_wage_annual') }}
group by 1, 2, 3
having count(*) > 1
