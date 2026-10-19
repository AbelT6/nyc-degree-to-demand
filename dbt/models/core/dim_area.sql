-- core.dim_area: the ten geographies, from the hand-built seed ref/area.csv. One column per source
-- code system. NYC (five boroughs) and the NY metro (CBSA 35620) are separate rows and never mixed.

select
    area_key,
    area_name,
    area_type,
    sort_order,
    state_fips,
    county_fips,
    cbsa_code,
    laus_area_code,
    qcew_ny_area_code,
    nysdol_area_code,
    oews_area_code,
    indeed_area_code,
    cpi_area_code,
    jolts_state_code,
    ui_region,
    ui_county,
    area_type in ('city', 'borough') as is_nyc,
    note
from {{ ref('area') }}
