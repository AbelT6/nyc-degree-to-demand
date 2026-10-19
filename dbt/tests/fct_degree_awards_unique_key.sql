-- fct_degree_awards grain: year x unitid x cip_code x major_number x award_level is unique (plan §3c, §4 item 9).
select year, unitid, cip_code, major_number, award_level, count(*) as n
from {{ ref('fct_degree_awards') }}
group by year, unitid, cip_code, major_number, award_level
having count(*) > 1
