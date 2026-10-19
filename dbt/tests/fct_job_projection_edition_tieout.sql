-- Edition tie-out (plan §6.3): (a) every edition's leaves cover >= 97% of the published total (2022-32 >= 98.5% after
-- the fill); (b) for 2022-32 the total decomposes exactly into leaves + retained (fill groups) + the residual of the
-- other minor groups + the minor-to-total rounding slack, for base, projected and openings, within 1e-6.
-- Leaves are assigned to the minor group they were filled from when imputed (39-4012 -> 39-9000), else the SOC one.
with f as (
    select f.*, coalesce(f.fill_group, d.minor_code) as minor_code, d.soc_level
    from {{ ref('fct_job_projection') }} as f
    join {{ ref('dim_job') }} as d on d.soc_code = f.soc_code
),

coverage as (
    select edition,
        sum(base_employment) filter (where is_leaf) / max(base_employment) filter (where soc_code = '00-0000') as leaf_share
    from f
    group by edition
),

minor_residual as (
    select m.soc_code as minor_code,
        m.base_employment - coalesce(sum(l.base_employment), 0) as base_residual,
        m.projected_employment - coalesce(sum(l.projected_employment), 0) as projected_residual,
        m.annual_openings_avg - coalesce(sum(l.annual_openings_avg), 0) as openings_residual
    from f as m
    left join f as l on l.edition = m.edition and l.is_leaf and l.minor_code = m.soc_code
    where m.edition = '2022-2032' and m.soc_level = 'minor'
    group by m.soc_code, m.base_employment, m.projected_employment, m.annual_openings_avg
),

decomposition as (
    select
        (select base_employment from f where edition = '2022-2032' and soc_code = '00-0000')
            - (select sum(base_employment) from f where edition = '2022-2032' and is_leaf)
            - (select sum(base_retained) from {{ ref('audit_projection_fill_2022') }})
            - (select sum(base_residual) from minor_residual where minor_code not in (select fill_group from {{ ref('audit_projection_fill_2022') }}))
            - ((select base_employment from f where edition = '2022-2032' and soc_code = '00-0000')
               - (select sum(base_employment) from f where edition = '2022-2032' and soc_level = 'minor')) as base_gap,
        (select projected_employment from f where edition = '2022-2032' and soc_code = '00-0000')
            - (select sum(projected_employment) from f where edition = '2022-2032' and is_leaf)
            - (select sum(projected_retained) from {{ ref('audit_projection_fill_2022') }})
            - (select sum(projected_residual) from minor_residual where minor_code not in (select fill_group from {{ ref('audit_projection_fill_2022') }}))
            - ((select projected_employment from f where edition = '2022-2032' and soc_code = '00-0000')
               - (select sum(projected_employment) from f where edition = '2022-2032' and soc_level = 'minor')) as projected_gap,
        (select annual_openings_avg from f where edition = '2022-2032' and soc_code = '00-0000')
            - (select sum(annual_openings_avg) from f where edition = '2022-2032' and is_leaf)
            - (select sum(openings_retained) from {{ ref('audit_projection_fill_2022') }})
            - (select sum(openings_residual) from minor_residual where minor_code not in (select fill_group from {{ ref('audit_projection_fill_2022') }}))
            - ((select annual_openings_avg from f where edition = '2022-2032' and soc_code = '00-0000')
               - (select sum(annual_openings_avg) from f where edition = '2022-2032' and soc_level = 'minor')) as openings_gap
)

select 'coverage_below_band' as problem, edition || ' ' || round(leaf_share * 100, 2)::text as detail
from coverage
where leaf_share < 0.97 or (edition = '2022-2032' and leaf_share < 0.985)
union all
select 'decomposition_2022_32', 'base ' || base_gap::text || ' projected ' || projected_gap::text || ' openings ' || openings_gap::text
from decomposition
where abs(base_gap) > 1e-6 or abs(projected_gap) > 1e-6 or abs(openings_gap) > 1e-6
