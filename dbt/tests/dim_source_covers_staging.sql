-- Every staging table's source_file path starts with "<group>/<manifest key>/", and that key must be a
-- dim_source row. stg_census__qwi carries no source_file; its key is census_qwi.
{% set tables = [
    'stg_anthropic__job_exposure', 'stg_anthropic__task_penetration', 'stg_bea__county_gdp', 'stg_bls__cpi',
    'stg_bls__ep_attainment', 'stg_bls__ep_entry_requirements', 'stg_bls__ep_occupation_projections',
    'stg_bls__ind_occ_matrix', 'stg_bls__jolts', 'stg_bls__laus', 'stg_bls__oews_hybrid',
    'stg_bls__oews_metro_occupations', 'stg_bls__oews_research_ny', 'stg_bls__ooh_description', 'stg_bls__qcew_county',
    'stg_bls__soc_2010_2018', 'stg_bls__soc_2018_structure', 'stg_census__acs_pums_person',
    'stg_cte__cip_subcluster', 'stg_cte__cluster', 'stg_cte__naics_subcluster', 'stg_cte__soc_subcluster',
    'stg_cuny__program_enrollment', 'stg_cuny__program_graduates', 'stg_eloundou__job_exposure',
    'stg_eloundou__task_exposure', 'stg_indeed__postings_area', 'stg_indeed__postings_category',
    'stg_indeed__postings_national', 'stg_ipeds__completions', 'stg_ipeds__institutions',
    'stg_nces__cip_2010_2020', 'stg_nces__cip_2020', 'stg_nces__cip_soc', 'stg_nysdol__ces_monthly',
    'stg_nysdol__occupation_projections', 'stg_nysdol__occupation_wages', 'stg_nysdol__projections_xlsx',
    'stg_nysdol__qcew_annual', 'stg_nysdol__ui_beneficiaries', 'stg_onet__descriptor_rating',
    'stg_onet__education_experience', 'stg_onet__in_demand_pct', 'stg_onet__job_zone', 'stg_onet__occupation', 'stg_onet__software',
    'stg_revelio__postings'
] %}

with staging_keys as (
    {% for t in tables %}
    select '{{ t }}' as table_name, split_part(source_file, '/', 2) as source_key
    from {{ source('staging', t) }}
    group by 1, 2
    union all
    {% endfor %}
    select 'stg_census__qwi', 'census_qwi'
)

select table_name, source_key
from staging_keys
where source_key not in (select source_key from {{ ref('dim_source') }})
   or source_key is null or source_key = ''
order by 1, 2
