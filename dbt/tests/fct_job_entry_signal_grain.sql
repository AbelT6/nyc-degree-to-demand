-- fct_job_entry_signal is unique at soc_code x measure (plan docs/step4-facts-plan.md §3b, D5).
select soc_code, measure, count(*) as n
from {{ ref('fct_job_entry_signal') }}
group by 1, 2
having count(*) > 1
