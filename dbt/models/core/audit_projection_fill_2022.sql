-- core.audit_projection_fill_2022: the group-level arithmetic of the D1 fill for the NYS DOL 2022-32 edition,
-- one row per minor group that holds a fill candidate (19). fct_job_projection reads the fill targets from here;
-- a dashboard footnote and docs/data-pipeline.md cite it. Plan: docs/step3-d1-fill-plan.md §3 steps 4-5; D15 (rule B).
--
-- For each group and each measure m in {base, projected, openings}:
--   residual_m  = group total - published leaves that are not collapsed rows  (the collapsed rows' values sit inside it)
--   normal      = max(2020-30 group residual, 0) / 2020-30 group total         (the group's usual unpublished share)
--   f           = min(normal x 2022 total / (residual_b - collapsed_b), 1)     (share of the unpublished gap that is "normal")
--   filled_m    = collapsed_m + (residual_m - collapsed_m) x (1 - f)            (what the part rows receive)
--   retained_m  = residual_m - filled_m                                          (left unassigned, visible in the edition tie-out)

with parts as (
    select * from {{ ref('int_projection_fill_2022_parts') }}
),

src as (
    select * from {{ source('staging', 'stg_nysdol__occupation_projections') }}
    where edition in ('2020-2030', '2022-2032')
),

dim as (
    select soc_code, soc_title, minor_code from {{ ref('dim_job') }}
),

candidate_group as (
    select distinct fill_candidate, fill_group from parts
),

-- Every row of the two hybrid editions with its minor group: dim_job for SOC 2018 codes, the candidate's group for
-- the hybrid codes (every hybrid code these editions publish is a fill candidate; tested).
coded as (
    select
        p.*,
        coalesce(d.minor_code, c.fill_group) as minor_group
    from src as p
    left join dim as d on d.soc_code = p.soc_code
    left join candidate_group as c on c.fill_candidate = p.soc_code
),

fill_groups as (
    select
        fill_group,
        count(distinct fill_candidate) as n_candidates,
        count(*) as n_parts,
        string_agg(distinct fill_candidate, ' ' order by fill_candidate) as candidates
    from parts
    group by fill_group
),

leaves_2022 as (
    select
        minor_group as fill_group,
        sum(base_employment) filter (where quality_flag <> 'publisher_defect')                   as base_published_leaves,
        sum(projected_employment) filter (where quality_flag <> 'publisher_defect')              as projected_published_leaves,
        sum(annual_openings_avg) filter (where quality_flag <> 'publisher_defect')               as openings_published_leaves,
        coalesce(sum(base_employment) filter (where quality_flag = 'publisher_defect'), 0)       as base_collapsed_published,
        coalesce(sum(projected_employment) filter (where quality_flag = 'publisher_defect'), 0)  as projected_collapsed_published,
        coalesce(sum(annual_openings_avg) filter (where quality_flag = 'publisher_defect'), 0)   as openings_collapsed_published
    from coded
    where edition = '2022-2032' and is_leaf
    group by minor_group
),

leaves_2020 as (
    select minor_group as fill_group, sum(base_employment) as base_leaves_2020
    from coded
    where edition = '2020-2030' and is_leaf
    group by minor_group
),

totals as (
    select
        g.fill_group,
        d.soc_title as group_title,
        g.n_candidates,
        g.n_parts,
        g.candidates,
        t22.base_employment::numeric        as base_total,
        t22.projected_employment::numeric   as projected_total,
        t22.annual_openings_avg::numeric    as openings_total,
        l22.base_published_leaves::numeric,
        l22.projected_published_leaves::numeric,
        l22.openings_published_leaves::numeric,
        l22.base_collapsed_published::numeric,
        l22.projected_collapsed_published::numeric,
        l22.openings_collapsed_published::numeric,
        t20.base_employment::numeric        as base_total_2020,
        (t20.base_employment - l20.base_leaves_2020)::numeric as base_residual_2020
    from fill_groups as g
    join dim as d on d.soc_code = g.fill_group
    join coded as t22 on t22.edition = '2022-2032' and t22.soc_code = g.fill_group and t22.soc_level = 'minor'
    join coded as t20 on t20.edition = '2020-2030' and t20.soc_code = g.fill_group and t20.soc_level = 'minor'
    join leaves_2022 as l22 on l22.fill_group = g.fill_group
    join leaves_2020 as l20 on l20.fill_group = g.fill_group
),

residual as (
    select
        *,
        base_total - base_published_leaves           as base_residual,
        projected_total - projected_published_leaves as projected_residual,
        openings_total - openings_published_leaves   as openings_residual,
        greatest(base_residual_2020, 0) / base_total_2020 as normal_share_2020
    from totals
),

retention as (
    select
        *,
        case
            when base_residual - base_collapsed_published > 0
                then least(normal_share_2020 * base_total / (base_residual - base_collapsed_published), 1)
            else 0
        end as f_retained
    from residual
),

filled as (
    select
        *,
        base_collapsed_published + (base_residual - base_collapsed_published) * (1 - f_retained)                 as base_filled,
        projected_collapsed_published + (projected_residual - projected_collapsed_published) * (1 - f_retained)  as projected_filled,
        openings_collapsed_published + (openings_residual - openings_collapsed_published) * (1 - f_retained)     as openings_filled
    from retention
)

select
    fill_group,
    group_title,
    n_candidates,
    n_parts,
    candidates,
    base_total,
    base_published_leaves,
    base_collapsed_published,
    base_residual,
    base_total_2020,
    base_residual_2020,
    normal_share_2020,
    f_retained,
    base_filled,
    base_residual - base_filled as base_retained,
    projected_total,
    projected_published_leaves,
    projected_collapsed_published,
    projected_residual,
    projected_filled,
    projected_residual - projected_filled as projected_retained,
    openings_total,
    openings_published_leaves,
    openings_collapsed_published,
    openings_residual,
    openings_filled,
    openings_residual - openings_filled as openings_retained
from filled
