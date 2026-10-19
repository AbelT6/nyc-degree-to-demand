-- D24 A: in the three industry views that hold totals and parts on the same rows, the is_leaf_row rows sum to their
-- is_total_row. Tolerances from the sources: QWI sectors vs the all-industries row differ by noise infusion (max
-- 0.034% on hires, 0.007% on separations, 2019-2025) -> 0.1%; QCEW private sectors vs private '00' differ by
-- rounding and undisclosed cells (max 0.81%, Bronx) -> 1%; the D18 estimate sectors vs NYC 'Total, All Ownerships'
-- '00' -> 0.01% (government-by-sector rounding; max gap 69 jobs, 2020); CES top supersectors vs Total Nonfarm -> exact (published in hundreds).
with hiring as (
    select
        year,
        sum(hires_new)     filter (where is_leaf_row)  as leaf_hires,
        max(hires_new)     filter (where is_total_row) as total_hires,
        sum(separations)   filter (where is_leaf_row)  as leaf_sep,
        max(separations)   filter (where is_total_row) as total_sep,
        sum(emp_begin_sum) filter (where is_leaf_row)  as leaf_emp,
        max(emp_begin_sum) filter (where is_total_row) as total_emp
    from {{ ref('mart_industry_hiring_trend') }}
    group by 1
),

qcew_private as (
    select
        area_key, year,
        sum(employment) filter (where is_leaf_row)  as leaf_emp,
        max(employment) filter (where is_total_row) as total_emp
    from {{ ref('mart_industry_employment_trend') }}
    where ownership = 'Private'
    group by 1, 2
),

qcew_estimate as (
    select
        e.year,
        e.leaf_emp,
        t.employment as total_emp
    from (
        select year, sum(employment) as leaf_emp
        from {{ ref('mart_industry_employment_trend') }}
        where area_key = 'nyc' and ownership = 'All ownerships (estimate)' and is_leaf_row
        group by 1
    ) as e
    join {{ ref('mart_industry_employment_trend') }} as t
        on t.year = e.year and t.area_key = 'nyc' and t.ownership = 'Total, All Ownerships' and t.is_total_row
),

ces as (
    select
        month_start,
        sum(employment) filter (where is_leaf_row)                as leaf_emp,
        max(employment) filter (where series_code = '00000000')  as total_emp
    from {{ ref('mart_industry_employment_monthly') }}
    group by 1
),

checks as (
    select 'QWI new hires, sectors vs 00, ' || year as check_name, total_hires::numeric as expected, leaf_hires::numeric as got, 0.001 * total_hires as tolerance from hiring
    union all
    select 'QWI separations, sectors vs 00, ' || year, total_sep, leaf_sep, 0.001 * total_sep from hiring where total_sep is not null
    union all
    select 'QWI beginning jobs, sectors vs 00, ' || year, total_emp, leaf_emp, 0.001 * total_emp from hiring
    union all
    select 'QCEW private sectors vs 00, ' || area_key || ' ' || year, total_emp, leaf_emp, 0.01 * total_emp from qcew_private
    union all
    select 'QCEW all-ownership estimate sectors vs Total All Ownerships 00, nyc ' || year, total_emp, leaf_emp, 0.0001 * total_emp from qcew_estimate
    union all
    select 'CES top supersectors vs Total Nonfarm, ' || month_start, total_emp, leaf_emp, 0 from ces
    union all
    select 'CES months with no Total Nonfarm row (must be 0)', 0, (select count(*) from ces where total_emp is null), 0
)

select *
from checks
where got is null or abs(got - expected) > tolerance
