-- mart.grad_outcome_field: one row per ACS field of degree x age band x degree level, cut field_total of
-- fct_grad_outcome (every field the PUMS carries; is_mapped_field marks the 78 fields in ref_fod_cip /
-- int_major_field_lift). Implements docs/mart-plan.md §4d, explore-plan §3e (the lift, D20) and §3h (the graduate
-- premium):
--   * workers, shares, median and mean full-time year-round earnings (2024 dollars) with 90% MOEs; suppressed rows
--     (under 30 responses) are kept with null values, never dropped (D17).
--   * Graduate premium (§3h), on the 28-34 and 35-64 bands only, repeated on the bachelor and graduate rows of the
--     pair: premium_median = graduate median / bachelor's median - 1, premium_mean beside it; SE = MOE / 1.645,
--     Z = (graduate - bachelor's) / sqrt(SE_g^2 + SE_b^2); 'readable' when |Z| > 1.645, otherwise 'no readable
--     difference'; 'unreadable (a median suppressed)' when either median is suppressed or the row is missing.
--     Words on pages: "graduate holders earn X% more", never "a master's adds X%" (wording_key).
--   * all_fields_weighted_median = the workers-weighted mean of field medians for the row's level and band over every
--     field with a readable median (the §3h reference); all_fields_premium_median = the graduate reference over the
--     bachelor's reference - 1.
--   * graduate_share_of_degree_holders = graduate workers / (bachelor's + graduate workers) for the field and band.
--   * Lift (§3e, D20) from int_major_field_lift (22-34 bachelor's-only workers): linked share + MOE, base rate,
--     lift, verdict (pathway >= 3, weak 1.5-3, convention < 1.5, unreadable).
{{ config(alias='grad_outcome_field') }}

{% call mart_numeric_as_double() %}
with ft as (
    select *
    from {{ ref('fct_grad_outcome') }}
    where cut = 'field_total'
),

lift as (
    select * from {{ ref('int_major_field_lift') }}
),

reference as (
    select
        age_band,
        degree_level,
        sum(workers * median_earnings_2024usd) / sum(workers) as all_fields_weighted_median,
        count(*)                                              as all_fields_n_readable
    from ft
    where not suppressed and not earnings_suppressed and median_earnings_2024usd is not null and workers > 0
    group by 1, 2
),

pairs as (
    select
        coalesce(b.group_1, g.group_1)   as fod1p,
        coalesce(b.age_band, g.age_band) as age_band,
        b.median_earnings_2024usd        as b_median,
        b.moe_median_earnings            as b_moe,
        b.mean_earnings_2024usd          as b_mean,
        b.workers                        as b_workers,
        g.median_earnings_2024usd        as g_median,
        g.moe_median_earnings            as g_moe,
        g.mean_earnings_2024usd          as g_mean,
        g.workers                        as g_workers,
        coalesce(b.earnings_suppressed, true) or coalesce(g.earnings_suppressed, true)
            or b.median_earnings_2024usd is null or g.median_earnings_2024usd is null as a_median_suppressed
    from (select * from ft where degree_level = 'bachelor') as b
    full join (select * from ft where degree_level = 'graduate') as g
        on g.group_1 = b.group_1 and g.age_band = b.age_band
),

premium as (
    select
        p.fod1p,
        p.age_band,
        p.age_band in ('28-34', '35-64')                                   as premium_band,
        p.b_median                                                         as bachelor_median_earnings,
        p.g_median                                                         as graduate_median_earnings,
        p.g_median / nullif(p.b_median, 0) - 1                             as premium_median,
        p.g_mean / nullif(p.b_mean, 0) - 1                                 as premium_mean,
        (p.g_median - p.b_median)
            / nullif(sqrt(power(p.g_moe / 1.645, 2) + power(p.b_moe / 1.645, 2)), 0) as premium_z,
        p.a_median_suppressed,
        case
            when p.b_workers is not null and p.g_workers is not null and p.b_workers + p.g_workers > 0
            then p.g_workers / (p.b_workers + p.g_workers)
        end                                                                as graduate_share_of_degree_holders
    from pairs as p
),

verdict as (
    select
        pr.*,
        case
            when not pr.premium_band then null
            when pr.a_median_suppressed then 'unreadable (a median suppressed)'
            when abs(pr.premium_z) > 1.645 then 'readable'
            else 'no readable difference'
        end as premium_verdict
    from premium as pr
)

select
    f.group_1                                   as fod1p,
    coalesce(f.group_1_label, l.fod_title, 'Field ' || f.group_1) as fod_title,  -- unmapped PUMS fields carry no label in the fact
    l.fod1p is not null                         as is_mapped_field,
    f.age_band,
    f.degree_level,
    f.n_unweighted,
    f.n_ftyr,
    f.suppressed,
    f.workers,
    f.moe_workers,
    f.share_of_group                            as share_of_level_workers,
    f.moe_share                                 as moe_share_of_level_workers,
    f.group_workers                             as level_workers,
    f.earnings_suppressed,
    f.median_earnings_2024usd,
    f.moe_median_earnings,
    f.mean_earnings_2024usd,
    f.moe_mean_earnings,
    f.includes_allocated_codes,
    -- graduate premium (§3h; 28-34 and 35-64 only; the same on both rows of the pair)
    v.premium_band,
    case when v.premium_band then v.bachelor_median_earnings end                     as bachelor_median_earnings,
    case when v.premium_band then v.graduate_median_earnings end                     as graduate_median_earnings,
    case when v.premium_band and not v.a_median_suppressed then v.premium_median end as premium_median,
    case when v.premium_band and not v.a_median_suppressed then v.premium_mean end   as premium_mean,
    case when v.premium_band and not v.a_median_suppressed then v.premium_z end      as premium_z,
    v.premium_verdict,
    case when v.premium_band and v.premium_verdict = 'readable'
         then sign(v.premium_mean) = sign(v.premium_median) end                      as premium_sign_agrees,
    'graduate_holders_earn_pct_more'                                                 as wording_key,
    r.all_fields_weighted_median,
    r.all_fields_n_readable,
    rg.all_fields_weighted_median / nullif(rb.all_fields_weighted_median, 0) - 1     as all_fields_premium_median,
    v.graduate_share_of_degree_holders,
    -- lift (§3e, D20), a field-level number from the 22-34 bachelor's-only population
    l.linked_share,
    l.moe_linked_share,
    l.base_rate,
    l.lift,
    l.verdict                                   as field_verdict,
    l.n_linked_jobs,
    l.n_all_other_jobs,
    l.n_base_jobs_suppressed,
    f.source_key,
    'ACS PUMS 2020-2024 five-year file, NYC residents, employed civilians not enrolled, full-time year-round earnings in 2024 dollars, 90% MOEs from replicate weights' as as_of
from ft as f
left join lift as l on l.fod1p = f.group_1
left join verdict as v on v.fod1p = f.group_1 and v.age_band = f.age_band
left join reference as r on r.age_band = f.age_band and r.degree_level = f.degree_level
left join reference as rb on rb.age_band = f.age_band and rb.degree_level = 'bachelor'
left join reference as rg on rg.age_band = f.age_band and rg.degree_level = 'graduate'
{% endcall %}
