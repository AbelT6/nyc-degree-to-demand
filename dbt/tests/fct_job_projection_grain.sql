-- fct_job_projection is unique at edition x soc_code (plan docs/step3-d1-fill-plan.md §6.1).
select edition, soc_code, count(*) as n
from {{ ref('fct_job_projection') }}
group by 1, 2
having count(*) > 1
