-- D14 regression (plan §5): 2024 first-major awards at the NYC institutions in dim_college whose major x level has no
-- passing job at 15% (link_status not linked or dispersed) are 12,351 at the associate's level and 5,153 at the
-- bachelor's level; of those, the majors with no crosswalk link hold 513 and 1,575. D20: the dispersed bachelor's
-- majors (passing job, ACS field holds it at the population rate) are 73 in the dim (22 with 2024 awards > 0) and
-- carry 12,067 of the 2024 awards. Every award row finds a dim_major_award row.
-- D57: 12,382 and 5,288 before unrated detailed codes were linked through their rated BLS group (31 + 135 awards:
-- Clinical/Medical Laboratory Technician (associate's); Clinical Laboratory Science, Elementary Special Education and
-- Education, General (bachelor's) now pass).
with awards as (
    select c.cip_code, c.award_level, sum(c.awards_total) as awards
    from {{ source('staging', 'stg_ipeds__completions') }} as c
    join {{ ref('dim_college') }} as k on k.unitid = c.unitid
    where c.year = 2024 and c.major_number = 1 and c.award_level in (3, 5)
    group by c.cip_code, c.award_level
),

labeled as (
    select a.award_level, a.awards, d.link_status
    from awards as a
    left join {{ ref('dim_major_award') }} as d on d.cip_code = a.cip_code and d.award_level = a.award_level
)

select 'unlabeled_awards' as problem, award_level::text || ': ' || sum(awards)::text as detail
from labeled where link_status is null group by award_level
union all
select 'no_passing_job ' || award_level::text, sum(awards)::text
from labeled where link_status not in ('linked', 'dispersed')
group by award_level
having (award_level = 3 and sum(awards) <> 12351) or (award_level = 5 and sum(awards) <> 5153)
union all
select 'not_in_crosswalk ' || award_level::text, sum(awards)::text
from labeled where link_status = 'not_in_crosswalk'
group by award_level
having (award_level = 3 and sum(awards) <> 513) or (award_level = 5 and sum(awards) <> 1575)
union all
select 'dispersed awards (D20)', sum(awards)::text
from labeled where link_status = 'dispersed'
having sum(awards) <> 12067
union all
select 'dispersed majors (D20)', count(*) filter (where award_level = 5)::text || ' at bachelor level, '
       || count(*) filter (where award_level <> 5)::text || ' at other levels'
from {{ ref('dim_major_award') }} where link_status = 'dispersed'
having count(*) filter (where award_level = 5) <> 73 or count(*) filter (where award_level <> 5) > 0
