-- Plan §5 / nb 43 §4 tie-outs for mart.job_entry_signal (D5): 85 of the 221 degree-reachable detailed jobs have the ACS
-- young-worker signal suppressed (under 30 responses) or not available; every detailed degree-reachable job has a
-- readable BLS experience row; a readable row carries a value and a band, a non-readable row carries neither; the
-- ACS band follows the fact (high = share >= 0.30 is set in core, so only consistency is checked here: band and
-- value present together); the D5 direction holds (median O*NET newcomer share falls from the BLS 'none' band to
-- 'under 5 years' to '5 years plus').
with v as (
    select * from {{ ref('mart_job_entry_signal') }}
),

detailed as (
    select v.*
    from v
    join {{ ref('dim_job') }} as j on j.soc_code = v.soc_code
    where j.soc_level = 'detailed'
),

direction as (
    select
        b.band as bls_band,
        percentile_cont(0.5) within group (order by o.value) as median_newcomer
    from detailed as o
    join detailed as b on b.soc_code = o.soc_code and b.measure = 'bls_experience'
    where o.measure = 'onet_newcomer' and o.signal_status = 'readable'
    group by b.band
),

checks as (
    select 'degree-reachable detailed jobs with the ACS signal suppressed or not available' as check_name, 85::numeric as expected,
        count(*) filter (where measure = 'acs_young_share' and signal_status <> 'readable')::numeric as got, 0::numeric as tolerance
    from detailed
    union all
    select 'degree-reachable detailed jobs', 221, count(distinct soc_code), 0 from detailed
    union all
    select 'detailed jobs with a readable BLS experience row', 221, count(*) filter (where measure = 'bls_experience' and signal_status = 'readable'), 0 from detailed
    union all
    select 'readable rows missing value or band (must be 0)', 0, count(*) filter (where signal_status = 'readable' and (value is null or band is null)), 0 from v
    union all
    select 'non-readable rows carrying a value or band (must be 0)', 0, count(*) filter (where signal_status <> 'readable' and (value is not null or band is not null)), 0 from v
    union all
    select 'D5 direction: median newcomer share, BLS none > under 5 years', 1,
        case when (select median_newcomer from direction where bls_band = 'none') > (select median_newcomer from direction where bls_band = 'under_5_years') then 1 else 0 end, 0
    union all
    select 'D5 direction: median newcomer share, under 5 years >= 5 years plus', 1,
        case when (select median_newcomer from direction where bls_band = 'under_5_years') >= (select median_newcomer from direction where bls_band = '5_years_plus') then 1 else 0 end, 0
)

select *
from checks
where got is null or abs(got - expected) > tolerance
