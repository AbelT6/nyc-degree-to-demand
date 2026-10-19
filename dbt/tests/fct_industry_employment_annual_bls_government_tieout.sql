-- Plan §4 item 11 (source card bls_qcew_county.md §5): for 2019, 2024 and 2025 and each government ownership, the BLS
-- county files' all-industry government employment (agglvl 71) summed over the five boroughs equals the NYS DOL NYC
-- all-industries row within ±2 jobs. Reads staging directly so the comparison is source to fact.
with bls as (
    select
        year,
        case own_code
            when '1' then 'Federal Government'
            when '2' then 'State Government'
            when '3' then 'Local Government'
        end as ownership,
        sum(emp) as bls_employment
    from {{ source('staging', 'stg_bls__qcew_county') }}
    where agglvl_code = '71' and own_code in ('1', '2', '3') and year in (2019, 2024, 2025)
    group by 1, 2
),

fact as (
    select year, ownership, employment
    from {{ ref('fct_industry_employment_annual') }}
    where area_key = 'nyc' and industry_key = '00' and source_key = 'nysdol_qcew_annual'
      and ownership in ('Federal Government', 'State Government', 'Local Government')
      and year in (2019, 2024, 2025)
)

select b.year, b.ownership, b.bls_employment, f.employment as nysdol_employment, b.bls_employment - f.employment as diff
from bls as b
full join fact as f using (year, ownership)
where f.employment is null or b.bls_employment is null or abs(b.bls_employment - f.employment) > 2
