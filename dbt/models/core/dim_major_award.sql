-- core.dim_major_award: every detailed CIP 2020 major x the two in-scope award levels (2,325 x 2 = 4,650 rows), with
-- what the D2 filter found for it. Grain: cip_code x award_level (major_award_key). This is the "transfer pathway
-- flag table" of docs/step2-bridges-plan.md: the awards fact (step 4) joins it so every IPEDS row gets a label and
-- nothing is dropped. Plan: docs/step2b-major-bridges-plan.md §5-6; decisions D2, D14, D16, D20.
--
-- link_status:
--   linked            at least one job passes at 15% (rows in bridge_major_job) and the ACS test does not reject the link
--   dispersed         (bachelor's only, D20) at least one job passes at 15%, but the major's ACS field of degree holds
--                     the bridge's jobs at the population rate (int_major_field_lift lift < 1.5): the graduates spread
--                     across job families, so the page shows ACS destinations and earnings, not graduates per opening.
--                     The bridge rows are kept; the mart does not count these graduates as supply to a job.
--   transfer_pathway  the crosswalk links the major to jobs, none of which passes at this level
--   not_in_crosswalk  no links: NCES lists the major with no job (dim_major.cip_soc_status = no_job_link) or does not
--                     list it at all (not_in_crosswalk); cip_soc_status keeps the distinction
--
-- field_fod1p / field_lift / field_verdict carry the ACS field the major maps to through ref_fod_cip (prefix match on
-- cip2020, as int_grad_outcome_person_cut joins it). Three majors map to two fields; the field with the higher readable
-- lift is kept, so a major is dispersed only when no field it maps to reaches 1.5. The field columns are filled at
-- both levels (the map is level-free) but the status changes at the bachelor's level only: the ACS asks field of
-- degree of bachelor's holders alone, so the test says nothing about associate's majors.

with majors as (
    select cip_code, cip_soc_status
    from {{ ref('dim_major') }}
    where cip_level = 'detailed'
),

levels as (
    select award_level
    from {{ ref('dim_award_level') }}
    where in_v1_scope
),

filtered as (
    select
        cip_code,
        award_level,
        count(*) as n_links,
        count(*) filter (where passes_filter_10) as n_pass_10,
        count(*) filter (where passes_filter_15) as n_pass_15,
        count(*) filter (where passes_filter_20) as n_pass_20
    from {{ ref('int_major_job_filter') }}
    group by cip_code, award_level
),

bridged as (
    select
        cip_code,
        award_level,
        sum(openings_nyc) as openings_nyc_total,
        bool_and(weight_openings is not null) as has_openings_weight,
        count(*) filter (where is_all_other) as n_all_other_jobs
    from {{ ref('bridge_major_job') }}
    group by cip_code, award_level
),

-- D20: the major's ACS field; when a major maps to two fields, the one with the higher readable lift.
field_map as (
    select distinct on (m.cip_code)
        m.cip_code,
        l.fod1p,
        l.lift,
        l.verdict
    from majors as m
    join {{ ref('ref_fod_cip') }} as r
      on (m.cip_code = r.cip2020 or left(m.cip_code, length(r.cip2020)) = r.cip2020)
    join {{ ref('int_major_field_lift') }} as l on l.fod1p = r.fod1p
    order by m.cip_code, l.lift desc nulls last, l.fod1p
)

select
    m.cip_code || '|' || v.award_level::text as major_award_key,
    m.cip_code,
    v.award_level,
    m.cip_soc_status,
    coalesce(f.n_links, 0) as n_links,
    coalesce(f.n_pass_10, 0) as n_pass_10,
    coalesce(f.n_pass_15, 0) as n_pass_15,
    coalesce(f.n_pass_20, 0) as n_pass_20,
    case
        when coalesce(f.n_pass_15, 0) > 0 and v.award_level = 5 and fm.verdict = 'convention' then 'dispersed'
        when coalesce(f.n_pass_15, 0) > 0 then 'linked'
        when coalesce(f.n_links, 0) > 0 then 'transfer_pathway'
        else 'not_in_crosswalk'
    end as link_status,
    b.openings_nyc_total,
    coalesce(b.has_openings_weight, false) as has_openings_weight,
    coalesce(b.n_all_other_jobs, 0) as n_all_other_jobs,
    fm.fod1p as field_fod1p,
    fm.lift as field_lift,
    coalesce(fm.verdict, 'no_field') as field_verdict
from majors as m
cross join levels as v
left join filtered as f on f.cip_code = m.cip_code and f.award_level = v.award_level
left join bridged as b on b.cip_code = m.cip_code and b.award_level = v.award_level
left join field_map as fm on fm.cip_code = m.cip_code
