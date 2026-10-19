-- staging.stg_onet__in_demand_pct (nb 36; card onet_in_demand.md §7): 1,302 rows, unique (onet_soc_code, product),
-- whole percents 0 to 100, one O*NET row order per code, and the same Lightcast window on every row (2025).
-- Returns one row per failed check.
with d as (
    select * from {{ source('staging', 'stg_onet__in_demand_pct') }}
),

checks as (
    select 'rows = 1,302' as check_name, 1302 as expected, count(*)::int as got from d
    union all
    select '(onet_soc_code, product) unique', 0, (count(*) - count(distinct (onet_soc_code, product)))::int from d
    union all
    select 'pct_of_job_ads between 0 and 100', 0, count(*) filter (where pct_of_job_ads is null or pct_of_job_ads not between 0 and 100)::int from d
    union all
    select 'csv_order unique per code', 0, (count(*) - count(distinct (onet_soc_code, csv_order)))::int from d
    union all
    select 'soc_code = first 7 characters of the O*NET code', 0, count(*) filter (where soc_code <> left(onet_soc_code, 7))::int from d
    union all
    select 'one window: 2025-01-01 to 2025-12-31', 0,
           count(*) filter (where window_start <> date '2025-01-01' or window_end <> date '2025-12-31')::int from d
    union all
    -- O*NET's lists come sorted high to low, so csv_order never puts a higher share after a lower one
    select 'O*NET order is by share, high to low', 0, count(*)::int
    from d as a join d as b on b.onet_soc_code = a.onet_soc_code and b.csv_order = a.csv_order + 1
    where b.pct_of_job_ads > a.pct_of_job_ads
)

select * from checks where got is distinct from expected
