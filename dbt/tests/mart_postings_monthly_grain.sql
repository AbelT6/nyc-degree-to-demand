-- mart.postings_monthly is unique at source_key x area_key x group_code x month_start (plan §4f).
select source_key, area_key, group_code, month_start, count(*) as n
from {{ ref('mart_postings_monthly') }}
group by 1, 2, 3, 4
having count(*) > 1
