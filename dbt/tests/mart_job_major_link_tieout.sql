-- Plan §5 tie-outs for mart.job_major_link (nb 42 §2, §4 under D20; the jobs side of the S11 grid lives here and on
-- job_profile). Tolerances: graduates and openings ±1 (the weights and the D1 fill carry decimals); counts exact;
-- the equality with mart.job_profile ±0.01 on every job the profile carries.
with jobs as (
    select distinct
        soc_code, soc_title, job_graduates_2024_linked, job_openings_nyc, job_graduates_per_opening,
        job_projected_change_2022_2032_pct
    from {{ ref('mart_job_major_link') }}
),

growing_many as (
    -- "growing · many" on the jobs side: more than one graduate per opening and the job projected to grow
    select count(*) as n_jobs, sum(job_graduates_2024_linked) as graduates, sum(job_openings_nyc) as openings
    from jobs
    where job_graduates_per_opening > 1.0 and job_projected_change_2022_2032_pct > 0
),

crowded as (
    select count(*) as n_jobs, max(soc_code) as soc_code
    from jobs
    where job_graduates_per_opening > 1.0 and job_projected_change_2022_2032_pct <= 0
),

vs_profile as (
    select count(*) filter (where abs(coalesce(j.job_graduates_2024_linked, 0) - coalesce(p.graduates_2024_linked, 0)) > 0.01) as graduates_mismatch,
           count(*) filter (where p.graduates_per_opening is not null
                              and abs(coalesce(j.job_graduates_per_opening, -1) - p.graduates_per_opening) > 0.0001) as ratio_mismatch
    from jobs as j
    join {{ ref('mart_job_profile') }} as p on p.soc_code = j.soc_code
),

checks as (
    select 'Managers All Other 11-9199 graduates 2024 from linked majors' as check_name, 2688::numeric as expected, job_graduates_2024_linked::numeric as got, 1::numeric as tolerance from jobs where soc_code = '11-9199'
    union all
    select 'Managers All Other 11-9199 openings', 859, job_openings_nyc, 1 from jobs where soc_code = '11-9199'
    union all
    select 'Secondary School Teachers 25-2031 graduates 2024', 4493, job_graduates_2024_linked, 1 from jobs where soc_code = '25-2031'
    union all
    select 'Secondary School Teachers 25-2031 openings', 2627, job_openings_nyc, 1 from jobs where soc_code = '25-2031'
    union all
    select 'jobs whose linked graduates differ from mart.job_profile', 0, graduates_mismatch, 0 from vs_profile
    union all
    select 'jobs whose graduates per opening differ from mart.job_profile', 0, ratio_mismatch, 0 from vs_profile
    union all
    select 'growing · many jobs (ratio > 1, projected growth > 0)', 21, n_jobs, 0 from growing_many
    union all
    select 'growing · many graduates', 13739, graduates, 1 from growing_many
    union all
    select 'growing · many openings', 7389, openings, 1 from growing_many
    union all
    select 'crowded jobs (ratio > 1, projected change <= 0)', 1, n_jobs, 0 from crowded
    union all
    select 'the crowded job is Mechanical Drafters 17-3013', 1, (soc_code = '17-3013')::int, 0 from crowded
)

select *
from checks
where got is null or abs(got - expected) > tolerance
