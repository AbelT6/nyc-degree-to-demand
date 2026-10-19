-- fct_postings_revelio_monthly is unique at month x area_key x soc_group_code x industry_code_source (plan §3f).
select month, area_key, soc_group_code, industry_code_source, count(*) as n
from {{ ref('fct_postings_revelio_monthly') }}
group by 1, 2, 3, 4
having count(*) > 1
