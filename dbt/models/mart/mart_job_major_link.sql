-- mart.job_major_link: one row per job x major (every bridge_major_job row, 15% filter; 3,873 after D57). Implements
-- docs/mart-plan.md §4b row job_major_link and explore-plan §3c (a) (the job grain of the S11 grid); D2, D16, D20.
--   * weight_openings (D2 headline; 31 null weights treated as 0, flagged) and weight_equal (the other end of the
--     D2 range); awards_2024_* = 2024 first-major awards (major_number = 1) of the major, all NYC colleges and CUNY;
--     graduates_2024_* = awards x weight = this pair's share of the major's graduates under each weight.
--   * counts_as_supply = the major's link_status is 'linked' (D20: dispersed majors keep the link but their graduates
--     are not supply to the job; transfer-pathway / not-in-crosswalk majors have no bridge row).
--   * job_* columns repeat the job's totals on every row of the job: graduates from linked majors under both weights,
--     the D20-off total (linked + dispersed), 2022-32 leaf openings and projected change, and graduates per opening =
--     linked graduates / leaf openings (null where the job has no 2022-32 leaf row; the bridge's estimated openings
--     are carried as openings_nyc_bridge but never divide). These equal mart.job_profile for every job it carries
--     (tests/mart_job_major_link_tieout.sql).
--   * Job page display (docs/page3-build-plan.md §3.2, §4 item 7): major_title and award_label from dim_major;
--     major_label = the title, led by "Assoc. · " on associate rows of a job whose 2024 graduates come from both levels
--     (26 named jobs; the block's subtitle then reads "Bachelor's & associate graduates", job_profile.majors_levels_label);
--     major_label_details leads with "✦ " for dispersed majors (Details view only). Both marks lead, not trail: the
--     table cuts long CIP titles (114 of 311 labels are wider than the 222 px cell), and a trailing mark was cut first,
--     so the two levels of one major looked the same (sweep). major_rank_in_job orders the majors with
--     2024 NYC graduates by count (null for the rest), so the Summary shows ranks 1-4 and "+ N more on Details".
{{ config(alias='job_major_link') }}

{% call mart_numeric_as_double() %}
with awards as (
    select
        a.cip_code,
        a.award_level,
        sum(a.awards_total)                         as awards_2024_nyc,
        sum(a.awards_total) filter (where c.is_cuny) as awards_2024_cuny
    from {{ ref('fct_degree_awards') }} as a
    join {{ ref('dim_college') }} as c on c.unitid = a.unitid
    where a.year = 2024 and a.major_number = 1 and a.award_level in (3, 5)
    group by 1, 2
),

leaves as (
    select soc_code, pct_change, annual_openings_avg, quality_flag
    from {{ ref('fct_job_projection') }}
    where edition = '2022-2032' and is_leaf
),

pairs as (
    select
        b.major_award_key,
        b.cip_code,
        b.award_level,
        b.soc_code,
        d.link_status,
        d.link_status = 'linked'                                            as counts_as_supply,
        b.is_all_other,
        b.pass_basis,
        b.attainment_pct,
        b.attainment_inexact,
        b.openings_nyc                                                      as openings_nyc_bridge,
        b.openings_basis,
        b.n_jobs_in_major,
        b.weight_openings is null                                           as weight_openings_missing,
        coalesce(b.weight_openings, 0)                                      as weight_openings,
        b.weight_equal,
        coalesce(aw.awards_2024_nyc, 0)                                     as awards_2024_nyc,
        coalesce(aw.awards_2024_cuny, 0)                                    as awards_2024_cuny,
        coalesce(aw.awards_2024_nyc, 0) * coalesce(b.weight_openings, 0)    as graduates_2024_openings_wt,
        coalesce(aw.awards_2024_nyc, 0) * b.weight_equal                    as graduates_2024_equal_wt,
        coalesce(aw.awards_2024_cuny, 0) * coalesce(b.weight_openings, 0)   as graduates_2024_cuny_openings_wt
    from {{ ref('bridge_major_job') }} as b
    join {{ ref('dim_major_award') }} as d on d.major_award_key = b.major_award_key
    left join awards as aw on aw.cip_code = b.cip_code and aw.award_level = b.award_level
),

jobs as (
    select
        soc_code,
        count(*)                                                                   as job_n_majors,
        count(*) filter (where counts_as_supply)                                   as job_n_majors_linked,
        count(*) filter (where link_status = 'dispersed')                          as job_n_majors_dispersed,
        sum(graduates_2024_openings_wt) filter (where counts_as_supply)            as job_graduates_2024_linked,
        sum(graduates_2024_equal_wt)    filter (where counts_as_supply)            as job_graduates_2024_linked_equal,
        sum(graduates_2024_cuny_openings_wt) filter (where counts_as_supply)       as job_graduates_2024_linked_cuny,
        sum(graduates_2024_openings_wt)                                            as job_graduates_2024_d20_off,
        max(openings_nyc_bridge)                                                   as job_openings_nyc_bridge,
        bool_or(awards_2024_nyc > 0 and award_level = 5)
            and bool_or(awards_2024_nyc > 0 and award_level = 3)                  as job_has_both_levels
    from pairs
    group by soc_code
)

select
    p.major_award_key,
    p.cip_code,
    p.award_level,
    p.soc_code,
    j.soc_title,
    m.major_title,
    m.award_label,
    case when jb.job_has_both_levels and p.award_level = 3 then 'Assoc. · ' else '' end || m.major_title         as major_label,
    case when not p.counts_as_supply then '✦ ' else '' end
        || case when jb.job_has_both_levels and p.award_level = 3 then 'Assoc. · ' else '' end || m.major_title   as major_label_details,
    case when p.awards_2024_nyc > 0
         then row_number() over (partition by p.soc_code, p.awards_2024_nyc > 0
                                 order by p.awards_2024_nyc desc, p.awards_2024_cuny desc, m.major_title, p.award_level desc) end as major_rank_in_job,
    p.link_status,
    p.counts_as_supply,
    p.is_all_other,
    p.pass_basis,
    p.attainment_pct,
    p.attainment_inexact,
    p.openings_nyc_bridge,
    p.openings_basis,
    p.n_jobs_in_major,
    p.weight_openings,
    p.weight_openings_missing,
    p.weight_equal,
    p.awards_2024_nyc,
    p.awards_2024_cuny,
    p.graduates_2024_openings_wt,
    p.graduates_2024_equal_wt,
    p.graduates_2024_cuny_openings_wt,
    -- the job's totals (repeated on every row of the job)
    jb.job_n_majors,
    jb.job_n_majors_linked,
    jb.job_n_majors_dispersed,
    jb.job_graduates_2024_linked,
    jb.job_graduates_2024_linked_equal,
    jb.job_graduates_2024_linked_cuny,
    jb.job_graduates_2024_d20_off,
    jb.job_has_both_levels,
    l.soc_code is not null                                                   as job_has_projection,
    l.annual_openings_avg                                                    as job_openings_nyc,
    l.pct_change                                                             as job_projected_change_2022_2032_pct,
    l.quality_flag                                                           as job_projection_quality_flag,
    case when l.annual_openings_avg > 0 then jb.job_graduates_2024_linked / l.annual_openings_avg end       as job_graduates_per_opening,
    case when l.annual_openings_avg > 0 then jb.job_graduates_2024_linked_equal / l.annual_openings_avg end as job_graduates_per_opening_equal,
    case when l.annual_openings_avg > 0 then jb.job_graduates_2024_d20_off / l.annual_openings_avg end      as job_graduates_per_opening_d20_off,
    'nces_cip'            as source_key,
    'ipeds_completions'   as source_key_awards,
    'nysdol_projections'  as source_key_openings,
    'bls_ep_education'    as source_key_filter,
    'NCES CIP-SOC crosswalk with the D2 degree-level filter (BLS EP 2025 attainment, 15%); IPEDS 2024 provisional first-major awards; NYS DOL 2022-2032 NYC projections (D1 fill where imputed)' as as_of
from pairs as p
join {{ ref('dim_job') }} as j on j.soc_code = p.soc_code
join {{ ref('mart_dim_major') }} as m on m.major_award_key = p.major_award_key
join jobs as jb on jb.soc_code = p.soc_code
left join leaves as l on l.soc_code = p.soc_code
{% endcall %}
