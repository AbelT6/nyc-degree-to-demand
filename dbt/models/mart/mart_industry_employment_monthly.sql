-- mart.industry_employment_monthly: one row per month x CES series (NYC payroll jobs, latest vintage), Jan 2019
-- to the latest published month (docs/mart-plan.md §4e: "latest months" context only; nb 41).
-- All three CES levels are kept (aggregate, supersector, detail) with ces_level as the filter, so the sector
-- lines industry_profile quotes (e.g. Health Care and Social Assistance 65620000) read from the same view.
-- industry_key is the CES supersector row of dim_industry (CES-xx), not a NAICS sector: CES is a different
-- universe (payroll jobs by place of work, private education and health only in 65, all public ownership in 90).
-- 12-month change compares the same month a year earlier; the 2019 columns compare the same month in 2019.
-- D24 A, the three CES levels nest: is_total_row = the aggregate rows (Total Nonfarm, Total Private, Goods Producing,
-- Service-Providing, Private Service Providing); is_leaf_row = the 10 top supersectors (15, 30, 40, 50, 55, 60, 65,
-- 70, 80, 90), which sum to Total Nonfarm. The sub-supersectors (31, 32, 41, 42, 43) and the detail rows nest inside
-- a leaf and are neither: read them one series at a time. Base filter for a sum = is_leaf_row, one month.
{{ config(alias='industry_employment_monthly') }}

{% call mart_numeric_as_double() %}
with latest as (
    select max(vintage) as vintage
    from {{ ref('fct_industry_employment_monthly') }}
),

ces as (
    select
        m.year,
        m.month,
        make_date(m.year, m.month, 1)  as month_start,
        m.area_key,
        m.series_code,
        m.series_title,
        m.ces_level,
        m.supersector_code,
        m.industry_key,
        m.employment,
        m.vintage,
        m.source_key
    from {{ ref('fct_industry_employment_monthly') }} m
    join latest l on l.vintage = m.vintage
),

with_lags as (
    select
        c.*,
        lag(employment, 12) over (partition by area_key, series_code order by month_start) as employment_12m_ago,
        max(employment) filter (where year = 2019)
            over (partition by area_key, series_code, month)                                as employment_same_month_2019,
        max(month_start) over ()                                                            as latest_month
    from ces c
)

select
    month_start,
    year,
    month,
    area_key,
    series_code,
    series_title,
    ces_level,
    supersector_code,
    industry_key,
    ces_level = 'aggregate'                                         as is_total_row,
    ces_level = 'supersector'
        and supersector_code in ('15', '30', '40', '50', '55', '60', '65', '70', '80', '90') as is_leaf_row,
    employment,
    employment_12m_ago,
    employment - employment_12m_ago                                 as change_12m,
    case when employment_12m_ago > 0
         then employment / employment_12m_ago - 1 end               as pct_change_12m,
    employment_same_month_2019,
    employment - employment_same_month_2019                         as change_vs_2019,
    case when employment_same_month_2019 > 0
         then employment / employment_same_month_2019 - 1 end       as pct_change_vs_2019,
    month_start = latest_month                                      as is_latest_month,
    latest_month,
    vintage,
    source_key,
    'NYS DOL CES, vintage ' || vintage || ', NYC payroll jobs Jan 2019 - ' || to_char(latest_month, 'Mon YYYY') as as_of
from with_lags
{% endcall %}
