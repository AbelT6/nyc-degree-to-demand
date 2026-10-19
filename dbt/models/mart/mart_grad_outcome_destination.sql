-- mart.grad_outcome_destination: one row per ACS field of degree x SOC major group x age band x degree level, cut
-- field_x_soc_major of fct_grad_outcome (docs/mart-plan.md §4d; D17 cuts; nb 44 §3). Suppressed cells (under 30
-- responses) are kept with null values and shown as "too few responses", never dropped.
--   * share_of_field = the group's share of the field's workers at that band and level, with its 90% MOE;
--     share_renormalized = the share over the field's readable shares (field_readable_share = the sum of the
--     unsuppressed shares, the ACS coverage the dispersed-major exposure reports); rank_in_field over readable rows.
--   * group_exposure = the SOC major group's employment-weighted observed AI exposure from mart.ai_group_exposure
--     (D7); it is what major_supply_demand multiplies the 22-34 bachelor's shares by for dispersed majors (§3i).
--   * all_level_share = the same group's share of ALL workers at that band and level, from the degree_x_soc cut
--     summed over the group's readable detailed jobs (suppressed jobs drop, so it understates: Management reads
--     15.8% for 22-34 bachelor's where the notebook's person-level figure was 18.3%).
--   * soc_code is the group row of mart.dim_job ('11-0000' ...).
{{ config(alias='grad_outcome_destination') }}

{% call mart_numeric_as_double() %}
with d as (
    select *
    from {{ ref('fct_grad_outcome') }}
    where cut = 'field_x_soc_major'
),

coverage as (
    select
        group_1, age_band, degree_level,
        sum(share_of_group) filter (where not suppressed) as field_readable_share,
        count(*) filter (where not suppressed)            as field_n_readable_groups,
        count(*)                                          as field_n_groups
    from d
    group by 1, 2, 3
),

all_level as (
    select
        age_band, degree_level, left(group_2, 2) as soc_group_code,
        sum(workers) / max(group_workers)             as all_level_share,
        count(*) filter (where suppressed)            as all_level_n_jobs_suppressed
    from {{ ref('fct_grad_outcome') }}
    where cut = 'degree_x_soc'
    group by 1, 2, 3
),

lift as (
    select fod1p, fod_title from {{ ref('int_major_field_lift') }}
),

ranked as (
    select
        d.*,
        case when not d.suppressed
             then rank() over (partition by d.group_1, d.age_band, d.degree_level
                               order by case when d.suppressed then null else d.share_of_group end desc nulls last, d.group_2) end as rank_in_field
    from d
)

select
    r.group_1                                   as fod1p,
    coalesce(r.group_1_label, l.fod_title, 'Field ' || r.group_1) as fod_title,  -- unmapped PUMS fields carry no label in the fact
    l.fod1p is not null                         as is_mapped_field,
    r.group_2                                   as soc_code,
    left(r.group_2, 2)                          as soc_group_code,
    r.group_2_label                             as group_title,
    r.age_band,
    r.degree_level,
    r.n_unweighted,
    r.n_ftyr,
    r.suppressed,
    case when r.suppressed then 'too few responses' end as suppression_note,
    r.workers,
    r.moe_workers,
    r.share_of_group                            as share_of_field,
    r.moe_share                                 as moe_share_of_field,
    r.share_of_group / nullif(c.field_readable_share, 0) as share_renormalized,
    c.field_readable_share,
    c.field_n_readable_groups,
    c.field_n_groups,
    r.rank_in_field,
    r.group_workers                             as field_workers,
    r.earnings_suppressed,
    r.median_earnings_2024usd,
    r.moe_median_earnings,
    r.mean_earnings_2024usd,
    r.moe_mean_earnings,
    a.all_level_share,
    a.all_level_n_jobs_suppressed,
    x.exposure_observed                         as group_exposure,
    x.high_share                                as group_high_share,
    x.coverage                                  as group_exposure_coverage,
    x.low_coverage                              as group_exposure_low_coverage,
    r.source_key,
    'anthropic_ai_exposure'                     as source_key_exposure,
    'ACS PUMS 2020-2024 five-year file, NYC residents, employed civilians not enrolled, 90% MOEs from replicate weights; group exposure = Anthropic observed exposure (Mar 2026) weighted by OEWS NY metro May 2025' as as_of
from ranked as r
left join coverage as c on c.group_1 = r.group_1 and c.age_band = r.age_band and c.degree_level = r.degree_level
left join all_level as a on a.age_band = r.age_band and a.degree_level = r.degree_level and a.soc_group_code = left(r.group_2, 2)
left join lift as l on l.fod1p = r.group_1
left join {{ ref('mart_ai_group_exposure') }} as x on x.soc_code = r.group_2
{% endcall %}
