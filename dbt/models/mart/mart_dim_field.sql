-- mart.dim_field: one row per ACS field of degree (FOD1P, the 174 codes in the Census PUMS dictionary, seed acs_fod1p),
-- the dimension the two ACS views (grad_outcome_field, grad_outcome_destination) and dim_major.field_fod1p share, so a
-- major reaches its field's outcomes through one *:1 and one 1:* relationship (D24 B; docs/mart-plan.md §4a).
-- is_mapped = the field is one of the 78 that int_major_field_lift scores (a CIP -> FOD1P map exists through
-- ref_fod_cip); lift and verdict are D20's (bachelor's-only workers 22-34), null on the 96 unmapped fields.
{{ config(alias='dim_field') }}

{% call mart_numeric_as_double() %}
select
    f.fod1p,
    f.fod_title                                         as field_title,
    l.fod1p is not null                                 as is_mapped,
    l.lift,
    l.verdict,
    'acs_pums'                                          as source_key
from {{ ref('acs_fod1p') }} as f
left join {{ ref('int_major_field_lift') }} as l on l.fod1p = f.fod1p
{% endcall %}
