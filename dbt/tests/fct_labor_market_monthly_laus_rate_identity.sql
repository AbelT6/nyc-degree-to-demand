-- LAUS identity (plan §4 item 18): unemployment (04) / labor force (06) x 100 = unemployment rate (03) within 0.1
-- for every area x seasonal x year x period x month where all three exist.
with w as (
    select area_key, seasonal, year, period_type, month,
        max(value) filter (where measure_code = '03') as rate,
        max(value) filter (where measure_code = '04') as unemployment,
        max(value) filter (where measure_code = '06') as labor_force
    from {{ ref('fct_labor_market_monthly') }}
    where source_key = 'bls_la'
    group by 1, 2, 3, 4, 5
)

select *, unemployment / labor_force * 100 as rate_computed
from w
where rate is not null and unemployment is not null and labor_force is not null
  and abs(unemployment / labor_force * 100 - rate) > 0.1
