-- Plan §5 tie-outs for mart.job_employment_trend (nb 40 §2): degree-reachable NYC estimate (every level the estimate
-- publishes, as the notebook summed it) 2019 -> 2025 = 1.22 M -> 1.45 M (±5,000 on the rounded millions), +18.9%
-- (±0.0005); every other entry level -2.1% (±0.0005). Row accounting: the NYC rows equal the estimate fact 2019-2025
-- and the metro rows equal the OEWS detailed + major rows 2019-2025 (no fan-out through dim_job).
with v as (
    select * from {{ ref('mart_job_employment_trend') }}
),

nyc as (
    select
        is_degree_entry,
        sum(nyc_employment_est) filter (where year = 2019) as e2019,
        sum(nyc_employment_est) filter (where year = 2025) as e2025
    from v
    where area_key = 'nyc'
    group by 1
),

checks as (
    select 'degree-reachable NYC estimate 2019' as check_name, 1220000::numeric as expected, e2019 as got, 5000::numeric as tolerance from nyc where is_degree_entry
    union all
    select 'degree-reachable NYC estimate 2025', 1450000, e2025, 5000 from nyc where is_degree_entry
    union all
    select 'degree-reachable NYC growth 2019 -> 2025', 0.189, e2025 / e2019 - 1, 0.0005 from nyc where is_degree_entry
    union all
    select 'other entry levels NYC growth 2019 -> 2025', -0.021, e2025 / e2019 - 1, 0.0005 from nyc where not is_degree_entry
    union all
    select 'NYC rows = estimate fact rows 2019-2025',
        (select count(*) from {{ ref('fct_job_employment_nyc_est') }} where year between 2019 and 2025),
        (select count(*) from v where area_key = 'nyc'), 0
    union all
    select 'metro rows = OEWS detailed + major rows 2019-2025',
        (select count(*) from {{ ref('fct_job_employment_wage_annual') }} where year between 2019 and 2025 and occ_level in ('detailed', 'major')),
        (select count(*) from v where area_key = 'ny_metro'), 0
    union all
    select 'NYC estimate rows with null employment (must be 0; metro rows may be wage-only)', 0,
        (select count(*) from v where area_key = 'nyc' and nyc_employment_est is null), 0
    union all
    select 'metro rows with neither employment nor an annual wage percentile = the same rows in the OEWS fact (4: one hourly-only, three all-suppressed 2021 physician rows)',
        (select count(*) from {{ ref('fct_job_employment_wage_annual') }} where area_key = 'ny_metro' and year between 2019 and 2025
         and occ_level in ('detailed', 'major') and employment is null and annual_p25 is null and annual_p50 is null),
        (select count(*) from v where area_key = 'ny_metro' and metro_employment is null and annual_p25 is null and annual_p50 is null), 0
    union all
    select 'NYC total 2025 = QCEW NYC total carried by the estimate (sum of every level)',
        (select sum(employment_est) from {{ ref('fct_job_employment_nyc_est') }} where year = 2025),
        (select sum(nyc_employment_est) from v where year = 2025), 1
    union all
    select 'D24 A: no row carries both columns', 0,
        (select count(*) from v where nyc_employment_est is not null and metro_employment is not null), 0
    union all
    select 'D24 A: metro major-group rows sum to the metro all-occupations total 2025 (OEWS rounding, ±100)',
        (select employment from {{ ref('fct_job_employment_wage_annual') }} where area_key = 'ny_metro' and year = 2025 and occ_level = 'total'),
        (select sum(metro_employment) from v where year = 2025 and is_group_total), 100
    union all
    select 'D24 A: metro detailed rows sum to the total less suppressed cells 2025 (within 1%)',
        (select employment from {{ ref('fct_job_employment_wage_annual') }} where area_key = 'ny_metro' and year = 2025 and occ_level = 'total'),
        (select sum(metro_employment) from v where year = 2025 and not is_group_total),
        (select 0.01 * employment from {{ ref('fct_job_employment_wage_annual') }} where area_key = 'ny_metro' and year = 2025 and occ_level = 'total')
)

select *
from checks
where got is null or abs(got - expected) > tolerance
