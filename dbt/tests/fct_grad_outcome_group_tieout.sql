-- Group tie-out (plan §4 item 15): for every cut and group, (a) the sum of share_of_group over unsuppressed rows is
-- at most 1 + 1e-6, and (b) group_workers equals the sum of weight x part_weight over every person row in the group
-- (recomputed from the ephemeral person model, so suppressed cells count too), within 1e-6 and the same on every row.
with fact as (
    select
        *,
        case when cut in ('field_x_soc_major', 'field_x_linked') then group_1 else 'all' end as share_group
    from {{ ref('fct_grad_outcome') }}
),

persons as (
    select
        period, cut,
        case when cut in ('field_x_soc_major', 'field_x_linked') then group_1 else 'all' end as share_group,
        age_band, degree_level,
        sum(weight * part_weight) as workers_all
    from {{ ref('int_grad_outcome_person_cut') }}
    group by 1, 2, 3, 4, 5
),

groups as (
    select
        f.period, f.cut, f.share_group, f.age_band, f.degree_level,
        sum(f.share_of_group) filter (where not f.suppressed) as share_sum,
        min(f.group_workers) as group_workers_min,
        max(f.group_workers) as group_workers_max,
        p.workers_all
    from fact as f
    join persons as p
      on p.period = f.period and p.cut = f.cut and p.share_group = f.share_group
     and p.age_band = f.age_band and p.degree_level = f.degree_level
    group by f.period, f.cut, f.share_group, f.age_band, f.degree_level, p.workers_all
)

select *
from groups
where share_sum > 1 + 1e-6
   or abs(group_workers_min - workers_all) > 1e-6
   or abs(group_workers_max - workers_all) > 1e-6
