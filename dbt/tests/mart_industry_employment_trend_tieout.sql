-- Plan §5 tie-outs for the QCEW trend (nb 41): private jobs, all industries ('00'), 2019 -> 2025:
--   Manhattan -40 k, Brooklyn +129 k, NYC +158 k (+4.0%)  -> tolerance ±500 jobs on the change (the plan quotes
--   thousands), ±0.005 on the NYC percent. The all-ownership estimate rows must add to the QCEW NYC all-ownership
--   total within ±5 jobs every year, 2020 within ±100 (D18; the same tolerances as the core audit test:
--   BLS local government is +68 vs NYS DOL in 2020).
with t as (
    select *
    from {{ ref('mart_industry_employment_trend') }}
    where ownership = 'Private' and industry_key = '00' and year = 2025
),

est as (
    select e.year, sum(e.employment) as est_total, max(q.employment) as qcew_total
    from {{ ref('mart_industry_employment_trend') }} e
    join {{ ref('mart_industry_employment_trend') }} q
      on q.year = e.year and q.area_key = 'nyc' and q.ownership = 'Total, All Ownerships' and q.industry_key = '00'
    where e.ownership = 'All ownerships (estimate)'
    group by e.year
),

checks as (
    select 'Manhattan private change 2019 -> 2025' as check_name, -40000::numeric as expected, change_vs_2019 as got, 500::numeric as tolerance
    from t where area_key = 'manhattan'
    union all
    select 'Brooklyn private change 2019 -> 2025', 129000, change_vs_2019, 500
    from t where area_key = 'brooklyn'
    union all
    select 'NYC private change 2019 -> 2025', 158000, change_vs_2019, 500
    from t where area_key = 'nyc'
    union all
    select 'NYC private pct change 2019 -> 2025', 0.040, pct_change_vs_2019, 0.005
    from t where area_key = 'nyc'
    union all
    select 'all-ownership estimate = QCEW NYC total, ' || year, qcew_total, est_total, case when year = 2020 then 100 else 5 end
    from est
)

select *
from checks
where got is null or abs(got - expected) > tolerance
