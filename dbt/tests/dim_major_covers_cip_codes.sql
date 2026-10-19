-- Every CIP code a core fact or bridge will carry is a dim_major row, or a CIP 2010 code that
-- bridge_cip_2010_2020 (step 2) maps onto one, or NCES's 99.9999 "no match". Lists any other code.
with fact_codes as (
    select 'ipeds_completions_' || cip_edition as src, cip_code from {{ source('staging', 'stg_ipeds__completions') }}
    union select 'cuny_programs', cip_code from {{ source('staging', 'stg_cuny__program_graduates') }} where cip_code is not null
    union select 'nces_cip_soc', cip_code from {{ source('staging', 'stg_nces__cip_soc') }}
    union select 'career_clusters', cip_code from {{ source('staging', 'stg_cte__cip_subcluster') }}
),

bridgeable as (
    select cip_2010 as cip_code from {{ source('staging', 'stg_nces__cip_2010_2020') }}
    union select '99.9999'
)

select f.src, f.cip_code
from fact_codes as f
where f.cip_code not in (select cip_code from {{ ref('dim_major') }})
  and f.cip_code not in (select cip_code from bridgeable where cip_code is not null)
order by 1, 2
