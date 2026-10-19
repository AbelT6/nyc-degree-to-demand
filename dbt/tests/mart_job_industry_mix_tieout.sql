-- Tie-outs for mart.job_industry_mix (explore-plan §3g; nb 40 §5d and §7c; D3, D8):
--   rows = bridge_industry_job rows with a readable share_of_job on a job-page level (no fan-out through dim_industry,
--   the hiring view or the pattern audit); Registered Nurses recomputed from this view: share-weighted 2024 separation
--   rate over sectors with a QWI rate, renormalized = 0.5239 (±0.0001) at coverage 0.959 (±0.0005), 10 sectors, 78%
--   of the job in Health Care 62 (±0.005); the job's sector contributions sum to its NYC estimate for 2025 (±1) for
--   Registered Nurses and for every job the estimate publishes; share_of_job sums to at most 1.0005 per job;
--   GOV-OEWS and 92 never carry a QWI rate.
with v as (
    select * from {{ ref('mart_job_industry_mix') }}
),

rn as (
    select
        sum(share_of_job * separation_rate_2024) / sum(share_of_job) filter (where has_qwi_rate) as sep_rate,
        sum(share_of_job) filter (where has_qwi_rate)                                           as coverage,
        count(*)                                                                                 as n_sectors,
        max(share_of_job) filter (where industry_key = '62')                                     as share_62,
        sum(nyc_jobs_in_sector_2025_est)                                                         as nyc_jobs_2025
    from v
    where soc_code = '29-1141'
),

est as (
    select soc_code, employment_est
    from {{ ref('fct_job_employment_nyc_est') }}
    where year = 2025
),

sums as (
    select v.soc_code, sum(v.nyc_jobs_in_sector_2025_est) as nyc_jobs_2025, max(e.employment_est) as employment_est
    from v
    join est as e on e.soc_code = v.soc_code
    group by v.soc_code
),

checks as (
    select 'rows = readable bridge rows on job-page levels' as check_name,
        (select count(*) from {{ ref('bridge_industry_job') }} as b join {{ ref('dim_job') }} as j on j.soc_code = b.soc_code
         where b.share_of_job is not null and j.soc_level in ('detailed', 'broad', 'bls_aggregate'))::numeric as expected,
        (select count(*) from v)::numeric as got, 0::numeric as tolerance
    union all
    select 'Registered Nurses share-weighted separation rate 2024', 0.5239, sep_rate, 0.0001 from rn
    union all
    select 'Registered Nurses churn coverage', 0.959, coverage, 0.0005 from rn
    union all
    select 'Registered Nurses sectors with a readable share', 10, n_sectors, 0 from rn
    union all
    select 'Registered Nurses share in Health Care 62', 0.78, share_62, 0.005 from rn
    union all
    select 'Registered Nurses sector contributions = NYC estimate 2025', (select employment_est from est where soc_code = '29-1141'), nyc_jobs_2025, 1 from rn
    union all
    select 'jobs whose sector contributions miss their NYC 2025 estimate by more than 1', 0, count(*), 0 from sums where abs(nyc_jobs_2025 - employment_est) > 1
    union all
    select 'jobs whose share_of_job sums above 1.0005', 0, count(*), 0 from (select soc_code from v group by 1 having sum(share_of_job) > 1.0005) x
    union all
    select 'GOV-OEWS or 92 rows carrying a QWI rate', 0, count(*), 0 from v where industry_key in ('GOV-OEWS', '92') and has_qwi_rate
)

select *
from checks
where got is null or abs(got - expected) > tolerance
