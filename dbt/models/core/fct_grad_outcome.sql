-- core.fct_grad_outcome: what NYC residents with each degree level (and each bachelor's field of degree) do and earn,
-- from ACS PUMS 2020-2024 (NYC residents, civilian employed, not enrolled), with a 90% margin of error on every estimate.
-- Grain: period x cut x group_1 x group_2 x age_band x degree_level (one long fact; four cuts, four age bands).
-- Plan: docs/step4-facts-plan.md §3e (design), §6.1 (cuts B, D, E, G), §4 item 15 (tests), §5 risks 1 and 10;
-- decisions D2 (the link check, not weights), D4 (ref_fod_cip), D5 (n < 30 suppression, replicate-weight MOE).
-- Person rows, the landing on dim_job (direct code, else bridge_job_code acs_socp parts) and the cut definitions are in
-- int_grad_outcome_person_cut (ephemeral); this model is one aggregation pass over it.
--
-- share_of_group = workers / group_workers, the group being
--   field_x_soc_major, field_x_linked   group_1 (field) x age_band x degree_level   (shares over jobs sum to 1 per field)
--   degree_x_soc, field_total            age_band x degree_level                     (share of all holders of that degree)
-- Earnings (mean, median, 2024 dollars) are for full-time year-round workers only (n_ftyr persons); the median is the
-- weighted median by cumulative weight (smallest earnings where the cumulative weight reaches half the total).
-- MOE = 1.645 x sqrt(4/80 x sum over r = 1..80 of (est_r - est)^2), est_r recomputed with pwgtp_r in place of weight
-- (Census PUMS accuracy formula, card acs_pums.md §3). For shares and means the replicate estimate re-divides by the
-- replicate denominator; for the median it is the replicate weighted median.
-- suppressed = n_unweighted < 30: workers, share, earnings and every MOE are null, n_unweighted / n_ftyr / group_workers
-- and the imputation shares stay so the mart can say "too few responses". earnings_suppressed = n_ftyr < 30 (brief S13
-- applied to the earnings sample): the two earnings estimates and their MOEs are null, n_ftyr kept. Unrounded numerics.

{% set reps = range(1, 81) %}

with rows_ as (
    select * from {{ ref('int_grad_outcome_person_cut') }}
),

agg as (
    select
        period,
        cut,
        group_1,
        group_2,
        age_band,
        degree_level,
        count(distinct person_id)                                 as n_unweighted,
        count(distinct person_id) filter (where is_ftyr)          as n_ftyr,
        sum(weight * part_weight)                                 as workers,
        {% for r in reps %}
        sum(pwgtp{{ r }} * part_weight)                           as workers_{{ r }},
        {% endfor %}
        sum(weight * part_weight * earnings_2024usd) filter (where is_ftyr) as earn_w,
        sum(weight * part_weight)                    filter (where is_ftyr) as ftyr_w,
        {% for r in reps %}
        sum(pwgtp{{ r }} * part_weight * earnings_2024usd) filter (where is_ftyr) as earn_w_{{ r }},
        sum(pwgtp{{ r }} * part_weight)                    filter (where is_ftyr) as ftyr_w_{{ r }},
        {% endfor %}
        sum(weight * part_weight) filter (where fod_imputed)  as fod_imputed_w,
        sum(weight * part_weight) filter (where occ_imputed)  as occ_imputed_w,
        sum(weight * part_weight) filter (where wage_imputed) as wage_imputed_w,
        bool_or(is_allocated)                                 as includes_allocated_codes
    from rows_
    group by period, cut, group_1, group_2, age_band, degree_level
),

-- Weighted median for full-time year-round workers: running weight along the earnings order, once per weight column.
ftyr_cum as (
    select
        period, cut, group_1, group_2, age_band, degree_level,
        earnings_2024usd,
        sum(weight * part_weight) over w as cum_w,
        {% for r in reps %}
        sum(pwgtp{{ r }} * part_weight) over w as cum_w_{{ r }}{{ "," if not loop.last }}
        {% endfor %}
    from rows_
    where is_ftyr
    window w as (
        partition by period, cut, group_1, group_2, age_band, degree_level
        order by earnings_2024usd, person_id, soc_code
        rows between unbounded preceding and current row
    )
),

medians as (
    select
        c.period, c.cut, c.group_1, c.group_2, c.age_band, c.degree_level,
        min(c.earnings_2024usd) filter (where c.cum_w >= a.ftyr_w / 2) as median_earnings,
        {% for r in reps %}
        min(c.earnings_2024usd) filter (where c.cum_w_{{ r }} >= a.ftyr_w_{{ r }} / 2) as median_earnings_{{ r }}{{ "," if not loop.last }}
        {% endfor %}
    from ftyr_cum as c
    join agg as a
      on a.period = c.period and a.cut = c.cut and a.group_1 = c.group_1 and a.group_2 = c.group_2
     and a.age_band = c.age_band and a.degree_level = c.degree_level
    group by c.period, c.cut, c.group_1, c.group_2, c.age_band, c.degree_level
),

-- Group totals for the share denominator, for the full-sample weight and each replicate.
grouped as (
    select
        a.*,
        sum(a.workers) over g as group_workers,
        {% for r in reps %}
        sum(a.workers_{{ r }}) over g as group_workers_{{ r }}{{ "," if not loop.last }}
        {% endfor %}
    from agg as a
    window g as (
        partition by
            a.period, a.cut,
            case when a.cut in ('field_x_soc_major', 'field_x_linked') then a.group_1 else 'all' end,
            a.age_band, a.degree_level
    )
),

estimates as (
    select
        g.*,
        g.workers / nullif(g.group_workers, 0) as share_of_group,
        g.earn_w / nullif(g.ftyr_w, 0)         as mean_earnings,
        m.median_earnings,
        {% for r in reps %}
        g.workers_{{ r }} / nullif(g.group_workers_{{ r }}, 0) as share_{{ r }},
        g.earn_w_{{ r }} / nullif(g.ftyr_w_{{ r }}, 0)         as mean_{{ r }},
        m.median_earnings_{{ r }}{{ "," if not loop.last }}
        {% endfor %}
    from grouped as g
    left join medians as m
      on m.period = g.period and m.cut = g.cut and m.group_1 = g.group_1 and m.group_2 = g.group_2
     and m.age_band = g.age_band and m.degree_level = g.degree_level
),

with_moe as (
    select
        *,
        n_unweighted < 30 as suppressed,
        n_ftyr < 30 as earnings_suppressed,
        1.645 * sqrt(4.0 / 80 * ({% for r in reps %}power(workers_{{ r }} - workers, 2){{ " + " if not loop.last }}{% endfor %}))
            as moe_workers,
        1.645 * sqrt(4.0 / 80 * ({% for r in reps %}power(share_{{ r }} - share_of_group, 2){{ " + " if not loop.last }}{% endfor %}))
            as moe_share,
        1.645 * sqrt(4.0 / 80 * ({% for r in reps %}power(mean_{{ r }} - mean_earnings, 2){{ " + " if not loop.last }}{% endfor %}))
            as moe_mean_earnings,
        1.645 * sqrt(4.0 / 80 * ({% for r in reps %}power(median_earnings_{{ r }} - median_earnings, 2){{ " + " if not loop.last }}{% endfor %}))
            as moe_median_earnings
    from estimates
),

field_titles as (
    -- official Census labels for all 174 FOD1P codes (ref_fod_cip covers only the 78 mapped fields)
    select fod1p, fod_title from {{ ref('acs_fod1p') }}
)

select
    e.period,
    e.cut,
    e.group_1,
    t.fod_title as group_1_label,
    e.group_2,
    coalesce(j.soc_title, e.group_2) as group_2_label,
    e.age_band,
    e.degree_level,
    e.n_unweighted,
    e.n_ftyr,
    e.suppressed,
    case when not e.suppressed then e.workers end              as workers,
    case when not e.suppressed then e.moe_workers end          as moe_workers,
    case when not e.suppressed then e.share_of_group end       as share_of_group,
    case when not e.suppressed then e.moe_share end            as moe_share,
    e.earnings_suppressed,
    case when not e.suppressed and not e.earnings_suppressed then e.mean_earnings end        as mean_earnings_2024usd,
    case when not e.suppressed and not e.earnings_suppressed then e.moe_mean_earnings end    as moe_mean_earnings,
    case when not e.suppressed and not e.earnings_suppressed then e.median_earnings end      as median_earnings_2024usd,
    case when not e.suppressed and not e.earnings_suppressed then e.moe_median_earnings end  as moe_median_earnings,
    e.group_workers,
    case when e.degree_level in ('bachelor', 'graduate') then coalesce(e.fod_imputed_w, 0) / e.workers end as pct_fod_imputed,
    coalesce(e.occ_imputed_w, 0) / e.workers  as pct_occ_imputed,
    coalesce(e.wage_imputed_w, 0) / e.workers as pct_wage_imputed,
    e.includes_allocated_codes,
    'acs_pums' as source_key
from with_moe as e
left join field_titles as t on t.fod1p = e.group_1
left join {{ ref('dim_job') }} as j on j.soc_code = e.group_2
