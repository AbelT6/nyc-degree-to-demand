-- fct_job_software is unique at soc_code x product (plan docs/step4-facts-plan.md §3b, §4 item 8).
select soc_code, product, count(*) as n
from {{ ref('fct_job_software') }}
group by 1, 2
having count(*) > 1
