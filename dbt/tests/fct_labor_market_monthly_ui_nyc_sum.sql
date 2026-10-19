-- UI 'nyc' rows equal the sum of the five borough rows for the same month and measure, and exist for every month
-- the boroughs have (plan §3f: nyc = sum of the five counties, note set on those rows).
with boroughs as (
    select measure_code, year, month, sum(value) as borough_sum, count(*) as n
    from {{ ref('fct_labor_market_monthly') }}
    where source_key = 'nysdol_ui_beneficiaries' and area_key <> 'nyc'
    group by 1, 2, 3
),

nyc as (
    select measure_code, year, month, value, note
    from {{ ref('fct_labor_market_monthly') }}
    where source_key = 'nysdol_ui_beneficiaries' and area_key = 'nyc'
)

select coalesce(b.measure_code, n.measure_code) as measure_code, coalesce(b.year, n.year) as year,
    coalesce(b.month, n.month) as month, b.n as borough_rows, b.borough_sum, n.value as nyc_value, n.note
from boroughs as b
full join nyc as n on n.measure_code = b.measure_code and n.year = b.year and n.month = b.month
where b.measure_code is null or n.measure_code is null or b.n <> 5 or b.borough_sum <> n.value
   or n.note <> 'sum of five counties, rounded source values'
