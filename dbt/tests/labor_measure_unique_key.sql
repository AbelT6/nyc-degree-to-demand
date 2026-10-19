-- ref.labor_measure is unique at source_key x measure_code (plan §3f seed).
select source_key, measure_code, count(*) as n
from {{ ref('labor_measure') }}
group by 1, 2
having count(*) > 1
