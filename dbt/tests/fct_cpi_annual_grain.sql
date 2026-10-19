-- fct_cpi_annual is unique at year x area_key (plan docs/step4-facts-plan.md §3a, §4 item 1).
select year, area_key, count(*) as n
from {{ ref('fct_cpi_annual') }}
group by 1, 2
having count(*) > 1
