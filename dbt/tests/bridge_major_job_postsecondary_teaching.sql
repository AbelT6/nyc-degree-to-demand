-- D2 design intent (plan §3b): at 15% the only postsecondary teaching code (25-1xxx) that passes is 25-1194
-- Career/Technical Education Teachers, Postsecondary, and only at the bachelor's level. Every other postsecondary
-- teacher has a doctoral entry level and a 14.1% bachelor's attainment share, so the filter removes them.
select soc_code, award_level, count(*) as n_rows
from {{ ref('bridge_major_job') }}
where soc_code like '25-1%'
  and not (soc_code = '25-1194' and award_level = 5)
group by soc_code, award_level
union all
select '25-1194 missing', 5, 0
where not exists (select 1 from {{ ref('bridge_major_job') }} where soc_code = '25-1194' and award_level = 5)
