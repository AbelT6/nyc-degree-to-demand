-- The groups with no openings weight are exactly the ones whose passing jobs have 0 openings in total (plan §4b edge
-- case): 10 associate's and 18 bachelor's majors; and dim_major_award.has_openings_weight agrees.
with groups as (
    select cip_code, award_level, bool_and(weight_openings is null) as no_weight, sum(openings_nyc) as openings
    from {{ ref('bridge_major_job') }}
    group by cip_code, award_level
)
select 'count ' || award_level::text as problem, count(*)::text as detail
from groups
where no_weight
group by award_level
having (award_level = 3 and count(*) <> 10) or (award_level = 5 and count(*) <> 18)
union all
select 'weight_vs_openings', cip_code || ' ' || award_level::text
from groups
where no_weight <> (openings = 0)
union all
select 'dim_major_award_disagrees', g.cip_code || ' ' || g.award_level::text
from groups as g
join {{ ref('dim_major_award') }} as d on d.cip_code = g.cip_code and d.award_level = g.award_level
where d.has_openings_weight = g.no_weight
