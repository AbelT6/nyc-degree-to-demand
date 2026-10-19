-- D8 input 2 checks (plan docs/step4-facts-plan.md §2a, §3a, §5 risk 2; brief group E item 2):
-- (a) share_of_sector sums to 1 per sector-year (within 1e-9);
-- (b) every year has exactly the 20 pattern sectors (19 NAICS sectors + 99 government);
-- (c) pattern_coverage is between 0.80 and 1.02 for every sector-year, except agriculture (11) and mining (21),
--     which have under 600 NYC private jobs between them and publish as little as 0.69 of the sector (measured
--     range 0.69-0.84); those two must stay between 0.65 and 1.02;
-- (d) the grain year x pattern_sector x soc_code is unique;
-- (e) a sector-year's coverage and suppressed count are one value (not row-dependent).
with f as (
    select * from {{ ref('audit_industry_job_pattern_annual') }}
),

sector_year as (
    select
        year,
        pattern_sector,
        sum(share_of_sector) as share_sum,
        min(pattern_coverage) as cov_min,
        max(pattern_coverage) as cov_max,
        min(n_suppressed) as sup_min,
        max(n_suppressed) as sup_max
    from f
    group by year, pattern_sector
)

select 'shares_not_one' as problem, year::text || ' ' || pattern_sector || ' ' || share_sum::text as detail
from sector_year
where abs(share_sum - 1) > 1e-9

union all
select 'sector_count', year::text || ' ' || count(*)::text
from sector_year
group by year
having count(*) <> 20

union all
select 'coverage_out_of_range', year::text || ' ' || pattern_sector || ' ' || round(cov_min, 4)::text
from sector_year
where cov_max > 1.02
   or (pattern_sector not in ('11', '21') and cov_min < 0.80)
   or (pattern_sector in ('11', '21') and cov_min < 0.65)

union all
select 'duplicate_grain', year::text || ' ' || pattern_sector || ' ' || soc_code
from f
group by year, pattern_sector, soc_code
having count(*) > 1

union all
select 'sector_year_value_varies', year::text || ' ' || pattern_sector
from sector_year
where cov_min <> cov_max or sup_min <> sup_max
