-- Employment tie-out per year (plan docs/step4-facts-plan.md §4 item 2):
-- (a) the sum of the fact's lowest-level rows (occ_level = 'detailed', i.e. dim_job levels below major) equals the
--     sum of the staging detailed rows within 1 (the bridge weights for each source code sum to 1);
-- (b) the total row 00-0000 is unchanged from staging;
-- (c) detailed / total >= 0.989 every year (OEWS withholds a few cells, never more than 1.1% of the total);
-- (d) no target mixes source levels (a split or combined row is always built from detailed sources).
with f as (
    select f.*, d.soc_level
    from {{ ref('fct_job_employment_wage_annual') }} as f
    join {{ ref('dim_job') }} as d on d.soc_code = f.soc_code
),

s as (
    select * from {{ source('staging', 'stg_bls__oews_metro_occupations') }}
),

fact_year as (
    select
        year,
        sum(employment) filter (where occ_level = 'detailed')   as detailed,
        max(employment) filter (where soc_code = '00-0000')     as total
    from f
    group by year
),

stg_year as (
    select
        year,
        sum(employment::numeric) filter (where occ_level = 'detailed') as detailed,
        max(employment::numeric) filter (where occ_level = 'total')    as total
    from s
    group by year
)

select 'detailed_sum' as problem, fy.year::text || ' fact ' || fy.detailed::text || ' staging ' || sy.detailed::text as detail
from fact_year as fy
join stg_year as sy on sy.year = fy.year
where abs(fy.detailed - sy.detailed) > 1

union all
select 'total_row', fy.year::text || ' fact ' || fy.total::text || ' staging ' || sy.total::text
from fact_year as fy
join stg_year as sy on sy.year = fy.year
where fy.total <> sy.total

union all
select 'detailed_share', year::text || ' ' || round(detailed / total, 5)::text
from fact_year
where detailed / total < 0.989

union all
select 'level_mismatch', year::text || ' ' || soc_code || ' ' || occ_level || ' vs ' || soc_level
from f
where (occ_level = 'total' and soc_level <> 'total')
   or (occ_level = 'major' and soc_level <> 'major')
   or (occ_level = 'detailed' and soc_level in ('total', 'major'))
