-- fct_cuny_program (plan §4 item 10): grain year x program_key unique; 53,838 rows (2,991 programs x 18 years,
-- 2008-2025, both measures present on every row); CUNY Programs graduates 2024 = 11,364 associate's / 24,085
-- bachelor's and 2025 = 11,676 / 22,591 (card cuny_programs.md §5); sums conserved from both staging tables; the
-- period labels match the year (AY_YYYY_<year>, Fall_<year>).
with fact as (
    select * from {{ ref('fct_cuny_program') }}
),

by_level as (
    select f.year, d.award_level, sum(f.graduates) as graduates
    from fact as f
    join {{ ref('dim_cuny_program') }} as d on d.program_key = f.program_key
    where f.year in (2024, 2025) and d.award_level in ('associate', 'bachelor')
    group by f.year, d.award_level
),

expected as (
    select * from (values
        (2024, 'associate', 11364), (2024, 'bachelor', 24085),
        (2025, 'associate', 11676), (2025, 'bachelor', 22591)
    ) as v (year, award_level, graduates)
)

select 'duplicate_key' as problem, year::text || '|' || program_key as detail from fact
group by year, program_key having count(*) > 1

union all
select 'row_count', count(*)::text from fact having count(*) <> 53838

union all
select 'year_span', min(year)::text || '-' || max(year)::text || ' (' || count(distinct year)::text || ')' from fact
having min(year) <> 2008 or max(year) <> 2025 or count(distinct year) <> 18

union all
select 'both_measures_null', year::text || '|' || program_key from fact where graduates is null and enrolled_fall is null

union all
select 'graduates_missing', year::text || '|' || program_key from fact where graduates is null

union all
select 'enrollment_missing', year::text || '|' || program_key from fact where enrolled_fall is null

union all
select 'graduates_' || e.year::text || '_' || e.award_level, coalesce(b.graduates, 0)::text || '<>' || e.graduates::text
from expected as e
left join by_level as b on b.year = e.year and b.award_level = e.award_level
where b.graduates is distinct from e.graduates

union all
select 'total_graduates', sum(graduates)::text from fact
having sum(graduates) <> (select sum(graduates) from {{ source('staging', 'stg_cuny__program_graduates') }})

union all
select 'total_enrolled', sum(enrolled_fall)::text from fact
having sum(enrolled_fall) <> (select sum(enrolled) from {{ source('staging', 'stg_cuny__program_enrollment') }})

union all
select 'period_graduates_vs_year', period_graduates || ':' || year::text from fact
where period_graduates is not null and period_graduates !~ ('^AY_\d{4}_' || year::text || '$') group by period_graduates, year

union all
select 'period_enrollment_vs_year', period_enrollment || ':' || year::text from fact
where period_enrollment is not null and period_enrollment <> 'Fall_' || year::text group by period_enrollment, year
