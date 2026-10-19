-- fct_job_skill is unique at soc_code x domain x element_id x scale (plan docs/step4-facts-plan.md §3b).
select soc_code, domain, element_id, scale, count(*) as n
from {{ ref('fct_job_skill') }}
group by 1, 2, 3, 4
having count(*) > 1
