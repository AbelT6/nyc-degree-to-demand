-- fct_degree_awards tie-outs (plan §4 item 9): awards conserved from staging (1,493,986); NYC 2024 first-major
-- associate's 18,490 / bachelor's 54,735; CUNY 11,402 / 23,437 (card ipeds_completions.md §4-5); every 2015-2019 row
-- bridged and no 2020+ row bridged; men + women = total; every CIP 2010 code IPEDS reports is recorded in
-- cip_code_source; the fact and staging hold the same number of awards every year.
with fact as (
    select * from {{ ref('fct_degree_awards') }}
),

staging as (
    select * from {{ source('staging', 'stg_ipeds__completions') }}
)

select 'total_awards' as problem, sum(awards_total)::text as detail from fact having sum(awards_total) <> 1493986

union all
select 'nyc_2024_first_major_associate', sum(awards_total)::text from fact
where year = 2024 and major_number = 1 and award_level = 3 having sum(awards_total) <> 18490

union all
select 'nyc_2024_first_major_bachelor', sum(awards_total)::text from fact
where year = 2024 and major_number = 1 and award_level = 5 having sum(awards_total) <> 54735

union all
select 'cuny_2024_first_major_associate', sum(f.awards_total)::text
from fact as f join {{ ref('dim_college') }} as c on c.unitid = f.unitid
where c.is_cuny and f.year = 2024 and f.major_number = 1 and f.award_level = 3 having sum(f.awards_total) <> 11402

union all
select 'cuny_2024_first_major_bachelor', sum(f.awards_total)::text
from fact as f join {{ ref('dim_college') }} as c on c.unitid = f.unitid
where c.is_cuny and f.year = 2024 and f.major_number = 1 and f.award_level = 5 having sum(f.awards_total) <> 23437

union all
select 'bridged_flag_vs_year', year::text || ':' || cip_bridged::text from fact
where cip_bridged <> (year <= 2019) group by year, cip_bridged

union all
select 'edition_vs_bridged', cip_edition_source || ':' || cip_bridged::text from fact
where cip_bridged <> (cip_edition_source = '2010') group by cip_edition_source, cip_bridged

union all
select 'men_plus_women', count(*)::text from fact where awards_men + awards_women <> awards_total having count(*) > 0

union all
select 'cip2010_code_not_recorded', s.cip_code
from (select distinct cip_code from staging where cip_edition = '2010') as s
where not exists (
    select 1 from fact as f, unnest(string_to_array(f.cip_code_source, ', ')) as u (code)
    where f.cip_bridged and u.code = s.cip_code
)

union all
select 'awards_per_year', y.year::text || ':' || coalesce(y.fact_awards, 0)::text || '<>' || coalesce(y.stg_awards, 0)::text
from (
    select coalesce(f.year, s.year) as year, f.awards as fact_awards, s.awards as stg_awards
    from (select year, sum(awards_total) as awards from fact group by year) as f
    full outer join (select year, sum(awards_total) as awards from staging group by year) as s on s.year = f.year
) as y
where y.fact_awards is distinct from y.stg_awards
