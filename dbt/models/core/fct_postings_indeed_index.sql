-- core.fct_postings_indeed_index: Indeed Hiring Lab job postings index (Feb 1, 2020 = 100), daily, three series
-- families in one long table: U.S. aggregate (total and new postings, SA and NSA), New York State and the NY metro
-- aggregate (SA only), and 47 U.S. job categories (total and new, SA only). The national check beside Revelio (D10).
-- Grain: date x area_key x category x measure (238,728 rows = the three staging tables, nothing dropped).
-- Plan: docs/step4-facts-plan.md §3f, §4 item 17, §6.3 (no Indeed category -> SOC map in v1).
--
-- how a source code reaches the dimensions
--   national file   -> area_key 'us', category 'all'
--   area file       area_code NY -> 'ny_state', 35620 -> 'ny_metro' via dim_area.indeed_area_code; category 'all';
--                   the file carries one series per area, which is Indeed's total postings series (measure 'total')
--   category file   -> area_key 'us', category = Indeed's 47 category names (not SOC; §6.3 defers the map)
--
-- category is the literal 'all' (not null) for the aggregate series so the grain is a plain unique key;
-- is_category_series = (category <> 'all'). index_nsa exists only in the national file and is null elsewhere.
-- Values are an index, not counts; every series reads 100.0 on 2020-02-01.

with national as (
    select
        date,
        'us' as area_key,
        'all' as category,
        measure,
        index_sa::numeric as index_sa,
        index_nsa::numeric as index_nsa,
        source_file
    from {{ source('staging', 'stg_indeed__postings_national') }}
),

area as (
    select
        s.date,
        d.area_key,
        'all' as category,
        'total' as measure,
        s.index_sa::numeric as index_sa,
        null::numeric as index_nsa,
        s.source_file
    from {{ source('staging', 'stg_indeed__postings_area') }} as s
    join {{ ref('dim_area') }} as d on d.indeed_area_code = s.area_code
),

category as (
    select
        date,
        'us' as area_key,
        category,
        measure,
        index_sa::numeric as index_sa,
        null::numeric as index_nsa,
        source_file
    from {{ source('staging', 'stg_indeed__postings_category') }}
),

unioned as (
    select * from national
    union all
    select * from area
    union all
    select * from category
)

select
    date,
    area_key,
    category,
    measure,
    index_sa,
    index_nsa,
    category <> 'all' as is_category_series,
    'indeed_hiring_lab' as source_key,
    source_file
from unioned
