-- mart.job_skill_top: one row per job x domain x rank (docs/mart-plan.md §4b; nb 43 §5; O*NET 31.0).
--   * knowledge (33 elements), skill_essential (10), skill_transferable (25): the top 8 elements per domain by O*NET
--     importance (scale IM, 1-5; suppressed ratings excluded), ties broken by element name; the level rating (LV, 0-7)
--     of the same element beside it where O*NET publishes one.
--   * software: the top 10 products per job from fct_job_software. O*NET lists software without a rating, so the order
--     is hot technology first, then in-demand, then the number of O*NET specialty listings behind the product, then name.
-- Every job with an O*NET profile at the levels a job page lands on (detailed, broad, BLS aggregate: 790 skill
-- profiles, 798 software lists); pages filter through dim_job.
{{ config(alias='job_skill_top') }}

{% call mart_numeric_as_double() %}
with jobs as (
    select soc_code
    from {{ ref('dim_job') }}
    where soc_level in ('detailed', 'broad', 'bls_aggregate')
),

im as (
    select
        s.soc_code,
        s.domain,
        s.element_id,
        s.element_name,
        s.value                                                                                          as importance,
        s.n                                                                                              as importance_n,
        s.std_error                                                                                      as importance_se,
        s.rollup_rule,
        s.onet_release,
        s.source_key,
        row_number() over (partition by s.soc_code, s.domain order by s.value desc, s.element_name)       as rank
    from {{ ref('fct_job_skill') }} as s
    join jobs as j on j.soc_code = s.soc_code
    where s.scale = 'IM' and not coalesce(s.suppress, false)
),

lv as (
    select soc_code, element_id, value as level_value, coalesce(suppress, false) as level_suppressed, coalesce(not_relevant, false) as level_not_relevant
    from {{ ref('fct_job_skill') }}
    where scale = 'LV'
),

skills as (
    select
        im.soc_code,
        im.domain,
        case im.domain
            when 'knowledge' then 'Knowledge'
            when 'skill_essential' then 'Essential skills'
            when 'skill_transferable' then 'Transferable skills'
        end                                     as domain_label,
        case im.domain
            when 'knowledge' then 1
            when 'skill_essential' then 2
            when 'skill_transferable' then 3
        end                                     as domain_sort,
        im.rank,
        im.element_id,
        im.element_name,
        im.importance,
        im.importance_n,
        im.importance_se,
        case when lv.level_suppressed or lv.level_not_relevant then null else lv.level_value end as level_value,
        null::boolean                           as is_hot_technology,
        null::boolean                           as is_in_demand,
        null::text                              as commodity_title,
        null::bigint                            as n_specialties_listing,
        im.rollup_rule,
        im.onet_release,
        im.source_key
    from im
    left join lv on lv.soc_code = im.soc_code and lv.element_id = im.element_id
    where im.rank <= 8
),

software_ranked as (
    select
        w.*,
        row_number() over (
            partition by w.soc_code
            order by w.is_hot_technology desc, w.is_in_demand desc, w.n_specialties_listing desc, w.product
        ) as rank
    from {{ ref('fct_job_software') }} as w
    join jobs as j on j.soc_code = w.soc_code
),

software as (
    select
        soc_code,
        'software'                              as domain,
        'Software'                              as domain_label,
        4                                       as domain_sort,
        rank,
        commodity_id                            as element_id,
        product                                 as element_name,
        null::numeric                           as importance,
        null::numeric                           as importance_n,
        null::numeric                           as importance_se,
        null::numeric                           as level_value,
        is_hot_technology,
        is_in_demand,
        commodity_title,
        n_specialties_listing,
        null::text                              as rollup_rule,
        onet_release,
        source_key
    from software_ranked
    where rank <= 10
)

select
    soc_code, domain, domain_label, domain_sort, rank, element_id, element_name,
    importance, importance_n, importance_se, level_value,
    is_hot_technology, is_in_demand, commodity_title, n_specialties_listing,
    rollup_rule, onet_release, source_key,
    'O*NET ' || onet_release || ' importance (IM) and level (LV) ratings; software and hot technology lists' as as_of
from skills
union all
select
    soc_code, domain, domain_label, domain_sort, rank, element_id, element_name,
    importance, importance_n, importance_se, level_value,
    is_hot_technology, is_in_demand, commodity_title, n_specialties_listing,
    rollup_rule, onet_release, source_key,
    'O*NET ' || onet_release || ' importance (IM) and level (LV) ratings; software and hot technology lists'
from software
{% endcall %}
