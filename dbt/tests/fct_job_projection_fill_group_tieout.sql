-- Group tie-out, 2022-32 (plan §6.2): for each of the 19 fill groups, sum of leaves (published + imputed) + retained
-- = the published group total, for base, projected and openings, within 1e-6. An imputed leaf belongs to the group
-- it was filled from (39-4012 Crematory Operators sits in 39-4000 in the SOC structure but is a 39-9098 part filled
-- from 39-9000, where NYS DOL publishes the aggregate).
with leaves as (
    select coalesce(f.fill_group, d.minor_code) as fill_group,
        sum(f.base_employment) as base_leaves,
        sum(f.projected_employment) as projected_leaves,
        sum(f.annual_openings_avg) as openings_leaves
    from {{ ref('fct_job_projection') }} as f
    join {{ ref('dim_job') }} as d on d.soc_code = f.soc_code
    where f.edition = '2022-2032' and f.is_leaf
    group by 1
)

select a.fill_group,
    a.base_total - a.base_retained - l.base_leaves              as base_gap,
    a.projected_total - a.projected_retained - l.projected_leaves as projected_gap,
    a.openings_total - a.openings_retained - l.openings_leaves  as openings_gap
from {{ ref('audit_projection_fill_2022') }} as a
left join leaves as l on l.fill_group = a.fill_group
where l.fill_group is null
   or abs(a.base_total - a.base_retained - l.base_leaves) > 1e-6
   or abs(a.projected_total - a.projected_retained - l.projected_leaves) > 1e-6
   or abs(a.openings_total - a.openings_retained - l.openings_leaves) > 1e-6
