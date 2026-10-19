-- Every source_key x measure_code on the fact has a label row in ref.labor_measure, and every seed row is used
-- (plan §3f: the seed gives label and unit per source x measure).
select 'fact_without_label' as problem, f.source_key || ' ' || f.measure_code as detail
from (select distinct source_key, measure_code from {{ ref('fct_labor_market_monthly') }}) as f
left join {{ ref('labor_measure') }} as m on m.source_key = f.source_key and m.measure_code = f.measure_code
where m.measure_code is null
union all
select 'label_without_fact', m.source_key || ' ' || m.measure_code
from {{ ref('labor_measure') }} as m
left join (select distinct source_key, measure_code from {{ ref('fct_labor_market_monthly') }}) as f
    on f.source_key = m.source_key and f.measure_code = m.measure_code
where f.measure_code is null
