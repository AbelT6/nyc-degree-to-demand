-- The five kinds of major (release-plan §7b, study-frame-brainstorm §4) reproduce the verified counts: majors, 2024
-- degrees at NYC colleges (first majors, major_supply_demand) and majors with 2024 graduates. Regression pin, as
-- dim_major_award_d14_regression: a data refresh that moves these must update the docs that cite them.
-- Second check: each major's degree_jobs_openings equals the sum of job_profile openings over its linked jobs in the
-- study (the Major page's jobs table), so the card and the table agree.
-- D57: was 1,120 / 2,036 / 73 / 667 / 754 majors and 37,166 / 15,582 / 12,067 / 6,322 / 2,088 degrees before links
-- through rated BLS group codes (4 majors with graduates left transfer). D58: a group linked only in part counts by that
-- part's share; Special Education, General (bachelor's) still leans to (Special Ed) Teaching Assistants, outside the study.
with k as (
    select m.kind_key, count(*) as majors, sum(s.awards_2024_nyc) as degrees, count(*) filter (where m.has_graduates_2024) as with_grads
    from {{ ref('mart_dim_major') }} as m
    join {{ ref('mart_major_supply_demand') }} as s on s.major_award_key = m.major_award_key
    group by m.kind_key
),
expected (kind_key, majors, degrees, with_grads) as (
    values ('degree_jobs', 1140, 37125, 270), ('transfer', 2008, 15416, 149), ('dispersed', 73, 12067, 22),
           ('outside_jobs', 675, 6529, 77), ('no_link', 754, 2088, 27)
),
kind_diffs as (
    select coalesce(e.kind_key, k.kind_key) as kind_key, 'kind counts' as check_name
    from expected as e
    full join k on k.kind_key = e.kind_key
    where k.majors is distinct from e.majors or k.degrees is distinct from e.degrees or k.with_grads is distinct from e.with_grads
),
table_sum as (
    select lk.major_award_key, sum(coalesce(p.annual_openings_avg, 0)) as openings
    from {{ ref('mart_job_major_link') }} as lk
    join {{ ref('mart_job_profile') }} as p on p.soc_code = lk.soc_code
    group by lk.major_award_key
),
open_diffs as (
    select m.major_award_key as kind_key, 'degree_jobs_openings vs job_profile' as check_name
    from {{ ref('mart_dim_major') }} as m
    left join table_sum as t on t.major_award_key = m.major_award_key
    where abs(m.degree_jobs_openings - coalesce(t.openings, 0)) > 0.01
)
select * from kind_diffs
union all
select * from open_diffs
