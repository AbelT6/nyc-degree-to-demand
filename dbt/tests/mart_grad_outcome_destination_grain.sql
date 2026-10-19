-- Grain of mart.grad_outcome_destination: one row per fod1p x soc_code x age_band x degree_level, every
-- field_x_soc_major row of the fact present, readable shares of a field sum to field_readable_share (<= 1.0005),
-- renormalized readable shares sum to 1 per field x band x level, ranks only on readable rows.
with dup as (
    select 'duplicate key' as check_name, fod1p || ' ' || soc_code || ' ' || age_band || ' ' || degree_level as detail
    from {{ ref('mart_grad_outcome_destination') }}
    group by fod1p, soc_code, age_band, degree_level
    having count(*) > 1
),

counts as (
    select 'row count differs from the field_x_soc_major cut' as check_name,
           (select count(*) from {{ ref('mart_grad_outcome_destination') }})::text || ' vs '
           || (select count(*) from {{ ref('fct_grad_outcome') }} where cut = 'field_x_soc_major')::text as detail
    where (select count(*) from {{ ref('mart_grad_outcome_destination') }})
       <> (select count(*) from {{ ref('fct_grad_outcome') }} where cut = 'field_x_soc_major')
),

shares as (
    select 'readable shares do not match field_readable_share or exceed 1' as check_name, fod1p || ' ' || age_band || ' ' || degree_level as detail
    from {{ ref('mart_grad_outcome_destination') }}
    where not suppressed
    group by fod1p, age_band, degree_level
    having abs(sum(share_of_field) - max(field_readable_share)) > 0.0005
        or max(field_readable_share) > 1.0005
        or abs(sum(share_renormalized) - 1) > 0.0005
),

ranks as (
    select 'rank on a suppressed row or missing on a readable one' as check_name, fod1p || ' ' || soc_code || ' ' || age_band || ' ' || degree_level as detail
    from {{ ref('mart_grad_outcome_destination') }}
    where (suppressed and rank_in_field is not null) or (not suppressed and rank_in_field is null)
)

select * from dup
union all select * from counts
union all select * from shares
union all select * from ranks
