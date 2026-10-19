-- mart.job_profile: one row per degree-reachable job (docs/mart-plan.md §4b; explore-plan §3a universe, §3b lists,
-- §3d growth window, §3g growth vs replacement bands and industry churn; D1, D5, D7, D8, D19, D20; nb 40, nb 42, nb 43).
-- Universe = dim_job.is_degree_entry at the levels a job page lands on: the 221 detailed jobs plus the 4 degree-reachable
-- broad / BLS-aggregate codes that are 2022-32 projection leaves in their own right (13-1020 Buyers, 13-2020 Property
-- Appraisers, 25-2052 Special Education Teachers K-elementary, 29-2010 Clinical Laboratory Technologists), so the
-- List 1 universe (186 degree-reachable leaves) sits on this view. 39 detailed jobs have no 2022-32 leaf row and carry
-- null projection columns (has_projection = false).
--   * Openings (2022-32 leaf): growth_share = growth openings / annual openings; bands (§3g) shrinking (< 0),
--     mostly replacement (0 to the all-leaves NYC share computed here over every 2022-32 leaf = 9.7%), mixed (to 25%),
--     growth-led (>= 25%). quality_flag 'imputed' = the D1/D15 fill. Words: "openings from growth" / "openings from
--     people leaving (retirements, career changes)"; the list column is the growth share with the band as its label.
--   * NYC employment 2019 and 2025 = the D8 estimate (QCEW x NY staffing pattern), labeled estimate; the published
--     NY-metro OEWS series beside it. split_2019 = the metro 2019 value was carried from a SOC 2010 / hybrid code
--     (part of the growth is reclassification). clears_floor_1000 = at least 1,000 estimated NYC jobs in both years (§3b).
--   * Pay: NYS DOL NYC entry / median / experienced wage (survey May 2025 aged to 2026 Q1); metro real p25 / p50
--     2019 -> 2025 in 2025 dollars (nb 43), with the 2025 series note (top-coding dropped in 2025).
--   * NYS DOL Employment Prospects rating from the same projections release (staging xlsx), null where the publisher
--     row is defective (prospects_usable = false) or the code is a D1 fill with no published row.
--   * D5 bands for the three junior signals (values and MOEs are in job_entry_signal; never blended).
--   * Industry churn (§3g): sum over sectors of bridge_industry_job.share_of_job x the sector's 2024 QWI separation
--     (new-hire) rate from industry_hiring_trend, over sectors with a readable share and a QWI rate (GOV-OEWS and 92
--     drop, shares renormalized); coverage = the share summed, flagged under 70%. One descriptive sentence on a job
--     page, never a column or ranking: "the industries this job sits in turn over about X% of jobs a year".
--     The sentence reads industry_separation_rate_page: 2024 rates, except sectors with a 2024 series break
--     (industry_hiring_trend.is_series_break = 48-49) take their 2019 rate (D24 C); industry_churn_break_share =
--     the job's share in break sectors, and the transport_break_2024 footnote is on the job page.
--   * Majors: n_majors_linked = linked major x level keys in bridge_major_job (dispersed majors, D20, counted apart);
--     graduates_2024_linked = sum of 2024 first-major awards (levels 3 and 5, all NYC colleges) x weight_openings over
--     linked majors only; graduates_per_opening = that / annual openings (null where no openings).
--   * List ranks (§3b): list1_rank by annual openings over degree-reachable leaves, All Other codes to their own list
--     (other_list_rank); list2_rank by absolute NYC change 2019 -> 2025 over jobs clearing the floor, list2_rank_pct
--     the percent ranking kept as a toggle; in_list_1 / in_list_2 = rank <= 25.
--   * Job page wording keys (docs/page3-build-plan.md §3.2-§3.5; design brief §11.12 v4.1). SQL picks the case and
--     the number, DAX only puts the sentence together, so dbt tests the rule. Display rounding of graduate counts
--     (the mockup's): whole numbers under 1,000, three significant figures from 1,000 (1,145.7 -> 1,150).
--     - per_opening_key / per_opening_n (card 3, r = graduates_per_opening): needs_projection; no_major; zero_graduates
--       (none of its majors had NYC graduates); majors_dispersed (graduates only in dispersed majors); under_1_per_100 (r < 0.01); one_for_every_n (n = round(1/r) >= 2);
--       about_one (n would be 1: r above 2/3 and under 1.5); n_per_opening (r >= 1.5, n = r to 1 decimal). The mockup's
--       cut at r < 0.67 would print "1 for every 1 openings" for r in (2/3, 0.67), hence the cut on n.
--     - majors_split_key / majors_split_n / majors_split_n_cuny (the sentence under the majors): no_major;
--       no_graduates_2024 (none of its majors had NYC graduates; n = its majors); all_dispersed (the graduates are all
--       in dispersed majors); none_counted (linked majors have graduates, but the D2 openings weight gives this job
--       none: no openings to split by); under_one (fewer than 1 after rounding); all_count (the rounded count equals
--       the rounded graduates of its linked majors: majors that lead only here); split (n of them count).
--     - majors_levels_label: the levels with 2024 NYC graduates among its majors (dispersed included, as listed); "&" for
--       both levels so the subtitle fits beside the column labels (240 px with "and", 229 with "&"; sweep).
--   * Chart gaps (D38): nyc_ / metro_ / p50_ / p25_missing_years = the years after 2019 with no figure on a chart line
--     that has a 2019 base, as display text with runs joined ("2022–2023", "2021, 2024"); null when the line is
--     complete or not drawn. The job page writes one gray note per chart from them (the line joins across a gap).
--     - routes_status (the similar-jobs block): listed; none_qualify (High, compared, no route clears 0.75 and 90% pay);
--       no_skill_ratings / no_nyc_wage (High, not compared); not_high (Medium or Low: one line says the block is for
--       High jobs); no_ai_band (Not seen yet or Not rated: the block is hidden).
{{ config(alias='job_profile') }}

{% call mart_numeric_as_double() %}
with jobs as (
    select j.*
    from {{ ref('dim_job') }} as j
    where j.is_degree_entry and j.soc_level in ('detailed', 'broad', 'bls_aggregate')
),

major_groups as (
    select soc_code, replace(soc_title, ' Occupations', '') as major_group_title
    from {{ ref('dim_job') }}
    where soc_level = 'major'
),

leaves as (
    select *
    from {{ ref('fct_job_projection') }}
    where edition = '2022-2032' and is_leaf
),

all_leaves as (
    select sum(growth_openings_avg) / sum(annual_openings_avg) as all_leaves_growth_share
    from leaves
),

nyc_est as (
    select
        soc_code,
        max(employment_est)   filter (where year = 2019) as nyc_employment_2019,
        max(employment_est)   filter (where year = 2025) as nyc_employment_2025,
        max(metro_employment) filter (where year = 2019) as metro_employment_2019,
        max(metro_employment) filter (where year = 2025) as metro_employment_2025,
        max(method)                                       as nyc_estimate_method
    from {{ ref('fct_job_employment_nyc_est') }}
    where area_key = 'nyc'
    group by soc_code
),

metro as (
    select
        soc_code,
        bool_or(quality_flag <> 'published') filter (where year = 2019) as split_2019,
        max(source_codes)        filter (where year = 2019)              as metro_source_codes_2019,
        max(annual_p25_2025usd)  filter (where year = 2019)              as metro_p25_2019_2025usd,
        max(annual_p25_2025usd)  filter (where year = 2025)              as metro_p25_2025,
        max(annual_p50_2025usd)  filter (where year = 2019)              as metro_p50_2019_2025usd,
        max(annual_p50_2025usd)  filter (where year = 2025)              as metro_p50_2025,
        max(employment)          filter (where year = 2025)              as metro_oews_employment_2025,
        max(series_note)         filter (where year = 2025)              as metro_series_note_2025
    from {{ ref('fct_job_employment_wage_annual') }}
    where area_key = 'ny_metro' and occ_level <> 'total' and year in (2019, 2025)
    group by soc_code
),

wage as (
    select
        soc_code, vintage as wage_vintage, survey_reference as wage_survey_reference, wage_reference,
        employment as nyc_wage_table_employment, entry_wage, median_wage, experienced_wage,
        entry_wage_at_floor, median_at_floor
    from {{ ref('fct_job_wage_nyc') }}
    where area_key = 'nyc'
),

prospects as (
    select
        soc_code,
        max(employment_prospects) filter (where prospects_usable) as employment_prospects,
        bool_or(prospects_usable)                                 as prospects_usable
    from {{ source('staging', 'stg_nysdol__projections_xlsx') }}
    where edition = '2022-2032'
    group by soc_code
),

signals as (
    select
        soc_code,
        max(band) filter (where measure = 'bls_experience')                       as bls_experience_band,
        max(band) filter (where measure = 'acs_young_share' and not suppressed)   as acs_young_share_band,
        bool_or(suppressed) filter (where measure = 'acs_young_share')            as acs_young_share_suppressed,
        max(band) filter (where measure = 'onet_newcomer' and not suppressed)     as onet_newcomer_band
    from {{ ref('fct_job_entry_signal') }}
    group by soc_code
),

hiring as (
    select industry_key, year, separation_rate, new_hire_rate, is_series_break
    from {{ ref('mart_industry_hiring_trend') }}
    where year in (2019, 2024)
),

-- The rate the page sentence uses: each sector's 2024 rate, except a sector whose 2024 series is broken
-- (48-49, the 2024 Q1 employer reclassification) which takes its 2019 rate (D24 C).
sector_page_rate as (
    select
        h24.industry_key,
        h24.is_series_break,
        case when h24.is_series_break then h19.separation_rate else h24.separation_rate end as separation_rate,
        case when h24.is_series_break then h19.new_hire_rate   else h24.new_hire_rate   end as new_hire_rate
    from hiring as h24
    left join hiring as h19 on h19.industry_key = h24.industry_key and h19.year = 2019
    where h24.year = 2024
),

churn as (
    select
        b.soc_code,
        sum(b.share_of_job * h24.separation_rate) / nullif(sum(b.share_of_job) filter (where h24.separation_rate is not null), 0) as industry_separation_rate_2024,
        sum(b.share_of_job) filter (where h24.separation_rate is not null)                                                       as industry_churn_coverage,
        sum(b.share_of_job * h24.new_hire_rate)   / nullif(sum(b.share_of_job) filter (where h24.new_hire_rate is not null), 0)   as industry_new_hire_rate_2024,
        sum(b.share_of_job) filter (where h24.new_hire_rate is not null)                                                         as industry_hire_coverage,
        sum(b.share_of_job * h19.separation_rate) / nullif(sum(b.share_of_job) filter (where h19.separation_rate is not null), 0) as industry_separation_rate_2019,
        sum(b.share_of_job * h19.new_hire_rate)   / nullif(sum(b.share_of_job) filter (where h19.new_hire_rate is not null), 0)   as industry_new_hire_rate_2019,
        sum(b.share_of_job * pr.separation_rate)  / nullif(sum(b.share_of_job) filter (where pr.separation_rate is not null), 0)  as industry_separation_rate_page,
        sum(b.share_of_job * pr.new_hire_rate)    / nullif(sum(b.share_of_job) filter (where pr.new_hire_rate is not null), 0)    as industry_new_hire_rate_page,
        coalesce(sum(b.share_of_job) filter (where pr.is_series_break), 0) / nullif(sum(b.share_of_job), 0)                    as industry_churn_break_share,
        sum(b.share_of_job)                                                                                                      as share_of_job_readable,
        count(*)                                                                                                                 as n_sectors_readable
    from {{ ref('bridge_industry_job') }} as b
    left join hiring as h24 on h24.industry_key = b.industry_key and h24.year = 2024
    left join hiring as h19 on h19.industry_key = b.industry_key and h19.year = 2019
    left join sector_page_rate as pr on pr.industry_key = b.industry_key
    where b.share_of_job is not null
    group by b.soc_code
),

awards_2024 as (
    select cip_code, award_level, sum(awards_total) as awards
    from {{ ref('fct_degree_awards') }}
    where year = 2024 and major_number = 1 and award_level in (3, 5)
    group by 1, 2
),

supply as (
    select
        b.soc_code,
        count(distinct b.major_award_key) filter (where d.link_status = 'linked')                            as n_majors_linked,
        count(distinct b.cip_code)        filter (where d.link_status = 'linked')                            as n_cip_linked,
        count(distinct b.major_award_key) filter (where d.link_status = 'dispersed')                         as n_majors_dispersed,
        sum(coalesce(a.awards, 0) * coalesce(b.weight_openings, 0)) filter (where d.link_status = 'linked') as graduates_2024_linked,
        sum(coalesce(a.awards, 0) * coalesce(b.weight_equal, 0))    filter (where d.link_status = 'linked') as graduates_2024_linked_equal
    from {{ ref('bridge_major_job') }} as b
    join {{ ref('dim_major_award') }} as d on d.major_award_key = b.major_award_key
    left join awards_2024 as a on a.cip_code = b.cip_code and a.award_level = b.award_level
    group by b.soc_code
),

base as (
    select
        j.soc_code,
        j.soc_title,
        coalesce(st.short_title, j.soc_title)                               as soc_short_title,
        j.soc_level,
        j.is_all_other,
        coalesce(j.major_code, j.soc_code)                                  as major_code,
        mg.major_group_title,
        j.entry_education,
        j.entry_education_rank,
        j.entry_experience,
        j.entry_experience_rank,
        j.entry_training,
        j.job_zone,
        j.ai_observed_exposure,
        j.ai_band,
        j.in_tech, j.in_health, j.in_business, j.in_education,
        -- projections (2022-32 leaf)
        l.soc_code is not null                                              as has_projection,
        l.base_employment,
        l.projected_employment,
        l.employment_change,
        l.pct_change / 100.0                                                as pct_change_2022_2032,  -- NYS DOL publishes percent; a fraction like every other change column (design brief §10.5 item 1)
        l.annual_openings_avg,
        l.growth_openings_avg,
        l.separation_openings_avg,
        l.growth_openings_avg / nullif(l.annual_openings_avg, 0)            as growth_share,
        al.all_leaves_growth_share,
        l.quality_flag                                                      as projection_quality_flag,
        l.quality_flag = 'imputed'                                          as is_imputed,
        l.fill_group,
        -- NYC estimate and metro
        e.nyc_employment_2019,
        e.nyc_employment_2025,
        e.nyc_employment_2025 - e.nyc_employment_2019                       as nyc_change_2019_2025,
        case when e.nyc_employment_2019 > 0
             then e.nyc_employment_2025 / e.nyc_employment_2019 - 1 end     as nyc_pct_change_2019_2025,
        e.nyc_estimate_method,
        e.metro_employment_2019,
        e.metro_employment_2025,
        case when e.metro_employment_2019 > 0
             then e.metro_employment_2025 / e.metro_employment_2019 - 1 end as metro_pct_change_2019_2025,
        coalesce(m.split_2019, false)                                       as split_2019,
        case when m.split_2019
             then 'Part of the 2019 to 2025 growth is reclassification: the 2019 count is carried from SOC 2010 / hybrid code(s) '
                  || m.metro_source_codes_2019 end                          as growth_note,
        e.nyc_employment_2019 >= 1000 and e.nyc_employment_2025 >= 1000    as clears_floor_1000,
        -- pay
        w.wage_vintage, w.wage_survey_reference, w.wage_reference,
        w.nyc_wage_table_employment,
        w.entry_wage, w.median_wage, w.experienced_wage,
        w.entry_wage_at_floor, w.median_at_floor,
        case when w.median_wage > 0 then w.entry_wage / w.median_wage end   as entry_to_median_ratio,
        m.metro_p25_2019_2025usd,
        m.metro_p25_2025,
        m.metro_p50_2019_2025usd,
        m.metro_p50_2025,
        case when m.metro_p25_2019_2025usd > 0
             then m.metro_p25_2025 / m.metro_p25_2019_2025usd - 1 end       as metro_real_p25_change_2019_2025,
        case when m.metro_p50_2019_2025usd > 0
             then m.metro_p50_2025 / m.metro_p50_2019_2025usd - 1 end       as metro_real_p50_change_2019_2025,
        m.metro_oews_employment_2025,
        m.metro_series_note_2025,
        -- prospects
        p.employment_prospects,
        coalesce(p.prospects_usable, false)                                 as prospects_usable,
        -- D5 bands
        s.bls_experience_band,
        s.acs_young_share_band,
        coalesce(s.acs_young_share_suppressed, s.soc_code is null or s.acs_young_share_band is null) as acs_young_share_suppressed,
        s.onet_newcomer_band,
        -- industry churn
        c.industry_separation_rate_2024,
        c.industry_new_hire_rate_2024,
        c.industry_separation_rate_2019,
        c.industry_new_hire_rate_2019,
        c.industry_separation_rate_page,
        c.industry_new_hire_rate_page,
        c.industry_churn_break_share,
        c.industry_churn_coverage,
        c.industry_hire_coverage,
        c.share_of_job_readable,
        c.n_sectors_readable,
        -- majors
        coalesce(sp.n_majors_linked, 0)                                     as n_majors_linked,
        coalesce(sp.n_cip_linked, 0)                                        as n_cip_linked,
        coalesce(sp.n_majors_dispersed, 0)                                  as n_majors_dispersed,
        sp.graduates_2024_linked,
        sp.graduates_2024_linked_equal,
        case when l.annual_openings_avg > 0
             then sp.graduates_2024_linked / l.annual_openings_avg end       as graduates_per_opening,
        case when l.annual_openings_avg > 0
             then sp.graduates_2024_linked_equal / l.annual_openings_avg end as graduates_per_opening_equal
    from jobs as j
    left join {{ ref('ref_job_short_title') }} as st on st.soc_code = j.soc_code
    left join major_groups as mg on mg.soc_code = j.major_code
    left join leaves as l on l.soc_code = j.soc_code
    cross join all_leaves as al
    left join nyc_est as e on e.soc_code = j.soc_code
    left join metro as m on m.soc_code = j.soc_code
    left join wage as w on w.soc_code = j.soc_code
    left join prospects as p on p.soc_code = j.soc_code
    left join signals as s on s.soc_code = j.soc_code
    left join churn as c on c.soc_code = j.soc_code
    left join supply as sp on sp.soc_code = j.soc_code
),

majors as (
    select
        soc_code,
        count(*)                                                        as n_major_rows,
        coalesce(sum(awards_2024_nyc), 0)                               as awards_2024_all_majors,
        coalesce(sum(awards_2024_nyc) filter (where counts_as_supply), 0) as awards_2024_linked_majors,
        coalesce(sum(awards_2024_cuny) filter (where counts_as_supply), 0) as awards_2024_linked_majors_cuny,
        max(job_graduates_2024_linked)                                  as graduates_counted,
        max(job_graduates_2024_linked_cuny)                             as graduates_counted_cuny,
        bool_or(awards_2024_nyc > 0 and award_level = 5)                as has_bachelor_graduates,
        bool_or(awards_2024_nyc > 0 and award_level = 3)                as has_associate_graduates
    from {{ ref('mart_job_major_link') }}
    group by soc_code
),

routes as (
    select origin_soc_code as soc_code, max(n_routes_listed) as n_routes_listed
    from {{ ref('mart_job_escape_route') }}
    group by origin_soc_code
),

rated as (
    select soc_code
    from {{ ref('fct_job_skill') }}
    where scale = 'IM'
    group by soc_code
),

ranked as (
    select
        b.*,
        case
            when b.growth_share is null then null
            when b.growth_share < 0 then 'shrinking'
            when b.growth_share < b.all_leaves_growth_share then 'mostly replacement'
            when b.growth_share < 0.25 then 'mixed'
            else 'growth-led'
        end as growth_share_band,
        case
            when b.growth_share is null then null
            when b.growth_share < 0 then 1
            when b.growth_share < b.all_leaves_growth_share then 2
            when b.growth_share < 0.25 then 3
            else 4
        end as growth_share_band_rank,
        case when b.has_projection and not b.is_all_other
             then row_number() over (partition by (b.has_projection and not b.is_all_other) order by b.annual_openings_avg desc, b.soc_code) end as list1_rank,
        case when b.has_projection and b.is_all_other
             then row_number() over (partition by (b.has_projection and b.is_all_other) order by b.annual_openings_avg desc, b.soc_code) end as other_list_rank,
        case when b.clears_floor_1000 and not b.is_all_other
             then row_number() over (partition by (b.clears_floor_1000 and not b.is_all_other) order by b.nyc_change_2019_2025 desc, b.soc_code) end as list2_rank,
        case when b.clears_floor_1000 and not b.is_all_other
             then row_number() over (partition by (b.clears_floor_1000 and not b.is_all_other) order by b.nyc_pct_change_2019_2025 desc, b.soc_code) end as list2_rank_pct
    from base as b
),

final as (
select
    r.*,
    coalesce(r.list1_rank <= 25, false)                                     as in_list_1,
    coalesce(r.list2_rank <= 25, false)                                     as in_list_2,
    r.industry_churn_coverage < 0.7                                         as industry_churn_low_coverage,
    'openings_from_growth_vs_people_leaving'                                as wording_key,
    'industries_turn_over_pct_a_year'                                       as churn_wording_key,
    'nysdol_projections'                                                    as source_key,
    'bls_oews_research'                                                     as source_key_nyc_estimate,
    'bls_oews_metro'                                                        as source_key_metro,
    'nysdol_oews_regions'                                                   as source_key_wage,
    'nysdol_projections_xlsx'                                               as source_key_prospects,
    'census_qwi'                                                            as source_key_churn,
    'ipeds_completions'                                                     as source_key_awards,
    'NYS DOL 2022-2032 NYC projections (D1 fill where imputed); NYC jobs 2019 and 2025 = QCEW x OEWS research staffing pattern estimate (D8); OEWS NY metro May 2019 and May 2025 (2025 dollars); NYS DOL NYC wages survey May 2025 aged to 2026 Q1; Census QWI 2024 (2019 beside); IPEDS 2024 provisional first-major awards; BLS EP 2025 entry requirements' as as_of
from ranked as r
),

-- display rounding of a graduate count (see header): whole numbers under 1,000, three significant figures from 1,000
display as (
    select
        f.soc_code,
        f.has_projection,
        f.n_majors_linked,
        f.graduates_2024_linked,
        f.graduates_per_opening,
        f.ai_band,
        f.median_wage,
        mj.n_major_rows,
        mj.awards_2024_all_majors,
        mj.awards_2024_linked_majors,
        mj.has_bachelor_graduates,
        mj.has_associate_graduates,
        case when mj.graduates_counted >= 1000
             then round(mj.graduates_counted::numeric, 2 - floor(log(mj.graduates_counted::numeric))::int)
             else round(mj.graduates_counted::numeric) end                                  as grads_counted_disp,
        case when mj.graduates_counted_cuny >= 1000
             then round(mj.graduates_counted_cuny::numeric, 2 - floor(log(mj.graduates_counted_cuny::numeric))::int)
             else round(mj.graduates_counted_cuny::numeric) end                             as grads_counted_cuny_disp,
        case when mj.awards_2024_linked_majors >= 1000
             then round(mj.awards_2024_linked_majors::numeric, 2 - floor(log(mj.awards_2024_linked_majors::numeric))::int)
             else round(mj.awards_2024_linked_majors::numeric) end                          as awards_linked_disp,
        coalesce(mj.graduates_counted, 0)                                                   as graduates_counted,
        coalesce(rt.n_routes_listed, 0)                                                     as n_routes_listed,
        rd.soc_code is not null                                                             as has_skill_ratings
    from final as f
    left join majors as mj on mj.soc_code = f.soc_code
    left join routes as rt on rt.soc_code = f.soc_code
    left join rated as rd on rd.soc_code = f.soc_code
),

keys as (
    select
        d.soc_code,
        case
            when not d.has_projection then 'needs_projection'
            when d.n_major_rows is null then 'no_major'
            when d.awards_2024_all_majors = 0 then 'zero_graduates'
            when d.awards_2024_linked_majors = 0 then 'majors_dispersed'
            when coalesce(d.graduates_2024_linked, 0) = 0 then 'zero_graduates'
            when d.graduates_per_opening < 0.01 then 'under_1_per_100'
            when round(1 / d.graduates_per_opening::numeric) >= 2 then 'one_for_every_n'
            when d.graduates_per_opening < 1.5 then 'about_one'
            else 'n_per_opening'
        end                                                                                 as per_opening_key,
        case
            when not d.has_projection or d.n_major_rows is null or d.awards_2024_all_majors = 0
                 or d.awards_2024_linked_majors = 0 or coalesce(d.graduates_2024_linked, 0) = 0
                 or d.graduates_per_opening < 0.01 then null
            when round(1 / d.graduates_per_opening::numeric) >= 2 then round(1 / d.graduates_per_opening::numeric)
            when d.graduates_per_opening < 1.5 then 1
            else round(d.graduates_per_opening::numeric, 1)
        end                                                                                 as per_opening_n,
        case
            when d.n_major_rows is null then 'no_major'
            when d.awards_2024_all_majors = 0 then 'no_graduates_2024'
            when d.awards_2024_linked_majors = 0 then 'all_dispersed'
            when d.graduates_counted = 0 then 'none_counted'
            when d.grads_counted_disp = 0 then 'under_one'
            when d.grads_counted_disp = d.awards_linked_disp then 'all_count'
            else 'split'
        end                                                                                 as majors_split_key,
        case
            when d.n_major_rows is null then null
            when d.awards_2024_all_majors = 0 then d.n_major_rows
            when d.awards_2024_linked_majors = 0 or d.graduates_counted = 0 or d.grads_counted_disp = 0 then null
            else d.grads_counted_disp
        end                                                                                 as majors_split_n,
        case
            when d.n_major_rows is null or d.awards_2024_all_majors = 0 or d.awards_2024_linked_majors = 0
                 or d.graduates_counted = 0 or d.grads_counted_disp = 0 then null
            else d.grads_counted_cuny_disp
        end                                                                                 as majors_split_n_cuny,
        case
            when d.has_bachelor_graduates and d.has_associate_graduates then 'Bachelor''s & associate graduates, 2024'
            when d.has_bachelor_graduates then 'Bachelor''s graduates, 2024'
            when d.has_associate_graduates then 'Associate graduates, 2024'
        end                                                                                 as majors_levels_label,
        d.n_routes_listed,
        case
            when d.ai_band = 'High' and d.n_routes_listed > 0 then 'listed'
            when d.ai_band = 'High' and not d.has_skill_ratings then 'no_skill_ratings'
            when d.ai_band = 'High' and d.median_wage is null then 'no_nyc_wage'
            when d.ai_band = 'High' then 'none_qualify'
            when d.ai_band in ('Medium', 'Low') then 'not_high'
            else 'no_ai_band'
        end                                                                                 as routes_status
    from display as d
),

-- D38: years with no figure on each chart line that has a 2019 base, collapsed into runs
trend_lines as (
    select soc_code, 'nyc' as line, year, pct_change_vs_2019 as v from {{ ref('mart_job_employment_trend') }} where area_key = 'nyc'
    union all
    select soc_code, 'metro', year, pct_change_vs_2019 from {{ ref('mart_job_employment_trend') }} where area_key = 'ny_metro'
    union all
    select soc_code, 'p50', year, annual_p50_2025usd from {{ ref('mart_job_employment_trend') }} where area_key = 'ny_metro'
    union all
    select soc_code, 'p25', year, annual_p25_2025usd from {{ ref('mart_job_employment_trend') }} where area_key = 'ny_metro'
),

trend_years as (
    select generate_series(min(year), max(year)) as year from {{ ref('mart_job_employment_trend') }}
),

based_lines as (
    select distinct soc_code, line
    from trend_lines
    where year = (select min(year) from trend_years) and v is not null
),

missing_years as (
    select b.soc_code, b.line, y.year
    from based_lines as b
    cross join trend_years as y
    left join trend_lines as t on t.soc_code = b.soc_code and t.line = b.line and t.year = y.year and t.v is not null
    where t.soc_code is null
),

missing_runs as (
    select soc_code, line, min(year) as y0, max(year) as y1
    from (select *, year - row_number() over (partition by soc_code, line order by year) as run from missing_years) as m
    group by soc_code, line, run
),

gaps as (
    select
        soc_code,
        string_agg(case when y0 = y1 then y0::text else y0 || '–' || y1 end, ', ' order by y0) filter (where line = 'nyc')   as nyc_missing_years,
        string_agg(case when y0 = y1 then y0::text else y0 || '–' || y1 end, ', ' order by y0) filter (where line = 'metro') as metro_missing_years,
        string_agg(case when y0 = y1 then y0::text else y0 || '–' || y1 end, ', ' order by y0) filter (where line = 'p50')   as p50_missing_years,
        string_agg(case when y0 = y1 then y0::text else y0 || '–' || y1 end, ', ' order by y0) filter (where line = 'p25')   as p25_missing_years
    from missing_runs
    group by soc_code
)

select
    f.*,
    k.per_opening_key,
    k.per_opening_n,
    k.majors_split_key,
    k.majors_split_n,
    k.majors_split_n_cuny,
    k.majors_levels_label,
    k.n_routes_listed,
    k.routes_status,
    g.nyc_missing_years,
    g.metro_missing_years,
    g.p50_missing_years,
    g.p25_missing_years,
    -- BLS relative AI exposure tier (2025-35, published 2026-08-27): the headline AI label (D50 item 1); ai_band (D7) stays the second layer
    bai.bls_ai_tier,
    bai.bls_ai_tier_rank
from final as f
join keys as k on k.soc_code = f.soc_code
left join gaps as g on g.soc_code = f.soc_code
left join {{ ref('ref_bls_ai_exposure') }} as bai on bai.soc_code = f.soc_code
{% endcall %}