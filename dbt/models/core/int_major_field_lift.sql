-- core.int_major_field_lift: the ACS test of the major -> job bridge, one row per ACS field of degree in ref_fod_cip
-- (78 rows). Grain: fod1p. Rule pre-registered in docs/explore-plan.md §3e and run in nb 44; decision D20.
--
--   linked_share  share of the field's employed, not-enrolled NYC bachelor's-only holders aged 22-34 who hold one of the
--                 field's linked jobs (fct_grad_outcome cut field_x_linked, group_2 = linked); null when the cell has
--                 fewer than 30 responses (D17 suppression)
--   base_rate     share of ALL bachelor's-only holders 22-34 in the same jobs (cut degree_x_soc summed over the field's
--                 linked soc codes; a suppressed job counts 0 and is counted in n_base_jobs_suppressed)
--   lift          linked_share / base_rate. >= 3 pathway, >= 1.5 weak, < 1.5 convention (graduates hold the bridge's
--                 jobs at the population rate, so graduates-per-opening on those jobs is a counting convention, not a
--                 pathway); unreadable when the linked cell is suppressed
--
-- The linked (field, job) set is the one int_grad_outcome_person_cut builds: bachelor's-level rows of bridge_major_job
-- whose CIP is, or sits under, one of the field's ref_fod_cip codes (prefix match on cip2020).

with linked_pairs as (
    select distinct r.fod1p, m.soc_code, m.is_all_other
    from {{ ref('ref_fod_cip') }} as r
    join {{ ref('bridge_major_job') }} as m
      on m.award_level = 5
     and (m.cip_code = r.cip2020 or left(m.cip_code, length(r.cip2020)) = r.cip2020)
),

fields as (
    select fod1p, min(fod_title) as fod_title
    from {{ ref('ref_fod_cip') }}
    group by fod1p
),

young_bachelors as (
    select cut, group_1, group_2, suppressed, share_of_group, moe_share, n_unweighted, group_workers
    from {{ ref('fct_grad_outcome') }}
    where degree_level = 'bachelor' and age_band = '22-34'
      and cut in ('field_x_linked', 'degree_x_soc')
),

linked_cell as (
    select group_1 as fod1p, suppressed, share_of_group, moe_share, n_unweighted, group_workers
    from young_bachelors
    where cut = 'field_x_linked' and group_2 = 'linked'
),

base as (
    select
        p.fod1p,
        count(*) as n_linked_jobs,
        count(*) filter (where p.is_all_other) as n_all_other_jobs,
        sum(coalesce(case when y.suppressed then null else y.share_of_group end, 0)) as base_rate,
        count(*) filter (where y.group_2 is null or y.suppressed) as n_base_jobs_suppressed
    from linked_pairs as p
    left join young_bachelors as y on y.cut = 'degree_x_soc' and y.group_2 = p.soc_code
    group by p.fod1p
),

scored as (
    select
        f.fod1p,
        f.fod_title,
        coalesce(b.n_linked_jobs, 0) as n_linked_jobs,
        coalesce(b.n_all_other_jobs, 0) as n_all_other_jobs,
        c.group_workers as workers_22_34,
        c.n_unweighted as n_unweighted_linked,
        case when coalesce(c.suppressed, true) then null else c.share_of_group end as linked_share,
        case when coalesce(c.suppressed, true) then null else c.moe_share end as moe_linked_share,
        b.base_rate,
        coalesce(b.n_base_jobs_suppressed, 0) as n_base_jobs_suppressed
    from fields as f
    left join base as b on b.fod1p = f.fod1p
    left join linked_cell as c on c.fod1p = f.fod1p
)

select
    fod1p,
    fod_title,
    n_linked_jobs,
    n_all_other_jobs,
    workers_22_34,
    n_unweighted_linked,
    linked_share,
    moe_linked_share,
    base_rate,
    n_base_jobs_suppressed,
    case when linked_share is not null and base_rate > 0 then linked_share / base_rate end as lift,
    case
        when linked_share is null or base_rate is null or base_rate = 0 then 'unreadable'
        when linked_share / base_rate >= 3 then 'pathway'
        when linked_share / base_rate >= 1.5 then 'weak'
        else 'convention'
    end as verdict
from scored
