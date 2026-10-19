-- mart.job_escape_route: one row per origin job x route rank (docs/mart-plan.md §4b, docs/explore-plan.md §3i,
-- D22 as amended). "Jobs that use similar knowledge and skills, with lower AI exposure today and
-- similar pay", never "safe job".
--   * Origins = degree-reachable detailed jobs in the High band (D7, observed exposure >= 0.30) with an O*NET
--     profile and a NYC median wage (30; Statistical Assistants 43-9111 has no NYC wage and drops).
--   * Destinations = degree-reachable detailed jobs, not All Other, observed exposure < 0.10, a profile, a NYC
--     median wage and >= 100 projected annual openings on the 2022-32 leaf row (51).
--   * r = Pearson correlation of the two jobs' 68 O*NET importance ratings (fct_job_skill, scale 'IM';
--     33 knowledge, 10 essential skills, 25 transferable skills); r_knowledge over the 33, r_skills over the 35.
--   * Comparable pay = destination NYC median >= 90% of the origin's (wage_ratio >= 0.90). Among destinations
--     that pass, the top three by r are listed, and only at r >= 0.75: close = r >= 0.82, possible = 0.75 to
--     0.82. An origin with no route at 0.75 keeps one row (route_rank 0, closeness 'none') so all 30 are visible.
-- The self-join is restricted to origin rows x destination rows first (30 x 51 pairs x 68 elements).
-- Job page additions (docs/page3-build-plan.md §3.4, §4 items 6 and 17; D31): the destination's display title, its
-- job_label (the drill-through field), description and NYC starting pay for the route's hover card, and pay_words:
-- "pays 3.4 times as much" at 2x and above (ratio rounded to 2 decimals), "pays about the same" within +-0.5%, else
-- "pays 25% more" / "pays 9% less" (whole percent, half away from zero). The per-job status of the block (listed,
-- none qualify, not compared, not High) is job_profile.routes_status, because this view has rows for High jobs only.
{{ config(alias='job_escape_route') }}

{% call mart_numeric_as_double() %}
with wage as (
    select soc_code, median_wage, entry_wage
    from {{ ref('fct_job_wage_nyc') }}
    where area_key = 'nyc' and median_wage is not null
),

profile as (
    select soc_code, count(*) as n_elements
    from {{ ref('fct_job_skill') }}
    where scale = 'IM'
    group by soc_code
),

projection as (
    select soc_code, annual_openings_avg
    from {{ ref('fct_job_projection') }}
    where edition = '2022-2032' and is_leaf
),

origins as (
    select j.soc_code, j.ai_observed_exposure, w.median_wage, pr.annual_openings_avg
    from {{ ref('dim_job') }} as j
    join wage as w on w.soc_code = j.soc_code
    join profile as p on p.soc_code = j.soc_code
    left join projection as pr on pr.soc_code = j.soc_code
    where j.soc_level = 'detailed' and j.is_degree_entry and j.ai_band = 'High'
),

destinations as (
    select j.soc_code, j.ai_observed_exposure, j.ai_band, w.median_wage, w.entry_wage, pr.annual_openings_avg
    from {{ ref('dim_job') }} as j
    join wage as w on w.soc_code = j.soc_code
    join profile as p on p.soc_code = j.soc_code
    join projection as pr on pr.soc_code = j.soc_code
    where j.soc_level = 'detailed' and j.is_degree_entry and not j.is_all_other
        and j.ai_observed_exposure < 0.10 and pr.annual_openings_avg >= 100
),

pairs as (
    select
        o.soc_code as origin_soc_code,
        d.soc_code as destination_soc_code,
        corr(a.value, b.value) as r,
        corr(a.value, b.value) filter (where a.domain = 'knowledge') as r_knowledge,
        corr(a.value, b.value) filter (where a.domain <> 'knowledge') as r_skills,
        count(*) as n_elements,
        d.median_wage / o.median_wage as wage_ratio
    from origins as o
    join destinations as d on d.soc_code <> o.soc_code
    join {{ ref('fct_job_skill') }} as a on a.soc_code = o.soc_code and a.scale = 'IM'
    join {{ ref('fct_job_skill') }} as b on b.soc_code = d.soc_code and b.scale = 'IM' and b.element_id = a.element_id
    group by o.soc_code, d.soc_code, d.median_wage, o.median_wage
),

qualifying as (
    select
        *,
        row_number() over (partition by origin_soc_code order by r desc, destination_soc_code) as route_rank
    from pairs
    where wage_ratio >= 0.90 and r >= 0.75
),

routes as (
    select origin_soc_code, destination_soc_code, route_rank, r, r_knowledge, r_skills, n_elements, wage_ratio
    from qualifying
    where route_rank <= 3
    union all
    select o.soc_code, null, 0, null, null, null, null, null
    from origins as o
    where not exists (select 1 from qualifying as q where q.origin_soc_code = o.soc_code)
),

listed as (
    select origin_soc_code, count(*) as n_routes_listed
    from qualifying
    where route_rank <= 3
    group by origin_soc_code
)

select
    r.origin_soc_code,
    r.route_rank,
    r.destination_soc_code,
    dj.soc_short_title                                      as destination_title,
    dj.job_label                                            as destination_label,
    dj.job_description                                      as destination_description,
    dj.description_source                                   as destination_description_source,
    r.r,
    r.r_knowledge,
    r.r_skills,
    case
        when r.r >= 0.82 then 'close'
        when r.r >= 0.75 then 'possible'
        else 'none'
    end as closeness,
    case
        when r.r >= 0.82 then 'route_close'
        when r.r >= 0.75 then 'route_possible'
        else 'no_route_listed'
    end as wording_key,
    r.n_elements,
    coalesce(l.n_routes_listed, 0) as n_routes_listed,
    o.ai_observed_exposure as origin_exposure,
    o.median_wage as origin_median_wage,
    o.annual_openings_avg as origin_openings,
    d.ai_observed_exposure as destination_exposure,
    d.ai_band as destination_band,
    d.median_wage as destination_median_wage,
    r.wage_ratio,
    case
        when r.wage_ratio is null then null
        when round(r.wage_ratio::numeric, 2) >= 2 then 'pays ' || to_char(round(r.wage_ratio::numeric, 1), 'FM990.0') || ' times as much'
        when abs(r.wage_ratio::numeric - 1) < 0.005 then 'pays about the same'
        when r.wage_ratio > 1 then 'pays ' || round((r.wage_ratio::numeric - 1) * 100)::int || '% more'
        else 'pays ' || round((1 - r.wage_ratio::numeric) * 100)::int || '% less'
    end as pay_words,
    d.entry_wage as destination_entry_wage,
    d.annual_openings_avg as destination_openings,
    'onet' as source_key,
    'anthropic_ai_exposure' as source_key_exposure,
    'nysdol_oews_regions' as source_key_wage,
    'nysdol_projections' as source_key_openings,
    'O*NET 31.0 importance ratings; Anthropic observed exposure (Mar 2026); NYS DOL NYC median wage (vintage 2026-10-12); NYS DOL 2022-2032 projections' as as_of
from routes as r
join origins as o on o.soc_code = r.origin_soc_code
left join destinations as d on d.soc_code = r.destination_soc_code
left join {{ ref('mart_dim_job') }} as dj on dj.soc_code = r.destination_soc_code
left join listed as l on l.origin_soc_code = r.origin_soc_code
{% endcall %}
