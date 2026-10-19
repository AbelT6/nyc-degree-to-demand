-- mart.dim_college: NYC colleges in the IPEDS directory; is_cuny drives the "CUNY vs all NYC" slicer (S9).
{{ config(alias='dim_college') }}

select
    unitid,
    college_name,
    borough,
    sector,
    control,
    is_cuny,
    case when is_cuny then 'CUNY' else 'Other NYC colleges' end as college_group,
    is_closed,
    'ipeds_directory' as source_key
from {{ ref('dim_college') }}
