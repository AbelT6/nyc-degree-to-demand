-- Plan §5 / nb 42 §1 tie-outs for mart.major_awards_trend: NYC first-major awards 2019 -> 2024, associate's -33%
-- (CUNY -40%: 18,880 -> 11,402), bachelor's -5% (CUNY -14%, other colleges +3%); 2024 total 73,225 = the IPEDS
-- fact total at levels 3 and 5. Tolerances: counts exact; changes ±0.005 (half a percent, the notebook printed whole percents).
with t as (
    select
        award_level,
        college_group,
        sum(awards) filter (where year = 2019) as a2019,
        sum(awards) filter (where year = 2024) as a2024
    from {{ ref('mart_major_awards_trend') }}
    group by grouping sets ((award_level, college_group), (award_level), ())
),

checks as (
    select 'associate''s 2019 -> 2024, all NYC' as check_name, -0.33::numeric as expected, a2024::numeric / a2019 - 1 as got, 0.005::numeric as tolerance from t where award_level = 3 and college_group is null
    union all
    select 'associate''s 2019 -> 2024, CUNY', -0.40, a2024::numeric / a2019 - 1, 0.005 from t where award_level = 3 and college_group = 'CUNY'
    union all
    select 'associate''s CUNY 2019 awards', 18880, a2019, 0 from t where award_level = 3 and college_group = 'CUNY'
    union all
    select 'associate''s CUNY 2024 awards', 11402, a2024, 0 from t where award_level = 3 and college_group = 'CUNY'
    union all
    select 'bachelor''s 2019 -> 2024, all NYC', -0.05, a2024::numeric / a2019 - 1, 0.005 from t where award_level = 5 and college_group is null
    union all
    select 'bachelor''s 2019 -> 2024, CUNY', -0.14, a2024::numeric / a2019 - 1, 0.005 from t where award_level = 5 and college_group = 'CUNY'
    union all
    select 'bachelor''s 2019 -> 2024, other NYC colleges', 0.03, a2024::numeric / a2019 - 1, 0.005 from t where award_level = 5 and college_group = 'Other NYC colleges'
    union all
    select '2024 first-major awards, levels 3 and 5 (IPEDS total)', 73225, a2024, 0 from t where award_level is null and college_group is null
)

select *
from checks
where got is null or abs(got - expected) > tolerance
