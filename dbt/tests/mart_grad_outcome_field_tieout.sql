-- Plan §5 / explore-plan §3h and §3e tie-outs for mart.grad_outcome_field (nb 44 §5, §5c). Tolerances: medians
-- exact (dollars); premiums ±0.0005; Z ±0.005 (two decimals printed); lifts ±0.05 (23.3) and ±0.005 (1.03); shares
-- ±0.0005; counts exact. Verdict counts are distinct mapped fields per band (77 at 28-34: field 4009 has no row).
with f as (
    select * from {{ ref('mart_grad_outcome_field') }}
),

psy as (
    select * from f where fod1p = '5200' and age_band = '35-64' and degree_level = 'bachelor'
),

verdicts as (
    select age_band, premium_verdict, count(distinct fod1p) as n
    from f
    where is_mapped_field and premium_band
    group by 1, 2
),

fields_per_band as (
    select age_band, count(distinct fod1p) as n
    from f
    where is_mapped_field and premium_band
    group by 1
),

reference as (
    select distinct age_band, degree_level, all_fields_weighted_median, all_fields_premium_median
    from f
    where premium_band
),

rules as (
    select
        count(*) filter (where premium_sign_agrees is false)                                                    as sign_disagreements,
        count(*) filter (where is_mapped_field and premium_band and field_verdict = 'pathway' and lift < 3)        as pathway_breaks,
        count(*) filter (where is_mapped_field and premium_band and field_verdict = 'weak' and (lift < 1.5 or lift >= 3)) as weak_breaks,
        count(*) filter (where is_mapped_field and premium_band and field_verdict = 'convention' and lift >= 1.5)  as convention_breaks,
        count(*) filter (where premium_verdict = 'readable' and abs(premium_z) <= 1.645)                          as readable_breaks,
        count(*) filter (where premium_verdict = 'no readable difference' and abs(premium_z) > 1.645)             as nodiff_breaks
    from f
),

checks as (
    select 'Psychology 35-64 bachelor''s median' as check_name, 83789::numeric as expected, bachelor_median_earnings::numeric as got, 0::numeric as tolerance from psy
    union all
    select 'Psychology 35-64 graduate median', 117314, graduate_median_earnings, 0 from psy
    union all
    select 'Psychology 35-64 premium (median)', 0.400, premium_median, 0.0005 from psy
    union all
    select 'Psychology 35-64 Z', 7.48, premium_z, 0.005 from psy
    union all
    select 'Psychology 35-64 verdict readable', 1, (premium_verdict = 'readable')::int, 0 from psy
    union all
    select 'mapped fields with a 28-34 row', 77, n, 0 from fields_per_band where age_band = '28-34'
    union all
    select 'mapped fields with a 35-64 row', 78, n, 0 from fields_per_band where age_band = '35-64'
    union all
    select '28-34 readable', 9, coalesce(max(n), 0), 0 from verdicts where age_band = '28-34' and premium_verdict = 'readable'
    union all
    select '28-34 no readable difference', 34, coalesce(max(n), 0), 0 from verdicts where age_band = '28-34' and premium_verdict = 'no readable difference'
    union all
    select '28-34 unreadable (a median suppressed)', 34, coalesce(max(n), 0), 0 from verdicts where age_band = '28-34' and premium_verdict = 'unreadable (a median suppressed)'
    union all
    select '35-64 readable', 30, coalesce(max(n), 0), 0 from verdicts where age_band = '35-64' and premium_verdict = 'readable'
    union all
    select '35-64 no readable difference', 33, coalesce(max(n), 0), 0 from verdicts where age_band = '35-64' and premium_verdict = 'no readable difference'
    union all
    select '35-64 unreadable (a median suppressed)', 15, coalesce(max(n), 0), 0 from verdicts where age_band = '35-64' and premium_verdict = 'unreadable (a median suppressed)'
    union all
    select 'all-fields workers-weighted median, 28-34 bachelor''s', 99944, all_fields_weighted_median, 1 from reference where age_band = '28-34' and degree_level = 'bachelor'
    union all
    select 'all-fields workers-weighted median, 28-34 graduate', 108907, all_fields_weighted_median, 1 from reference where age_band = '28-34' and degree_level = 'graduate'
    union all
    select 'all-fields premium 28-34', 0.09, all_fields_premium_median, 0.005 from reference where age_band = '28-34' and degree_level = 'bachelor'
    union all
    select 'all-fields workers-weighted median, 35-64 bachelor''s', 102056, all_fields_weighted_median, 1 from reference where age_band = '35-64' and degree_level = 'bachelor'
    union all
    select 'all-fields workers-weighted median, 35-64 graduate', 134686, all_fields_weighted_median, 1 from reference where age_band = '35-64' and degree_level = 'graduate'
    union all
    select 'all-fields premium 35-64', 0.32, all_fields_premium_median, 0.005 from reference where age_band = '35-64' and degree_level = 'bachelor'
    union all
    select 'Nursing 6107 lift', 23.3, max(lift), 0.05 from f where fod1p = '6107'
    union all
    select 'Nursing 6107 linked share', 0.739, max(linked_share), 0.0005 from f where fod1p = '6107'
    union all
    select 'Nursing 6107 verdict pathway', 1, (max(field_verdict) = 'pathway')::int, 0 from f where fod1p = '6107'
    union all
    select 'Psychology 5200 lift', 1.03, max(lift), 0.005 from f where fod1p = '5200'
    union all
    select 'Psychology 5200 verdict convention', 1, (max(field_verdict) = 'convention')::int, 0 from f where fod1p = '5200'
    union all
    select 'readable fields where the mean premium disagrees in sign with the median premium', 0, sign_disagreements, 0 from rules
    union all
    select 'D20 verdict rule breaks (pathway >= 3, weak 1.5-3, convention < 1.5)', 0, pathway_breaks + weak_breaks + convention_breaks, 0 from rules
    union all
    select 'premium verdict disagrees with |Z| > 1.645', 0, readable_breaks + nodiff_breaks, 0 from rules
)

select *
from checks
where got is null or abs(got - expected) > tolerance
