-- Indeed shape (plan §4 item 17): row count = the three staging tables together (4,872 + 4,872 + 228,984 = 238,728);
-- category is 'all' exactly for the aggregate (national + area) rows; index_nsa is present on every national
-- aggregate row and null on every other row; every series reads 100 on the base day 2020-02-01.
with f as (
    select * from {{ ref('fct_postings_indeed_index') }}
),

src_count as (
    select
        (select count(*) from {{ source('staging', 'stg_indeed__postings_national') }})
      + (select count(*) from {{ source('staging', 'stg_indeed__postings_area') }})
      + (select count(*) from {{ source('staging', 'stg_indeed__postings_category') }}) as n
)

select 'row_count' as problem, (select count(*) from f)::text || ' vs staging ' || n::text as detail
from src_count
where (select count(*) from f) <> n
union all
select 'aggregate_rows', count(*)::text
from f
where category = 'all'
having count(*) <> (select count(*) from {{ source('staging', 'stg_indeed__postings_national') }})
                 + (select count(*) from {{ source('staging', 'stg_indeed__postings_area') }})
union all
select 'category_flag_mismatch', count(*)::text
from f
where is_category_series <> (category <> 'all')
having count(*) > 0
union all
select 'nsa_outside_national', count(*)::text
from f
where index_nsa is not null and not (area_key = 'us' and category = 'all')
having count(*) > 0
union all
select 'nsa_missing_national', count(*)::text
from f
where index_nsa is null and area_key = 'us' and category = 'all'
having count(*) > 0
union all
select 'base_day_not_100', count(*)::text
from f
where date = date '2020-02-01' and (abs(index_sa - 100) > 1e-6 or abs(coalesce(index_nsa, 100) - 100) > 1e-6)
having count(*) > 0
