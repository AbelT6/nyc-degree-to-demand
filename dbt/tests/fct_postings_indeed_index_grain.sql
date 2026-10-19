-- fct_postings_indeed_index is unique at date x area_key x category x measure (plan §3f).
select date, area_key, category, measure, count(*) as n
from {{ ref('fct_postings_indeed_index') }}
group by 1, 2, 3, 4
having count(*) > 1
