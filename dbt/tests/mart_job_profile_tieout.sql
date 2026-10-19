-- Plan §5 tie-outs for mart.job_profile (nb 40 §3, §7, §7c; nb 42 §2 under D20; nb 43 §2-§4). Tolerances:
--   sums of openings ±1 (the leaf rows carry the D1 fill's decimals); shares and rates ±0.0005 (one decimal of a
--   percent) unless the notebook printed four decimals (RN separation rate 0.5239: ±0.0001); counts exact; wages ±1.
with p as (
    select * from {{ ref('mart_job_profile') }}
),

leaves as (
    select * from p where has_projection
),

pay as (
    -- nb 43 §3: NY-metro real change 2019 -> 2025, weighted by 2025 metro OEWS employment, degree-reachable detailed jobs
    select
        sum(metro_real_p25_change_2019_2025 * metro_oews_employment_2025) / sum(metro_oews_employment_2025) as p25_change,
        sum(metro_real_p50_change_2019_2025 * metro_oews_employment_2025) / sum(metro_oews_employment_2025) as p50_change
    from p
    where soc_level = 'detailed' and metro_oews_employment_2025 is not null
        and metro_real_p25_change_2019_2025 is not null and metro_real_p50_change_2019_2025 is not null
),

checks as (
    select 'rows: 221 detailed + 4 degree-reachable leaf codes' as check_name, 225::numeric as expected, count(*)::numeric as got, 0::numeric as tolerance from p
    union all
    select 'degree-reachable 2022-32 leaves', 186, count(*), 0 from leaves
    union all
    select 'sum annual openings on the 186 leaves', 136787, sum(annual_openings_avg), 1 from leaves
    union all
    select 'sum growth openings on the 186 leaves', 17894, sum(growth_openings_avg), 1 from leaves
    union all
    select 'degree-reachable growth share', 0.131, sum(growth_openings_avg) / sum(annual_openings_avg), 0.0005 from leaves
    union all
    select 'all-leaves NYC growth share (band cutoff, computed over every 2022-32 leaf)', 0.097, max(all_leaves_growth_share), 0.0005 from leaves
    union all
    select 'band growth-led', 15, count(*) filter (where growth_share_band = 'growth-led'), 0 from leaves
    union all
    select 'band mixed', 110, count(*) filter (where growth_share_band = 'mixed'), 0 from leaves
    union all
    select 'band mostly replacement', 47, count(*) filter (where growth_share_band = 'mostly replacement'), 0 from leaves
    union all
    select 'band shrinking', 14, count(*) filter (where growth_share_band = 'shrinking'), 0 from leaves
    union all
    select 'Registered Nurses industry separation rate 2024', 0.5239, industry_separation_rate_2024, 0.0001 from p where soc_code = '29-1141'
    union all
    select 'Registered Nurses churn coverage', 0.959, industry_churn_coverage, 0.0005 from p where soc_code = '29-1141'
    union all
    select 'Airline Pilots 53-2011 page separation rate = 48-49 2019 rate (D24 C)', 0.618, industry_separation_rate_page, 0.005 from p where soc_code = '53-2011'
    union all
    select 'Airline Pilots 53-2011 page new-hire rate = 48-49 2019 rate (D24 C)', 0.613, industry_new_hire_rate_page, 0.005 from p where soc_code = '53-2011'
    union all
    select 'Registered Nurses page rate = 2024 rate (no break sector share)', 0.5239, industry_separation_rate_page, 0.001 from p where soc_code = '29-1141'
    union all
    select 'job pages with at least half their jobs in 48-49 (D24 C)', 1, count(*) filter (where industry_churn_break_share >= 0.5), 0 from p
    union all
    select 'leaves with an industry churn rate', 184, count(industry_separation_rate_2024), 0 from leaves
    union all
    select 'leaves flagged under 70% churn coverage', 16, count(*) filter (where industry_churn_low_coverage), 0 from leaves
    union all
    select 'median NYC entry wage, degree-reachable detailed jobs', 69556, percentile_cont(0.5) within group (order by entry_wage), 1 from p where soc_level = 'detailed'
    union all
    select 'metro real p50 change 2019 -> 2025, degree-reachable (employment-weighted)', -0.012, p50_change, 0.0005 from pay
    union all
    select 'metro real p25 change 2019 -> 2025, degree-reachable (employment-weighted)', 0.014, p25_change, 0.0005 from pay
    union all
    select 'Managers All Other 11-9199 graduates 2024 (linked majors, D20 off dispersed)', 2688, graduates_2024_linked, 1 from p where soc_code = '11-9199'
    union all
    select 'Managers All Other 11-9199 annual openings', 859, annual_openings_avg, 1 from p where soc_code = '11-9199'
    union all
    select 'Managers All Other 11-9199 graduates per opening', 3.1, graduates_per_opening, 0.05 from p where soc_code = '11-9199'
    union all
    select 'Secondary School Teachers 25-2031 graduates 2024', 4493, graduates_2024_linked, 1 from p where soc_code = '25-2031'
    union all
    select 'Secondary School Teachers 25-2031 annual openings', 2627, annual_openings_avg, 1 from p where soc_code = '25-2031'
    union all
    select 'List 1 jobs rated Favorable or Very Favorable by NYS DOL', 20, count(*) filter (where employment_prospects in ('Favorable', 'Very Favorable')), 0 from p where in_list_1
    union all
    select 'List 1 size', 25, count(*) filter (where in_list_1), 0 from p
    union all
    select 'List 2 size', 25, count(*) filter (where in_list_2), 0 from p
    union all
    select 'degree-reachable detailed jobs with the ACS signal suppressed or missing (nb 43)', 85, count(*) filter (where acs_young_share_suppressed), 0 from p where soc_level = 'detailed'
)

select *
from checks
where got is null or abs(got - expected) > tolerance
