-- Tie-outs for mart.job_escape_route (docs/mart-plan.md §5, nb 46 §3, D22 as amended). Tolerance on r: 0.0001
-- (nb 46 printed four decimals); counts exact.
--   * Accountants and Auditors 13-2011 -> Financial Examiners 13-2061: r = 0.9125, its rank-1 route.
--   * 30 origins in the view (every High-band degree-reachable job with a profile and a NYC wage), 29 of them
--     with a route at r >= 0.75 under the -10% pay floor.
--   * Close routes: nb 46 counted 17 origins "at the 95th percentile (0.82)" using the unrounded percentile
--     (0.8215 over all 790-job pairs, printed as 0.82). The rule as written in D22 is 0.82, and at exactly 0.82
--     the view lists 20 origins with a close route (three best routes sit between 0.820 and 0.8215). Both facts
--     are pinned here: 17 at the notebook's cutoff 0.8215, 20 at the page cutoff 0.82. See
--     a working script (not published) for the diagnosis; the rule was not tuned.
with v as (
    select * from {{ ref('mart_job_escape_route') }}
),

best as (
    select origin_soc_code, max(r) as best_r
    from v
    where route_rank >= 1
    group by origin_soc_code
)

select 'accountants_to_financial_examiners_r' as problem, r::text as detail
from v
where origin_soc_code = '13-2011' and destination_soc_code = '13-2061' and (abs(r - 0.9125) > 0.0001 or route_rank <> 1)
union all
select 'accountants_to_financial_examiners_missing', 'no row'
where not exists (select 1 from v where origin_soc_code = '13-2011' and destination_soc_code = '13-2061')
union all
select 'origins', count(distinct origin_soc_code)::text from v having count(distinct origin_soc_code) <> 30
union all
select 'origins_with_route_at_0_75', count(*)::text from best having count(*) <> 29
union all
select 'origins_close_at_notebook_cutoff_0_8215', count(*)::text from best where best_r >= 0.8215 having count(*) <> 17
union all
select 'origins_close_at_page_cutoff_0_82', count(*)::text from best where best_r >= 0.82 having count(*) <> 20
union all
select 'origins_close_by_closeness_column', count(distinct origin_soc_code)::text from v where closeness = 'close' having count(distinct origin_soc_code) <> 20
