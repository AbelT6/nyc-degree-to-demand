-- D8 input 1 tie-outs (plan docs/step4-facts-plan.md §6.2, §4 item 3; brief group E item 1):
-- (a) the yearly sum over pattern sectors equals NYC "Total, All Ownerships" in fct_industry_employment_annual
--     within 5 (BLS government totals tie to NYS DOL within 2, private sectors to the private total within 3);
--     2020 is allowed 100 (BLS local government is +68 vs NYS DOL that year);
-- (b) every year has exactly the 20 pattern sectors;
-- (c) no component is negative, and employment is the five components added;
-- (d) government lands only on 61, 62, 48-49 and 99 (NYS DOL-filled cells only on 61, 62, 99); private only off 99.
with f as (
    select * from {{ ref('audit_nyc_employment_by_pattern_sector') }}
),

qcew as (
    select year, employment as total
    from {{ ref('fct_industry_employment_annual') }}
    where area_key = 'nyc' and ownership = 'Total, All Ownerships' and industry_key = '00'
),

per_year as (
    select year, sum(employment) as employment, count(*) as n_sectors, count(distinct pattern_sector) as n_distinct
    from f
    group by year
)

select 'total_gap' as problem, p.year::text || ' pattern ' || round(p.employment, 2)::text || ' qcew ' || q.total::text as detail
from per_year as p
join qcew as q on q.year = p.year
where abs(p.employment - q.total) > case when p.year = 2020 then 100 else 5 end

union all
select 'year_missing_in_qcew', p.year::text
from per_year as p
where not exists (select 1 from qcew as q where q.year = p.year)

union all
select 'sector_count', year::text || ' ' || n_sectors::text || ' rows, ' || n_distinct::text || ' distinct'
from per_year
where n_sectors <> 20 or n_distinct <> 20

union all
select 'negative_component', year::text || ' ' || pattern_sector
from f
where private_employment < 0 or private_unclassified_allocated < 0
   or government_disclosed < 0 or government_from_nysdol < 0
   or government_undisclosed_allocated < 0 or employment < 0

union all
select 'components_do_not_add', year::text || ' ' || pattern_sector
from f
where abs(employment - (private_employment + private_unclassified_allocated
                        + government_disclosed + government_from_nysdol + government_undisclosed_allocated)) > 1e-6

union all
select 'government_misfiled', year::text || ' ' || pattern_sector
from f
where (government_disclosed <> 0 and pattern_sector not in ('61', '62', '48-49', '99'))
   or (government_from_nysdol <> 0 and pattern_sector not in ('61', '62', '99'))
   or (government_undisclosed_allocated <> 0 and pattern_sector <> '99')
   or ((private_employment <> 0 or private_unclassified_allocated <> 0) and pattern_sector = '99')
