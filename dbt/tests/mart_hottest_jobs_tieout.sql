-- Plan §5 tie-outs for mart.hottest_jobs (nb 40 §3-§4; explore-plan §3b as decided):
--   List 1 top 6 by openings: General and Operations Managers 9,781, Registered Nurses 7,410, Accountants and Auditors
--   6,648, Market Research Analysts 6,037, Management Analysts 4,444, Software Developers 4,308 (the D1-imputed row) -> ±1,
--   and 20 of the 25 rated Favorable or Very Favorable; every List 1 row is a non-All-Other leaf;
--   List 2 (absolute NYC change 2019 -> 2025, floor 1,000): Software Developers +28 k / +68% (±100 jobs, ±0.005),
--   Marketing Managers +19 k (±100); Data Scientists carry split_2019 and a reclassification note; every List 2 row
--   has >= 1,000 estimated jobs in both years; the three ranked lists hold 25 rows; the All Other list holds only
--   All Other codes.
with v as (
    select * from {{ ref('mart_hottest_jobs') }}
),

l1 as (select * from v where list_key = 'most_openings'),
l2 as (select * from v where list_key = 'fastest_growing'),

checks as (
    select 'L1 #1 General and Operations Managers 11-1021' as check_name, 9781::numeric as expected, ranked_value as got, 1::numeric as tolerance from l1 where rank = 1 and soc_code = '11-1021'
    union all
    select 'L1 #2 Registered Nurses 29-1141', 7410, ranked_value, 1 from l1 where rank = 2 and soc_code = '29-1141'
    union all
    select 'L1 #3 Accountants and Auditors 13-2011', 6648, ranked_value, 1 from l1 where rank = 3 and soc_code = '13-2011'
    union all
    select 'L1 #4 Market Research Analysts 13-1161', 6037, ranked_value, 1 from l1 where rank = 4 and soc_code = '13-1161'
    union all
    select 'L1 #5 Management Analysts 13-1111', 4444, ranked_value, 1 from l1 where rank = 5 and soc_code = '13-1111'
    union all
    select 'L1 #6 Software Developers 15-1252 (imputed)', 4308, ranked_value, 1 from l1 where rank = 6 and soc_code = '15-1252' and is_imputed
    union all
    select 'L1 rows with the expected top-6 codes in place', 6, count(*), 0 from l1
    where (rank, soc_code) in ((1, '11-1021'), (2, '29-1141'), (3, '13-2011'), (4, '13-1161'), (5, '13-1111'), (6, '15-1252'))
    union all
    select 'L1 size', 25, count(*), 0 from l1
    union all
    select 'L1 rated Favorable or Very Favorable', 20, count(*) filter (where employment_prospects in ('Favorable', 'Very Favorable')), 0 from l1
    union all
    select 'L1 All Other rows (must be 0)', 0, count(*) filter (where is_all_other), 0 from l1
    union all
    select 'L2 size', 25, count(*), 0 from l2
    union all
    select 'L2 pct list size', 25, count(*), 0 from v where list_key = 'fastest_growing_pct'
    union all
    select 'L2 Software Developers 15-1252 jobs added 2019 -> 2025', 28415, nyc_change_2019_2025, 100 from l2 where soc_code = '15-1252'
    union all
    select 'L2 Software Developers 15-1252 percent change', 0.68, nyc_pct_change_2019_2025, 0.005 from l2 where soc_code = '15-1252'
    union all
    select 'L2 Marketing Managers 11-2021 jobs added 2019 -> 2025', 19257, nyc_change_2019_2025, 100 from l2 where soc_code = '11-2021'
    union all
    select 'L2 Data Scientists 15-2051 flagged split_2019 with a note', 1, count(*) filter (where split_2019 and growth_note is not null), 0 from l2 where soc_code = '15-2051'
    union all
    select 'L2 rows under the 1,000 floor (must be 0)', 0, count(*) filter (where not (nyc_employment_2019 >= 1000 and nyc_employment_2025 >= 1000)), 0 from l2
    union all
    select 'L2 All Other rows (must be 0)', 0, count(*) filter (where is_all_other), 0 from l2
    union all
    select 'L2 ranked by absolute change (rank order = value order)', 0, count(*), 0
    from (select rank, ranked_value, lag(ranked_value) over (order by rank) as prev from l2) x where prev < ranked_value
    union all
    select 'Other list non-All-Other rows (must be 0)', 0, count(*) filter (where not is_all_other), 0 from v where list_key = 'other_jobs_most_openings'
)

select *
from checks
where got is null or abs(got - expected) > tolerance
