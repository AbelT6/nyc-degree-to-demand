-- Every area code in the geography-bearing staging tables resolves to exactly one dim_area row
-- through the matching alias column. UI regions outside NYC are out of v1 scope and listed as bridgeable.
with fact_codes as (
    select 'laus' as src, area_code as code, 'laus_area_code' as via from {{ source('staging', 'stg_bls__laus') }}
    union select 'nysdol_qcew', area_code, 'qcew_ny_area_code' from {{ source('staging', 'stg_nysdol__qcew_annual') }}
    union select 'nysdol_wages', area_code, 'nysdol_area_code' from {{ source('staging', 'stg_nysdol__occupation_wages') }}
    union select 'oews_metro', area_code, 'oews_area_code' from {{ source('staging', 'stg_bls__oews_metro_occupations') }}
    union select 'indeed', area_code, 'indeed_area_code' from {{ source('staging', 'stg_indeed__postings_area') }}
    union select 'cpi', area_code, 'cpi_area_code' from {{ source('staging', 'stg_bls__cpi') }}
    union select 'jolts', state_code, 'jolts_state_code' from {{ source('staging', 'stg_bls__jolts') }}
    union select 'ui_region', region, 'ui_region' from {{ source('staging', 'stg_nysdol__ui_beneficiaries') }} where is_nyc
    union select 'ui_county', county, 'ui_county' from {{ source('staging', 'stg_nysdol__ui_beneficiaries') }} where is_nyc
    union select 'qwi', county_fips, 'county_fips' from {{ source('staging', 'stg_census__qwi') }}
    union select 'bls_qcew_county', county_fips, 'county_fips' from {{ source('staging', 'stg_bls__qcew_county') }}
    union select 'bea', county_fips, 'county_fips' from {{ source('staging', 'stg_bea__county_gdp') }}
    union select 'ipeds', county_fips, 'county_fips' from {{ source('staging', 'stg_ipeds__institutions') }}
),

resolved as (
    select f.src, f.code, f.via,
        (
            select count(*) from {{ ref('dim_area') }} as d
            where (f.via = 'laus_area_code' and d.laus_area_code = f.code)
               or (f.via = 'qcew_ny_area_code' and d.qcew_ny_area_code = f.code)
               or (f.via = 'nysdol_area_code' and d.nysdol_area_code = f.code)
               or (f.via = 'oews_area_code' and d.oews_area_code = f.code)
               or (f.via = 'indeed_area_code' and d.indeed_area_code = f.code)
               or (f.via = 'cpi_area_code' and d.cpi_area_code = f.code)
               or (f.via = 'jolts_state_code' and d.jolts_state_code = f.code)
               or (f.via = 'ui_region' and d.ui_region = f.code)
               or (f.via = 'ui_county' and d.ui_county = f.code)
               or (f.via = 'county_fips' and d.county_fips = f.code)
        ) as n_rows
    from fact_codes as f
)

select src, code, via, n_rows
from resolved
where n_rows <> 1
order by 1, 2
