-- Plan §5 / nb 44 §3-§4 tie-outs for mart.grad_outcome_destination. Tolerances: shares ±0.0005; counts exact.
-- Psychology 22-34 bachelor's Management share 17.0% (the fact's 90% MOE is 0.032; nb 44 printed ± 2.7, see the M3
-- as-built). The notebook's all-bachelor's Management share 18.3% is a person-level figure the suppressed cuts cannot
-- reproduce (degree_x_soc over readable jobs reads 15.8%); the test pins the view's own definition so drift is caught.
with d as (
    select * from {{ ref('mart_grad_outcome_destination') }}
),

psy as (
    select * from d where fod1p = '5200' and soc_code = '11-0000' and age_band = '22-34' and degree_level = 'bachelor'
),

checks as (
    select 'Psychology 22-34 bachelor''s Management share' as check_name, 0.170::numeric as expected, share_of_field::numeric as got, 0.0005::numeric as tolerance from psy
    union all
    select 'Psychology 22-34 bachelor''s Management is its top destination', 1, rank_in_field, 0 from psy
    union all
    select 'Psychology 22-34 bachelor''s readable destination groups', 10, field_n_readable_groups, 0 from psy
    union all
    select 'Psychology 22-34 bachelor''s readable share (ACS coverage)', 0.881, field_readable_share, 0.0005 from psy
    union all
    select 'all-bachelor''s 22-34 Management share from the degree_x_soc cut (readable jobs; notebook person-level 0.183)', 0.158, all_level_share, 0.0005 from psy
    union all
    select 'Management group exposure carried on the row = mart.ai_group_exposure 11-0000', 0,
           abs(group_exposure - (select exposure_observed from {{ ref('mart_ai_group_exposure') }} where soc_code = '11-0000')), 0.00001 from psy
    union all
    select 'Criminal Justice 5301 22-34 bachelor''s readable share (ACS coverage)', 0.42, max(field_readable_share), 0.005
    from d where fod1p = '5301' and age_band = '22-34' and degree_level = 'bachelor'
    union all
    select 'SOC major groups per field x band x level', 22, max(field_n_groups), 0 from d where age_band = '22-34' and degree_level = 'bachelor'
    union all
    select 'rows with a group exposure (every civilian group has one)', 0, count(*) filter (where group_exposure is null), 0 from d
)

select *
from checks
where got is null or abs(got - expected) > tolerance
