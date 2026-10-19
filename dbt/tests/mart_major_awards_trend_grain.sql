-- Grain of mart.major_awards_trend: one row per year x cip_code x award_level x unitid, years 2015-2024, and the
-- view's total equals the fact's first-major total at levels 3 and 5 (no row dropped by the college join).
with dup as (
    select 'duplicate key' as check_name, year || ' ' || cip_code || ' ' || award_level || ' ' || unitid as detail
    from {{ ref('mart_major_awards_trend') }}
    group by year, cip_code, award_level, unitid
    having count(*) > 1
),

years as (
    select 'year outside 2015-2024' as check_name, year::text as detail
    from {{ ref('mart_major_awards_trend') }}
    where year < 2015 or year > 2024
    group by year
),

totals as (
    select 'awards total differs from fct_degree_awards' as check_name,
           (select sum(awards) from {{ ref('mart_major_awards_trend') }})::text || ' vs '
           || (select sum(awards_total) from {{ ref('fct_degree_awards') }} where major_number = 1 and award_level in (3, 5))::text as detail
    where (select sum(awards) from {{ ref('mart_major_awards_trend') }})
       <> (select sum(awards_total) from {{ ref('fct_degree_awards') }} where major_number = 1 and award_level in (3, 5))
)

select * from dup
union all select * from years
union all select * from totals
