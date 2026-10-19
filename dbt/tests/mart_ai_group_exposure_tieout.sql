-- Every check fails on a NULL value or a missing row (scalar subqueries; left joins on the endpoints).
-- Tie-outs for mart.ai_group_exposure (docs/mart-plan.md §5, nb 45). Tolerances: exposure 0.005 (two-decimal
-- rounding); the employment-weighted Pearson 0.005 (nb 45 printed two decimals); postings changes 0.5 pp.
--   * Computer and Mathematical 15-0000 exposure 0.35 at coverage 1.000; its NY postings -24% Jun 2022 -> latest
--     and +49% Jun 2025 -> latest (nb 45 §2).
--   * Employment-weighted Pearson of exposure_observed vs the postings change over the 22 civilian groups
--     (weights = the OEWS NY-metro May 2025 major-group row): Jun 2022 -> latest -0.38; Aug 2025 -> latest +0.49
--     (headline, D21); Jun 2025 -> latest +0.54 (sensitivity, D10).
--   * 23 rows (one per dim_job job group), 22 in the correlation; the 47 Indeed categories all land on a group;
--     the postings endpoints equal the sums in mart.postings_monthly for the same group and month.
with v as (
    select
        soc_code,
        exposure_observed::double precision as x,
        emp_metro_2025::double precision as w,
        pct_change_long::double precision as y_long,
        pct_change_1y::double precision as y_1y,
        pct_change_1y_jun::double precision as y_jun
    from {{ ref('mart_ai_group_exposure') }}
    where in_correlation
),

mu as (
    select
        sum(w * x) / sum(w) as mx,
        sum(w * y_long) / sum(w) as m_long,
        sum(w * y_1y) / sum(w) as m_1y,
        sum(w * y_jun) / sum(w) as m_jun,
        count(*) as n
    from v
),

pearson as (
    select
        mu.n,
        sum(w * (x - mx) * (y_long - m_long)) / sqrt(sum(w * power(x - mx, 2)) * sum(w * power(y_long - m_long, 2))) as r_long,
        sum(w * (x - mx) * (y_1y - m_1y)) / sqrt(sum(w * power(x - mx, 2)) * sum(w * power(y_1y - m_1y, 2))) as r_1y,
        sum(w * (x - mx) * (y_jun - m_jun)) / sqrt(sum(w * power(x - mx, 2)) * sum(w * power(y_jun - m_jun, 2))) as r_jun
    from v
    cross join mu
    group by mu.n
),

computer as (
    select * from {{ ref('mart_ai_group_exposure') }} where soc_code = '15-0000'
),

endpoints as (
    select g.soc_group_code, g.postings_jun2022, g.postings_aug2025, g.postings_jun2025, g.postings_latest,
        g.long_start, g.one_year_start, g.sensitivity_start, g.latest_month
    from {{ ref('mart_ai_group_exposure') }} as g
),

monthly as (
    select group_code, month_start, active_postings_sa
    from {{ ref('mart_postings_monthly') }}
    where source_key = 'revelio_rpls'
)

select 'computer_exposure' as problem, v::text as detail from (select (select exposure_observed from computer) as v) as x where v is null or abs(v - 0.35) > 0.005
union all
select 'computer_coverage', v::text from (select (select coverage from computer) as v) as x where v is null or abs(v - 1.0) > 0.0005
union all
select 'computer_pct_change_long', v::text from (select (select pct_change_long from computer) as v) as x where v is null or abs(v - (-0.24)) > 0.005
union all
select 'computer_pct_change_1y_jun', v::text from (select (select pct_change_1y_jun from computer) as v) as x where v is null or abs(v - 0.49) > 0.005
union all
select 'pearson_n', v::text from (select (select n from pearson) as v) as x where v is null or v <> 22
union all
select 'pearson_long', v::text from (select (select r_long from pearson) as v) as x where v is null or abs(v - (-0.38)) > 0.005
union all
select 'pearson_1y_aug2025', v::text from (select (select r_1y from pearson) as v) as x where v is null or abs(v - 0.49) > 0.005
union all
select 'pearson_1y_jun2025', v::text from (select (select r_jun from pearson) as v) as x where v is null or abs(v - 0.54) > 0.005
union all
select 'row_count', count(*)::text from {{ ref('mart_ai_group_exposure') }} having count(*) <> 23
union all
select 'indeed_categories_mapped', sum(indeed_n_categories)::text from {{ ref('mart_ai_group_exposure') }} having sum(indeed_n_categories) <> 47
union all
select 'endpoint_' || e.soc_group_code || '_' || coalesce(m.month_start::text, 'missing'), e.postings_latest::text || ' vs ' || m.active_postings_sa::text
from endpoints as e
left join monthly as m on m.group_code = e.soc_group_code and m.month_start = e.latest_month
where e.postings_latest is null or m.active_postings_sa is null or abs(e.postings_latest - m.active_postings_sa) > 1e-6
union all
select 'endpoint_' || e.soc_group_code || '_' || coalesce(m.month_start::text, 'missing'), e.postings_jun2022::text || ' vs ' || m.active_postings_sa::text
from endpoints as e
left join monthly as m on m.group_code = e.soc_group_code and m.month_start = e.long_start
where e.postings_jun2022 is null or m.active_postings_sa is null or abs(e.postings_jun2022 - m.active_postings_sa) > 1e-6
union all
select 'endpoint_' || e.soc_group_code || '_' || coalesce(m.month_start::text, 'missing'), e.postings_aug2025::text || ' vs ' || m.active_postings_sa::text
from endpoints as e
left join monthly as m on m.group_code = e.soc_group_code and m.month_start = e.one_year_start
where e.postings_aug2025 is null or m.active_postings_sa is null or abs(e.postings_aug2025 - m.active_postings_sa) > 1e-6
