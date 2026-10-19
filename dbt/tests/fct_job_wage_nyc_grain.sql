-- fct_job_wage_nyc is unique at vintage x area_key x soc_code (plan docs/step4-facts-plan.md §3a).
select vintage, area_key, soc_code, count(*) as n
from {{ ref('fct_job_wage_nyc') }}
group by 1, 2, 3
having count(*) > 1
