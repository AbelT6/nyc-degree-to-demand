-- Plan §5 and nb 41 tie-outs for mart.industry_profile:
--   Health Care and Social Assistance (62) private jobs 2019 -> 2025: +207 k (+26%)  -> ±500 jobs, ±0.005 on the percent;
--   degree-reachable jobs estimate (NY pattern x NYC private 2025): Professional and Technical (54) ~277 k / 64%,
--     Finance (52) ~251 k / 70%, Health Care (62) ~207 k / 21%, Information (51) ~136 k / 65%  -> ±5% on the
--     count (the brief's reporting threshold), ±0.01 on the share;
--   GDP share, 2024 (BEA's all-industry line as denominator): Finance 0.263, Health Care 0.064  -> ±0.0005 (D24 D).
--     Note: nb 41's first text read 27% / 6.5%. Those are 2024 figures divided by the sum of the sector lines, which
--     withheld borough cells leave about 1% short of the all-industry line (1,363.7 vs 1,377.8 $B): 26.6% / 6.5%.
--     They are not 2021 figures (2021 = 27.4% / 5.7%) as the review suggested. nb 41 now uses the all-industry line.
--   QWI 2024 rates and bachelor's share carried from industry_hiring_trend: Finance bachelor's share 44%  -> ±0.005.
with p as (
    select * from {{ ref('mart_industry_profile') }}
),

checks as (
    select 'Health Care 62 private change 2019 -> 2025' as check_name, 207000::numeric as expected, change_2019_2025 as got, 500::numeric as tolerance
    from p where industry_key = '62'
    union all
    select 'Health Care 62 private pct change 2019 -> 2025', 0.26, pct_change_2019_2025, 0.005
    from p where industry_key = '62'
    union all
    select 'degree-reachable jobs 54', 277000, degree_reachable_jobs_est, 277000 * 0.05
    from p where industry_key = '54'
    union all
    select 'degree-reachable share 54', 0.64, degree_reachable_share, 0.01
    from p where industry_key = '54'
    union all
    select 'degree-reachable jobs 52', 251000, degree_reachable_jobs_est, 251000 * 0.05
    from p where industry_key = '52'
    union all
    select 'degree-reachable share 52', 0.70, degree_reachable_share, 0.01
    from p where industry_key = '52'
    union all
    select 'degree-reachable jobs 62', 207000, degree_reachable_jobs_est, 207000 * 0.05
    from p where industry_key = '62'
    union all
    select 'degree-reachable share 62', 0.21, degree_reachable_share, 0.01
    from p where industry_key = '62'
    union all
    select 'degree-reachable jobs 51', 136000, degree_reachable_jobs_est, 136000 * 0.05
    from p where industry_key = '51'
    union all
    select 'degree-reachable share 51', 0.65, degree_reachable_share, 0.01
    from p where industry_key = '51'
    union all
    select 'GDP share Finance 52, 2024', 0.263, gdp_share, 0.0005
    from p where industry_key = '52' and gdp_year = 2024
    union all
    select 'GDP share Health Care 62, 2024', 0.064, gdp_share, 0.0005
    from p where industry_key = '62' and gdp_year = 2024
    union all
    select 'bachelor share of hires 25+ 2024 Finance 52', 0.44, bachelor_share_hires_25plus_2024, 0.005
    from p where industry_key = '52'
    union all
    select 'separation rate 2024 Health Care 62 = hiring trend', h.separation_rate, p.separation_rate_2024, 0
    from p join {{ ref('mart_industry_hiring_trend') }} h on h.industry_key = p.industry_key and h.year = 2024
    where p.industry_key = '62'
)

select *
from checks
where got is null or abs(got - expected) > tolerance
