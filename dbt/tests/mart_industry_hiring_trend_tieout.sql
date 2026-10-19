-- Plan §5 tie-outs for mart.industry_hiring_trend (nb 40 §7b, nb 41):
--   2024 all-private ('00') separation rate 59.2% and new-hire rate 52.9%  -> tolerance ±0.0005 (one decimal of a percent);
--   sum of the 2024 sector separations 2,495,238 vs the QWI '00' row 2,495,257 -> exact (both are sums of released cells);
--   2024 bachelor's-or-higher share of hires 25+: all sectors 31%, Finance (52) 44%, Health Care (62) 28% -> tolerance ±0.005.
with t as (
    select * from {{ ref('mart_industry_hiring_trend') }} where year = 2024
),

checks as (
    select 'separation rate 2024 all private' as check_name, 0.592::numeric as expected, separation_rate as got, 0.0005 as tolerance
    from t where industry_key = '00'
    union all
    select 'new-hire rate 2024 all private', 0.529, new_hire_rate, 0.0005
    from t where industry_key = '00'
    union all
    select 'sum of sector separations 2024', 2495238, sum(separations), 0
    from t where industry_key <> '00'
    union all
    select 'QWI 00 row separations 2024', 2495257, separations, 0
    from t where industry_key = '00'
    union all
    select 'bachelor share of hires 25+ 2024, all sectors', 0.31, bachelor_share_hires_25plus, 0.005
    from t where industry_key = '00'
    union all
    select 'bachelor share of hires 25+ 2024, Finance 52', 0.44, bachelor_share_hires_25plus, 0.005
    from t where industry_key = '52'
    union all
    select 'bachelor share of hires 25+ 2024, Health Care 62', 0.28, bachelor_share_hires_25plus, 0.005
    from t where industry_key = '62'
)

select *
from checks
where got is null or abs(got - expected) > tolerance
