-- mart.dim_major: one row per major x award level (core.dim_major_award, D14 / D20 link status), the
-- degree-level slicer's dimension (docs/mart-plan.md §4a). offered_at_cuny and n_cuny_colleges come from
-- CUNY's program inventory (dim_cuny_program, open programs at the same IPEDS level).
-- Major page and "Find your major" (docs/release-plan.md §7b, D52), appended last so the Power BI columns keep their order:
--   * major_label = "Accounting (bachelor's)", the drill-through field; unique (tested). 124 titles repeat at one level
--     under different CIP codes; at most one of each has 2024 graduates, so the one with the most keeps the plain label
--     and the others add their CIP code: "Title (bachelor's, CIP 52.0399)".
--   * level_label = "Associate's" / "Bachelor's" (the finder's level buttons).
--   * The major's linked jobs (bridge_major_job, the same 3,873 rows as job_major_link; read here because job_major_link
--     reads this view): n_degree_jobs / degree_jobs_openings = jobs in the study (the 225: BLS associate's or bachelor's
--     entry, detailed, broad or BLS-aggregate codes) and their 2022-32 openings a year (NYS DOL leaves, D1 fill; a job
--     with no leaf row adds 0); n_outside_jobs / outside_jobs_openings = every other linked job (less schooling or a
--     master's or more). Openings are summed over jobs other majors share, so they describe the jobs, not the major.
--   * kind_key (five kinds, study-frame-brainstorm §4; reproduces 1,139 / 2,008 / 73 / 676 / 754 majors and
--     37,131 / 15,416 / 12,067 / 6,523 / 2,088 degrees in 2024 (D57), tests/mart_dim_major_kinds.sql): a linked major is
--     'degree_jobs' when it has a job in the study and those jobs' openings >= the outside jobs' openings, else
--     'outside_jobs'; 'dispersed', 'transfer' and 'no_link' follow link_status. kind_label is the finder's word;
--     'transfer' has three, by where the major's linked jobs point (link_levels below; D56 Q4).
--   * has_graduates_2024: 2024 first-major awards at NYC colleges > 0 (545 majors), the finder's universe.
{{ config(alias='dim_major') }}

{% call mart_numeric_as_double() %}
with cuny as (
    select cip_code, ipeds_award_level as award_level, count(distinct college) as n_cuny_colleges
    from {{ ref('dim_cuny_program') }}
    where not is_closed and ipeds_award_level is not null
    group by 1, 2
),

study_jobs as (
    select soc_code
    from {{ ref('dim_job') }}
    where is_degree_entry and soc_level in ('detailed', 'broad', 'bls_aggregate')
),

leaves as (
    select soc_code, annual_openings_avg
    from {{ ref('fct_job_projection') }}
    where edition = '2022-2032' and is_leaf
),

links as (
    select
        b.major_award_key,
        count(*) filter (where s.soc_code is not null)                                  as n_degree_jobs,
        coalesce(sum(l.annual_openings_avg) filter (where s.soc_code is not null), 0)   as degree_jobs_openings,
        count(*) filter (where s.soc_code is null)                                      as n_outside_jobs,
        coalesce(sum(l.annual_openings_avg) filter (where s.soc_code is null), 0)       as outside_jobs_openings,
        -- D58: the kind vote counts a group job linked only in part by that share (bridge link_part_share)
        coalesce(sum(l.annual_openings_avg * b.link_part_share) filter (where s.soc_code is not null), 0) as degree_jobs_vote,
        coalesce(sum(l.annual_openings_avg * b.link_part_share) filter (where s.soc_code is null), 0)     as outside_jobs_vote
    from {{ ref('bridge_major_job') }} as b
    left join study_jobs as s on s.soc_code = b.soc_code
    left join leaves as l on l.soc_code = b.soc_code
    group by b.major_award_key
),

-- D56 Q4, revised by D58 (fact-check): a 'transfer' major passes no link at its level; its label says where its
-- linked jobs sit, not what students do (there is no transfer or graduate-school data): every linked job usually
-- starts with more schooling than the degree (BLS typical entry: a bachelor's or more for an associate's major, a
-- master's or more for a bachelor's) -> "Linked jobs need more schooling"; every one with less -> "Linked jobs need
-- less schooling"; some of each, or a job BLS doesn't rate -> "No linked job at this level".
link_levels as (
    select
        f.cip_code,
        f.award_level,
        count(*) filter (where j.entry_education_rank > case f.award_level when 3 then 5 when 5 then 6 end) as n_links_above,
        count(*) filter (where j.entry_education_rank < case f.award_level when 3 then 5 when 5 then 6 end) as n_links_below,
        count(*) filter (where j.entry_education_rank is null) as n_links_unrated
    from {{ ref('audit_major_job_filter') }} as f
    join {{ ref('dim_job') }} as j on j.soc_code = f.soc_code
    group by 1, 2
),

grads as (
    select cip_code, award_level, sum(awards_total) as awards_2024_nyc
    from {{ ref('fct_degree_awards') }}
    where year = 2024 and major_number = 1 and award_level in (3, 5)
    group by 1, 2
),

base as (
    select
        a.major_award_key,
        a.cip_code,
        m.cip_title_clean as major_title,
        m.cip_family,
        m.cip_family_title_clean as family_title,
        a.award_level,
        l.award_label,
        a.link_status,
        case a.link_status
            when 'linked' then 'linked to jobs'
            when 'dispersed' then 'graduates work across many jobs'
            when 'transfer_pathway' then 'transfer pathway'
            else 'no job link in the crosswalk'
        end as link_status_label,
        a.n_links,
        a.n_pass_10 as n_linked_jobs,
        a.openings_nyc_total,
        a.field_fod1p,
        a.field_lift,
        a.field_verdict,
        coalesce(c.n_cuny_colleges, 0) > 0 as offered_at_cuny,
        coalesce(c.n_cuny_colleges, 0) as n_cuny_colleges,
        'nces_cip' as source_key,
        case a.award_level when 3 then 'Associate''s' when 5 then 'Bachelor''s' end as level_label,
        coalesce(g.awards_2024_nyc, 0) > 0 as has_graduates_2024,
        coalesce(k.n_degree_jobs, 0) as n_degree_jobs,
        coalesce(k.degree_jobs_openings, 0) as degree_jobs_openings,
        coalesce(k.n_outside_jobs, 0) as n_outside_jobs,
        coalesce(k.outside_jobs_openings, 0) as outside_jobs_openings,
        row_number() over (partition by m.cip_title_clean, a.award_level
                           order by coalesce(g.awards_2024_nyc, 0) desc, a.cip_code) as title_rank,
        count(*) over (partition by m.cip_title_clean, a.award_level) as n_same_title,
        coalesce(ll.n_links_above, 0) as n_links_above,
        coalesce(ll.n_links_below, 0) as n_links_below,
        coalesce(ll.n_links_unrated, 0) as n_links_unrated,
        k.degree_jobs_vote,
        k.outside_jobs_vote
    from {{ ref('dim_major_award') }} a
    join {{ ref('dim_major') }} m on m.cip_code = a.cip_code
    join {{ ref('dim_award_level') }} l on l.award_level = a.award_level
    left join cuny c on c.cip_code = a.cip_code and c.award_level = a.award_level
    left join links k on k.major_award_key = a.major_award_key
    left join grads g on g.cip_code = a.cip_code and g.award_level = a.award_level
    left join link_levels ll on ll.cip_code = a.cip_code and ll.award_level = a.award_level
),

kinds as (
    select
        b.*,
        case
            when b.link_status = 'linked' and b.n_degree_jobs > 0 and b.degree_jobs_vote >= b.outside_jobs_vote then 'degree_jobs'
            when b.link_status = 'linked' then 'outside_jobs'
            when b.link_status = 'dispersed' then 'dispersed'
            when b.link_status = 'transfer_pathway' then 'transfer'
            else 'no_link'
        end as kind_key
    from base as b
)

select
    major_award_key, cip_code, major_title, cip_family, family_title, award_level, award_label, link_status,
    link_status_label, n_links, n_linked_jobs, openings_nyc_total, field_fod1p, field_lift, field_verdict,
    offered_at_cuny, n_cuny_colleges, source_key,
    major_title || ' (' || lower(level_label)
        || case when title_rank > 1 then ', CIP ' || cip_code else '' end || ')'   as major_label,
    level_label,
    kind_key,
    case kind_key
        when 'degree_jobs'  then 'Leads to degree-level jobs'
        when 'outside_jobs' then 'Leads mostly to jobs outside the study'
        when 'dispersed'    then 'Graduates work across many jobs'
        when 'transfer'     then case
                                     when n_links_below = 0 and n_links_unrated = 0 then 'Linked jobs need more schooling'
                                     when n_links_above = 0 and n_links_unrated = 0 then 'Linked jobs need less schooling'
                                     else 'No linked job at this level'
                                 end
        else 'No job link'
    end as kind_label,
    case kind_key when 'degree_jobs' then 1 when 'outside_jobs' then 2 when 'dispersed' then 3 when 'transfer' then 4 else 5 end as kind_rank,
    has_graduates_2024,
    n_degree_jobs,
    degree_jobs_openings,
    n_outside_jobs,
    outside_jobs_openings
from kinds
{% endcall %}
