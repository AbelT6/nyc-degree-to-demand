-- Plan §5 tie-outs for mart.major_supply_demand (nb 42 §1-§4 under D20; nb 46 §1-§2). Tolerances: award counts
-- exact; graduates per opening ±0.005 (two decimals printed); exposure ±0.0005 (three decimals) except Computer
-- Science 0.3203 ±0.00005 (four printed); shares ±0.005 where the notebook printed whole percents; major counts exact.
-- D57: links through rated BLS group codes add 28 linked majors x level (1,860 -> 1,888; awards 43,488 -> 43,654 and
-- 17,670 -> 17,504, the 31 + 135 of the four majors that left transfer); 135 linked awards (Clinical Laboratory Science,
-- Education, General, Elementary Special Education) lead only to jobs Anthropic does not score; growing . many 421 -> 419 -> 420 (D58 part share).
with m as (
    select * from {{ ref('mart_major_supply_demand') }}
),

by_status as (
    select
        sum(awards_2024_nyc) filter (where link_status = 'linked')                                   as linked,
        sum(awards_2024_nyc) filter (where link_status = 'dispersed')                                as dispersed,
        sum(awards_2024_nyc) filter (where link_status in ('transfer_pathway', 'not_in_crosswalk'))  as other,
        sum(awards_2024_nyc)                                                                         as total
    from m
),

ipeds as (
    select sum(awards_total) as total
    from {{ ref('fct_degree_awards') }}
    where year = 2024 and major_number = 1 and award_level in (3, 5)
),

crowded as (
    select count(*) as majors, sum(awards_2024_nyc) as awards, count(distinct top_job_soc_code) as top_jobs
    from m where box = 'crowded'
),

growing_many as (
    select count(*) as majors, sum(awards_2024_nyc) as awards
    from m where box = 'growing_many' and award_level = 5
),

exposure as (
    select
        award_level,
        -- D57: averages over scored majors only (3 linked bachelor's majors lead only to jobs Anthropic doesn't score)
        sum(awards_2024_nyc * ai_exposure) / sum(awards_2024_nyc) filter (where ai_exposure is not null)    as exp_nyc,
        sum(awards_2024_cuny * ai_exposure) / sum(awards_2024_cuny) filter (where ai_exposure is not null)  as exp_cuny,
        sum(awards_2024_nyc) filter (where ai_band = 'High')
            / (sum(awards_2024_nyc) filter (where ai_exposure is not null))::numeric                        as high_awards_share,
        sum(awards_2024_nyc) filter (where ai_exposure is null)                              as awards_without_exposure
    from m
    where link_status = 'linked'
    group by award_level
),

dispersed as (
    select sum(awards_2024_nyc * ai_exposure) / sum(awards_2024_nyc) as exp_acs,
           count(*) filter (where ai_exposure is null and awards_2024_nyc > 0) as majors_without_exposure
    from m
    where link_status = 'dispersed'
),

checks as (
    select 'rows = mart.dim_major' as check_name, (select count(*) from {{ ref('mart_dim_major') }})::numeric as expected, count(*)::numeric as got, 0::numeric as tolerance from m
    union all
    select 'linked + dispersed majors x level', 1888, count(*), 0 from m where link_status in ('linked', 'dispersed')
    union all
    select '2024 awards, linked majors', 43654, linked, 0 from by_status
    union all
    select '2024 awards, dispersed majors (D20)', 12067, dispersed, 0 from by_status
    union all
    select '2024 awards, transfer pathway / not in crosswalk', 17504, other, 0 from by_status
    union all
    select '2024 awards total on the view', 73225, total, 0 from by_status
    union all
    select '2024 awards total = IPEDS fact (levels 3 and 5, first majors)', (select total from ipeds), total, 0 from by_status
    union all
    select 'crowded box majors (shrinking · many)', 8, majors, 0 from crowded
    union all
    select 'crowded box awards', 159, awards, 0 from crowded
    union all
    select 'crowded box top job is one job (Mechanical Drafters)', 1, top_jobs, 0 from crowded
    union all
    select 'every crowded major''s top job is Mechanical Drafters 17-3013', 1, (min(top_job_soc_code) = '17-3013' and max(top_job_soc_code) = '17-3013')::int, 0 from m where box = 'crowded'
    union all
    select 'growing · many bachelor''s majors', 420, majors, 0 from growing_many
    union all
    select 'growing · many bachelor''s awards', 14136, awards, 0 from growing_many
    union all
    select 'Nursing 51.3801 bachelor''s graduates per opening', 0.52, graduates_per_opening, 0.005 from m where major_award_key = '51.3801|5'
    union all
    select 'Computer Science 11.0701 bachelor''s graduates per opening', 0.53, graduates_per_opening, 0.005 from m where major_award_key = '11.0701|5'
    union all
    select 'Accounting 52.0301 bachelor''s graduates per opening', 0.19, graduates_per_opening, 0.005 from m where major_award_key = '52.0301|5'
    union all
    select 'Computer Science 11.0701 bachelor''s exposure', 0.3203, ai_exposure, 0.00005 from m where major_award_key = '11.0701|5'
    union all
    select 'Computer Science 11.0701 bachelor''s exposure coverage', 1.000, ai_exposure_coverage, 0.0005 from m where major_award_key = '11.0701|5'
    union all
    select 'Computer Science 11.0701 bachelor''s banded High', 1, (ai_band = 'High')::int, 0 from m where major_award_key = '11.0701|5'
    union all
    select 'awards-weighted exposure, linked bachelor''s, all NYC', 0.204, exp_nyc, 0.0005 from exposure where award_level = 5
    union all
    select 'awards-weighted exposure, linked bachelor''s, CUNY', 0.220, exp_cuny, 0.0005 from exposure where award_level = 5
    union all
    select 'awards-weighted exposure, linked associate''s, all NYC', 0.105, exp_nyc, 0.0005 from exposure where award_level = 3
    union all
    select 'awards-weighted exposure, linked associate''s, CUNY', 0.137, exp_cuny, 0.0005 from exposure where award_level = 3
    union all
    select 'share of linked bachelor''s awards in majors banded High', 0.18, high_awards_share, 0.005 from exposure where award_level = 5
    union all
    select 'linked awards without an exposure', 135, awards_without_exposure, 0 from exposure where award_level = 5
    union all
    select 'dispersed majors by ACS destinations, awards-weighted', 0.224, exp_acs, 0.0005 from dispersed
    union all
    select 'dispersed majors with awards but no ACS exposure', 0, majors_without_exposure, 0 from dispersed
    union all
    select 'Business Administration 52.0201 exposure by destinations', 0.26, ai_exposure, 0.005 from m where major_award_key = '52.0201|5'
    union all
    select 'Political Science 45.1001 exposure by destinations', 0.26, ai_exposure, 0.005 from m where major_award_key = '45.1001|5'
    union all
    select 'Psychology 42.0101 exposure by destinations', 0.21, ai_exposure, 0.005 from m where major_award_key = '42.0101|5'
    union all
    select 'Criminal Justice 43.0103 exposure by destinations', 0.17, ai_exposure, 0.005 from m where major_award_key = '43.0103|5'
    union all
    select 'Criminal Justice 43.0103 ACS coverage', 0.42, ai_exposure_coverage, 0.005 from m where major_award_key = '43.0103|5'
    union all
    select 'NYC all-jobs 2022-32 change (sensitivity cutoff)', 12.05, max(nyc_all_jobs_change_2022_2032_pct), 0.005 from m
)

select *
from checks
where got is null or abs(got - expected) > tolerance
