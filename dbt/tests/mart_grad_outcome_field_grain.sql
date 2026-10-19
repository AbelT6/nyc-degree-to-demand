-- Grain of mart.grad_outcome_field: one row per fod1p x age_band x degree_level, every field_total row of the fact
-- present, premium columns only on the 28-34 and 35-64 bands, and the two rows of a pair carry the same premium.
with dup as (
    select 'duplicate key' as check_name, fod1p || ' ' || age_band || ' ' || degree_level as detail
    from {{ ref('mart_grad_outcome_field') }}
    group by fod1p, age_band, degree_level
    having count(*) > 1
),

counts as (
    select 'row count differs from the field_total cut' as check_name,
           (select count(*) from {{ ref('mart_grad_outcome_field') }})::text || ' vs '
           || (select count(*) from {{ ref('fct_grad_outcome') }} where cut = 'field_total')::text as detail
    where (select count(*) from {{ ref('mart_grad_outcome_field') }})
       <> (select count(*) from {{ ref('fct_grad_outcome') }} where cut = 'field_total')
),

bands as (
    select 'premium outside the 28-34 / 35-64 bands' as check_name, fod1p || ' ' || age_band as detail
    from {{ ref('mart_grad_outcome_field') }}
    where age_band not in ('28-34', '35-64') and (premium_median is not null or premium_verdict is not null or premium_band)
),

pairs as (
    select 'premium differs between the bachelor and graduate rows' as check_name, fod1p || ' ' || age_band as detail
    from {{ ref('mart_grad_outcome_field') }}
    where premium_band
    group by fod1p, age_band
    having count(distinct coalesce(premium_verdict, '')) > 1 or count(distinct coalesce(premium_median, -9)) > 1
)

select * from dup
union all select * from counts
union all select * from bands
union all select * from pairs
