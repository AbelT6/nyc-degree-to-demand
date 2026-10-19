-- mart.dim_job: the job dimension Power BI imports (docs/mart-plan.md §4a, D23).
-- One row per job code a mart fact can land on: every detailed, broad and BLS-aggregate row of
-- core.dim_job (projection leaves include broad codes such as 29-2010 Clinical Laboratory Technologists
-- and the 5 BLS aggregates), plus the major-group rows, which exist so group-grain facts (postings,
-- group exposure) relate to the same dimension; measures on those facts return BLANK when a job is
-- filtered (Microsoft "relate higher grain facts"). Page-level flags (List 1 / List 2 rank) live on job_profile.
-- Job page additions (docs/page3-build-plan.md §3.7, §4 item 4; D29, D32), filled only on the 225 job-page rows (the
-- job_profile universe: degree-reachable detailed, broad and BLS-aggregate codes), null elsewhere:
--   * job_label = display title + " °" when the 2022-32 projection is imputed (D1) + "◆" when the 2019 metro count is
--     carried from split codes, e.g. "Software Developers °◆". The drill-through field and both Jobs lists' column:
--     short titles repeat across levels (17-2130 / 17-2131), so the label exists only where it is unique. The two
--     flags are read from core here (job_profile reads this view's neighbours, so referencing it would loop) and
--     tests/mart_dim_job_page_additions.sql ties them to job_profile.is_imputed / split_2019.
--   * job_description = the one line under the job page's title: the hand-checked replacement in
--     ref_job_description_override (profile_part / bls_type), else the BLS OOH profile sentence, else the first
--     sentence of the O*NET 31.0 .00 definition (13 named jobs BLS doesn't profile). The 23 "All other" groups take
--     O*NET's sentence ("All engineers not listed separately."), which says what the row is; only 3 have a BLS
--     profile, and that sentence describes the whole group. description_source = the source key behind the text.
--     verdict shortened (3 jobs, sweep): the source's own first sentence, or O*NET's sentence up to its
--     "such as" list, where the full text ran past the header's 2 lines or the route card's 4.
{{ config(alias='dim_job') }}

{% call mart_numeric_as_double() %}
with mg as (
    select soc_code, replace(soc_title, ' Occupations', '') as major_group_title
    from {{ ref('dim_job') }}
    where soc_level = 'major'
),

page_jobs as (
    select soc_code, is_all_other
    from {{ ref('dim_job') }}
    where is_degree_entry and soc_level in ('detailed', 'broad', 'bls_aggregate')
),

imputed as (
    select soc_code, quality_flag = 'imputed' as is_imputed
    from {{ ref('fct_job_projection') }}
    where edition = '2022-2032' and is_leaf
),

split_2019 as (
    select soc_code, bool_or(quality_flag <> 'published') as split_2019
    from {{ ref('fct_job_employment_wage_annual') }}
    where area_key = 'ny_metro' and occ_level <> 'total' and year = 2019
    group by soc_code
),

onet_sentence as (
    -- first sentence: up to the first full stop after a lower-case letter, digit or ')' that precedes a capital
    -- (the rule of src/job_text.py first_sentence(); equal on all 867 .00 definitions, checked)
    select
        soc_code,
        coalesce(substring(description from '^(.+?[a-z0-9)]\.)(?:\s+[A-Z]|$)'), description) as description
    from {{ source('staging', 'stg_onet__occupation') }}
    where onet_soc_code = soc_code || '.00'
),

page as (
    select
        pj.soc_code,
        coalesce(st.short_title, j.soc_title)
            || case when coalesce(i.is_imputed, false) or coalesce(s.split_2019, false) then ' ' else '' end
            || case when coalesce(i.is_imputed, false) then '°' else '' end
            || case when coalesce(s.split_2019, false) then '◆' else '' end                   as job_label,
        case
            when o.verdict = 'shortened' then o.description
            when pj.is_all_other or o.verdict = 'onet' or ooh.soc_code is null then os.description
            when o.verdict in ('profile_part', 'bls_type') then o.description
            else ooh.description
        end                                                                                    as job_description,
        case
            when pj.is_all_other or o.verdict = 'onet' or ooh.soc_code is null then 'onet'
            else 'bls_ooh'
        end                                                                                    as description_source,
        case
            when o.verdict = 'shortened' then 'shortened_to_fit'
            when pj.is_all_other then 'onet_all_other'
            when o.verdict = 'onet' or ooh.soc_code is null then 'onet_first_sentence'
            when o.verdict = 'keep' then 'ooh_shared_profile'
            when o.verdict = 'profile_part' then 'ooh_profile_part'
            when o.verdict = 'bls_type' then 'ooh_type_sentence'
            else 'ooh_own_profile'
        end                                                                                    as description_basis
    from page_jobs as pj
    join {{ ref('dim_job') }} as j on j.soc_code = pj.soc_code
    left join {{ ref('ref_job_short_title') }} as st on st.soc_code = pj.soc_code
    left join imputed as i on i.soc_code = pj.soc_code
    left join split_2019 as s on s.soc_code = pj.soc_code
    left join {{ ref('ref_job_description_override') }} as o on o.soc_code = pj.soc_code
    left join {{ source('staging', 'stg_bls__ooh_description') }} as ooh on ooh.soc_code = pj.soc_code
    left join onet_sentence as os on os.soc_code = pj.soc_code
)

select
    j.soc_code,
    j.soc_title,
    coalesce(st.short_title, j.soc_title) as soc_short_title,
    j.soc_level,
    case
        when j.soc_level = 'major' then 'job group'
        when j.is_degree_entry then 'degree-reachable job'
        else 'other job'
    end as job_kind,
    coalesce(j.major_code, j.soc_code) as major_code,
    coalesce(mg.major_group_title, replace(j.soc_title, ' Occupations', '')) as major_group_title,
    j.is_degree_entry,
    case when j.is_degree_entry then al.award_level end as degree_level_key,
    j.is_all_other,
    j.entry_education,
    j.entry_education_rank,
    j.entry_experience,
    j.entry_experience_rank,
    j.entry_training,
    j.entry_training_rank,
    j.job_zone,
    j.ai_observed_exposure,
    j.ai_band,
    j.ai_beta_gpt4,
    j.in_tech,
    j.in_health,
    j.in_business,
    j.in_education,
    case
        when j.in_tech then 'Tech'
        when j.in_health then 'Healthcare'
        when j.in_business then 'Business'
        when j.in_education then 'Education'
    end as featured_area_first,
    pg.job_label,
    pg.job_description,
    pg.description_source,
    pg.description_basis,
    'anthropic_ai_exposure' as source_key_ai,
    'bls_ep_education' as source_key_entry
from {{ ref('dim_job') }} j
left join mg on mg.soc_code = j.major_code
left join page pg on pg.soc_code = j.soc_code
left join {{ ref('ref_job_short_title') }} st on st.soc_code = j.soc_code
left join {{ ref('dim_award_level') }} al on al.bls_entry_education = j.entry_education and al.in_v1_scope
where j.soc_level in ('detailed', 'broad', 'bls_aggregate', 'major')
{% endcall %}
