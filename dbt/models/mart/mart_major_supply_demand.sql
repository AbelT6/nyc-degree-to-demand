-- mart.major_supply_demand: one row per major x award level (every row of mart.dim_major, 4,650; the 1,860 linked +
-- dispersed majors carry the numbers, transfer-pathway / not-in-crosswalk majors carry awards and nulls so the 2024
-- awards reconcile to the IPEDS total on this view). Implements docs/mart-plan.md §4c, explore-plan §3c (S11 grid,
-- cutoffs fixed before the results), §3i (exposure by major) and D2, D14, D16, D19, D20; nb 42, nb 46.
--   * Awards: 2024 and 2019 first-major awards (major_number = 1), all NYC colleges and CUNY, with the change.
--   * Graduates per opening (§3c (b), linked majors only, D20): sum over the major's bridge jobs of w_r x ratio_j,
--     where ratio_j = the job's 2024 graduates from linked majors / its 2022-32 leaf openings (job_major_link) and
--     w_r = weight_openings renormalized over the major's jobs that have a ratio (the notebook's w_r; jobs with no
--     2022-32 leaf row carry no ratio; ratio_weight_coverage = the weight those jobs hold before renormalizing).
--     Equal weights (D2 range) and D20 off (dispersed majors counted as supply) as sensitivities.
--   * Growth axis (D19): projected_change_2022_2032_pct = sum of w_r x the job's 2022-32 pct_change (percent, as NYS
--     DOL publishes it); actual_change_2019_2025_pct = the same over the D8 NYC estimate, shown beside, never the axis.
--   * S11 box (§3c, D19): many = graduates per opening > 1.0; shrinking = projected change <= 0; crowded = shrinking
--     and many (words: "more competition", never "bad major"); growing · many = "more graduates than openings, even
--     as the job grows"; shrinking · few; growing · few. Sensitivities the plan asks for: ratio cutoffs 0.5 / 1.5 /
--     2.0, growth cutoff = the NYC all-jobs 2022-32 rate (fct_job_projection 00-0000, +12.05%), equal weights,
--     actual growth as the axis, D20 off. Dispersed majors: box null, wording_key 'dispersed_see_destinations'.
--   * AI exposure (§3i, D7): linked majors = weight_openings-weighted mean of dim_job.ai_observed_exposure over the
--     major's scored bridge jobs, exposure_coverage = the weight those jobs hold (flagged under 70%), high_share =
--     the scored weight in the High band, equal weights as sensitivity, the three most exposed jobs; dispersed
--     majors = the ACS destination-weighted group exposure (field_x_soc_major shares, bachelor's 22-34, unsuppressed
--     rows renormalized, x mart.ai_group_exposure), labeled "by where its graduates work", coverage = the readable
--     share. Banded with the four D7 bands (Not seen yet = 0, Low < 0.10, Medium < 0.30, High >= 0.30). Transfer / no-link majors: null.
--   * ACS field earnings (bachelor's-only medians 22-34 and 35-64) and the 35-64 graduate premium where the major
--     maps to a field (dim_major_award.field_fod1p); field_lift / field_verdict (D20) from the dimension.
{{ config(alias='major_supply_demand') }}

{% set box_sql -%}
case
    when ({r}) is null or ({g}) is null then null
    when ({g}) <= ({gc}) and ({r}) > ({rc}) then 'crowded'
    when ({g}) >  ({gc}) and ({r}) > ({rc}) then 'growing_many'
    when ({g}) <= ({gc}) then 'shrinking_few'
    else 'growing_few'
end
{%- endset %}
{#- box codes are ASCII; box_label builds the page text "growing · many" with chr(183) so no SQL literal carries a non-ASCII byte -#}

{% call mart_numeric_as_double() %}
with majors as (
    select
        m.major_award_key, m.cip_code, m.major_title, m.cip_family, m.family_title, m.award_level, m.award_label,
        m.link_status, m.link_status_label, m.n_links, m.n_linked_jobs, m.openings_nyc_total,
        m.field_fod1p, m.field_lift, m.field_verdict, m.offered_at_cuny, m.n_cuny_colleges,
        d.n_all_other_jobs, d.has_openings_weight
    from {{ ref('mart_dim_major') }} as m
    join {{ ref('dim_major_award') }} as d on d.major_award_key = m.major_award_key
),

awards as (
    select
        a.cip_code,
        a.award_level,
        sum(a.awards_total) filter (where a.year = 2024)                as awards_2024_nyc,
        sum(a.awards_total) filter (where a.year = 2024 and c.is_cuny)  as awards_2024_cuny,
        sum(a.awards_total) filter (where a.year = 2019)                as awards_2019_nyc,
        sum(a.awards_total) filter (where a.year = 2019 and c.is_cuny)  as awards_2019_cuny
    from {{ ref('fct_degree_awards') }} as a
    join {{ ref('dim_college') }} as c on c.unitid = a.unitid
    where a.year in (2019, 2024) and a.major_number = 1 and a.award_level in (3, 5)
    group by 1, 2
),

nyc as (
    select
        soc_code,
        max(employment_est) filter (where year = 2019) as e19,
        max(employment_est) filter (where year = 2025) as e25
    from {{ ref('fct_job_employment_nyc_est') }}
    where area_key = 'nyc'
    group by soc_code
),

jobrows as (
    select
        lk.major_award_key,
        lk.soc_code,
        lk.soc_title,
        lk.weight_openings                                  as w,
        lk.weight_equal                                     as we,
        lk.job_graduates_per_opening                        as ratio,
        lk.job_graduates_per_opening_equal                  as ratio_eq,
        lk.job_graduates_per_opening_d20_off                as ratio_off,
        lk.job_projected_change_2022_2032_pct               as pct,
        case when n.e19 > 0 then (n.e25 / n.e19 - 1) * 100 end as actual_pct,
        j.ai_observed_exposure                              as exposure,
        j.ai_band
    from {{ ref('mart_job_major_link') }} as lk
    join {{ ref('dim_job') }} as j on j.soc_code = lk.soc_code
    left join nyc as n on n.soc_code = lk.soc_code
),

agg as (
    select
        major_award_key,
        count(*)                                                                                     as n_jobs,
        count(*) filter (where ratio is not null)                                                    as n_jobs_with_ratio,
        count(*) filter (where ratio is not null and pct <= 0)                                       as n_jobs_shrinking,
        sum(w) filter (where ratio is not null)                                                      as ratio_weight_coverage,
        sum(w * ratio)      filter (where ratio is not null)     / nullif(sum(w)  filter (where ratio is not null), 0)     as gpo,
        sum(we * ratio_eq)  filter (where ratio_eq is not null)  / nullif(sum(we) filter (where ratio_eq is not null), 0)  as gpo_eq,
        sum(w * ratio_off)  filter (where ratio_off is not null) / nullif(sum(w)  filter (where ratio_off is not null), 0) as gpo_off,
        sum(w * pct)        filter (where ratio is not null)     / nullif(sum(w)  filter (where ratio is not null), 0)     as growth,
        sum(we * pct)       filter (where ratio_eq is not null)  / nullif(sum(we) filter (where ratio_eq is not null), 0)  as growth_eq,
        sum(w * actual_pct) filter (where ratio is not null and actual_pct is not null)
            / nullif(sum(w) filter (where ratio is not null and actual_pct is not null), 0)                                as actual,
        sum(w) filter (where ratio is not null and actual_pct is not null)                            as actual_weight_coverage,
        -- exposure (§3i)
        count(*) filter (where exposure is not null)                                                  as n_jobs_scored,
        sum(w * exposure)  filter (where exposure is not null) / nullif(sum(w)  filter (where exposure is not null), 0)  as exposure_bridge,
        sum(w) filter (where exposure is not null)                                                    as exposure_bridge_coverage,
        coalesce(sum(w) filter (where ai_band = 'High'), 0) / nullif(sum(w) filter (where exposure is not null), 0)      as high_share_bridge,
        sum(we * exposure) filter (where exposure is not null) / nullif(sum(we) filter (where exposure is not null), 0)  as exposure_bridge_equal
    from jobrows
    group by major_award_key
),

top_exposed as (
    select
        major_award_key,
        string_agg(soc_title || ' (' || to_char(exposure, 'FM0.00') || ')', '; ' order by exposure desc, w desc, soc_code) as top_exposed_jobs
    from (
        select *, row_number() over (partition by major_award_key order by exposure desc, w desc, soc_code) as rn
        from jobrows
        where exposure is not null
    ) as t
    where rn <= 3
    group by major_award_key
),

top_job as (
    select distinct on (major_award_key)
        major_award_key, soc_code as top_job_soc_code, soc_title as top_job_title, w as top_job_weight
    from jobrows
    order by major_award_key, w desc, soc_code
),

acs_dest as (
    select
        fod1p,
        sum(share_of_field * group_exposure) filter (where group_exposure is not null)
            / nullif(sum(share_of_field) filter (where group_exposure is not null), 0) as exposure_acs,
        max(field_readable_share)                                                     as exposure_acs_coverage,
        count(*)                                                                      as acs_n_groups_readable
    from {{ ref('mart_grad_outcome_destination') }}
    where age_band = '22-34' and degree_level = 'bachelor' and not suppressed
    group by fod1p
),

acs_field as (
    select
        fod1p,
        max(fod_title)                                                                                   as field_title,
        max(median_earnings_2024usd) filter (where age_band = '22-34' and degree_level = 'bachelor')      as acs_median_22_34_bachelor,
        max(moe_median_earnings)     filter (where age_band = '22-34' and degree_level = 'bachelor')      as acs_moe_median_22_34_bachelor,
        max(median_earnings_2024usd) filter (where age_band = '35-64' and degree_level = 'bachelor')      as acs_median_35_64_bachelor,
        max(moe_median_earnings)     filter (where age_band = '35-64' and degree_level = 'bachelor')      as acs_moe_median_35_64_bachelor,
        max(premium_median)          filter (where age_band = '35-64' and degree_level = 'bachelor')      as acs_premium_median_35_64,
        max(premium_verdict)         filter (where age_band = '35-64' and degree_level = 'bachelor')      as acs_premium_verdict_35_64
    from {{ ref('mart_grad_outcome_field') }}
    group by fod1p
),

nyc_avg as (
    select pct_change as nyc_all_jobs_change_2022_2032_pct
    from {{ ref('fct_job_projection') }}
    where edition = '2022-2032' and soc_code = '00-0000'
),

base as (
    select
        m.*,
        coalesce(aw.awards_2024_nyc, 0)  as awards_2024_nyc,
        coalesce(aw.awards_2024_cuny, 0) as awards_2024_cuny,
        coalesce(aw.awards_2019_nyc, 0)  as awards_2019_nyc,
        coalesce(aw.awards_2019_cuny, 0) as awards_2019_cuny,
        case when aw.awards_2019_nyc > 0  then coalesce(aw.awards_2024_nyc, 0)::numeric  / aw.awards_2019_nyc - 1 end  as awards_change_2019_2024_nyc,
        case when aw.awards_2019_cuny > 0 then coalesce(aw.awards_2024_cuny, 0)::numeric / aw.awards_2019_cuny - 1 end as awards_change_2019_2024_cuny,
        m.link_status = 'linked'                                                        as counts_as_supply,
        coalesce(a.n_jobs, 0)                                                           as n_jobs_bridge,
        coalesce(a.n_jobs_with_ratio, 0)                                                as n_jobs_with_ratio,
        a.n_jobs_shrinking,
        case when m.link_status = 'linked' then a.gpo end                               as graduates_per_opening,
        case when m.link_status = 'linked' then a.gpo_eq end                            as graduates_per_opening_equal,
        case when m.link_status in ('linked', 'dispersed') then a.gpo_off end           as graduates_per_opening_d20_off,
        case when m.link_status = 'linked' then a.ratio_weight_coverage end             as ratio_weight_coverage,
        case when m.link_status = 'linked' then a.growth end                            as projected_change_2022_2032_pct,
        case when m.link_status = 'linked' then a.growth_eq end                         as projected_change_2022_2032_pct_equal,
        case when m.link_status = 'linked' then a.actual end                            as actual_change_2019_2025_pct,
        case when m.link_status = 'linked' then a.actual_weight_coverage end            as actual_weight_coverage,
        case when m.link_status in ('linked', 'dispersed') then a.growth end            as projected_change_d20_off_pct,
        na.nyc_all_jobs_change_2022_2032_pct,
        tj.top_job_soc_code, tj.top_job_title, tj.top_job_weight,
        -- exposure
        case m.link_status when 'linked' then a.exposure_bridge when 'dispersed' then ad.exposure_acs end                   as ai_exposure,
        case m.link_status when 'linked' then 'by the jobs it leads to' when 'dispersed' then 'by where its graduates work' end as ai_exposure_basis,
        case m.link_status when 'linked' then a.exposure_bridge_coverage when 'dispersed' then ad.exposure_acs_coverage end as ai_exposure_coverage,
        case when m.link_status = 'linked' then a.high_share_bridge end                 as ai_high_share,
        case when m.link_status = 'linked' then a.exposure_bridge_equal end             as ai_exposure_equal,
        case when m.link_status = 'linked' then a.n_jobs_scored end                     as n_jobs_scored,
        case when m.link_status = 'linked' then te.top_exposed_jobs end                 as top_exposed_jobs,
        a.exposure_bridge                                                               as ai_exposure_bridge_all,
        ad.exposure_acs                                                                 as ai_exposure_acs_all,
        ad.acs_n_groups_readable,
        -- ACS field earnings
        af.field_title,
        af.acs_median_22_34_bachelor, af.acs_moe_median_22_34_bachelor,
        af.acs_median_35_64_bachelor, af.acs_moe_median_35_64_bachelor,
        af.acs_premium_median_35_64, af.acs_premium_verdict_35_64
    from majors as m
    left join awards as aw on aw.cip_code = m.cip_code and aw.award_level = m.award_level
    left join agg as a on a.major_award_key = m.major_award_key
    left join top_exposed as te on te.major_award_key = m.major_award_key
    left join top_job as tj on tj.major_award_key = m.major_award_key
    left join acs_dest as ad on ad.fod1p = m.field_fod1p
    left join acs_field as af on af.fod1p = m.field_fod1p
    cross join nyc_avg as na
),

boxed as (
    select
        b.*,
        case when b.graduates_per_opening is not null then b.graduates_per_opening > 1.0 end          as many_graduates,
        case when b.projected_change_2022_2032_pct is not null then b.projected_change_2022_2032_pct <= 0 end as is_shrinking,
        {{ box_sql.format(r='b.graduates_per_opening', g='b.projected_change_2022_2032_pct', gc='0', rc='1.0') }}   as box,
        {{ box_sql.format(r='b.graduates_per_opening', g='b.projected_change_2022_2032_pct', gc='0', rc='0.5') }}   as box_ratio_0_5,
        {{ box_sql.format(r='b.graduates_per_opening', g='b.projected_change_2022_2032_pct', gc='0', rc='1.5') }}   as box_ratio_1_5,
        {{ box_sql.format(r='b.graduates_per_opening', g='b.projected_change_2022_2032_pct', gc='0', rc='2.0') }}   as box_ratio_2_0,
        {{ box_sql.format(r='b.graduates_per_opening', g='b.projected_change_2022_2032_pct', gc='b.nyc_all_jobs_change_2022_2032_pct', rc='1.0') }} as box_nyc_avg_growth,
        {{ box_sql.format(r='b.graduates_per_opening', g='b.actual_change_2019_2025_pct', gc='0', rc='1.0') }}      as box_actual_growth,
        {{ box_sql.format(r='b.graduates_per_opening_equal', g='b.projected_change_2022_2032_pct_equal', gc='0', rc='1.0') }} as box_equal_weights,
        {{ box_sql.format(r='b.graduates_per_opening_d20_off', g='b.projected_change_d20_off_pct', gc='0', rc='1.0') }} as box_d20_off,
        case
            when b.ai_exposure is null then null
            when b.ai_exposure = 0 then 'Not seen yet'   -- D7's fourth band, as on dim_job
            when b.ai_exposure < 0.10 then 'Low'
            when b.ai_exposure < 0.30 then 'Medium'
            else 'High'
        end as ai_band,
        case when b.ai_exposure_coverage is not null then b.ai_exposure_coverage < 0.7 end as ai_exposure_low_coverage
    from base as b
)

select
    x.*,
    case x.box
        when 'crowded'       then 'crowded'
        when 'growing_many'  then 'growing ' || chr(183) || ' many'
        when 'shrinking_few' then 'shrinking ' || chr(183) || ' few'
        when 'growing_few'   then 'growing ' || chr(183) || ' few'
    end as box_label,
    case x.box
        when 'crowded'       then 'more competition: shrinking jobs, more than one NYC graduate per opening'
        when 'growing_many'  then 'more graduates than openings, even as the job grows'
        when 'shrinking_few' then 'shrinking jobs, fewer NYC graduates than openings'
        when 'growing_few'   then 'growing jobs, fewer NYC graduates than openings'
    end as box_sentence,
    case
        when x.box = 'crowded'       then 'crowded_more_competition'
        when x.box = 'growing_many'  then 'growing_many_more_graduates_than_openings_even_as_job_grows'
        when x.box = 'shrinking_few' then 'shrinking_few'
        when x.box = 'growing_few'   then 'growing_few'
        when x.link_status = 'dispersed' then 'dispersed_see_destinations'
    end as wording_key,
    'ipeds_completions'     as source_key,
    'nysdol_projections'    as source_key_openings,
    'nces_cip'              as source_key_bridge,
    'bls_oews_research'     as source_key_nyc_estimate,
    'anthropic_ai_exposure' as source_key_exposure,
    'acs_pums'              as source_key_acs,
    'IPEDS 2024 provisional and 2019 first-major awards; NYS DOL 2022-2032 NYC projections (D1 fill where imputed); NYC jobs 2019 and 2025 = QCEW x OEWS research staffing pattern estimate (D8); Anthropic observed exposure (Mar 2026); ACS PUMS 2020-2024 (2024 dollars)' as as_of
from boxed as x
{% endcall %}
