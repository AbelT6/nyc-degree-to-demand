-- The dashboard universe measured in docs/core-build-plan.md §2 must reproduce from dim_job:
-- NYC 2022-32 leaf jobs with Associate's or Bachelor's entry = 162 jobs, 118,601 openings/yr,
-- of which 16 are "All Other" codes (D11).
with u as (
    select d.soc_code, d.is_all_other, p.annual_openings_avg
    from {{ source('staging', 'stg_nysdol__occupation_projections') }} as p
    join {{ ref('dim_job') }} as d on d.soc_code = p.soc_code
    where p.edition = '2022-2032' and p.is_leaf and d.is_degree_entry
)

select count(*) as jobs, sum(annual_openings_avg) as openings, count(*) filter (where is_all_other) as all_other
from u
having count(*) <> 162
    or sum(annual_openings_avg) <> 118601
    or count(*) filter (where is_all_other) <> 16
