-- fct_job_attainment is unique at soc_code x attainment_level (plan docs/step4-facts-plan.md §3b).
select soc_code, attainment_level, count(*) as n
from {{ ref('fct_job_attainment') }}
group by 1, 2
having count(*) > 1
