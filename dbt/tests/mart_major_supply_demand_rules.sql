-- Rule checks for mart.major_supply_demand (explore-plan §3c, §3i; D7, D19, D20): the box follows the two flags and
-- the cutoffs; ratios, growth and the bridge exposure exist only on linked majors; dispersed majors carry no box, the
-- 'dispersed_see_destinations' wording key and the ACS-basis exposure; transfer / no-link majors carry nulls; the
-- D7 band follows the exposure; coverages sit in [0, 1.0005]; awards never negative.
with m as (
    select * from {{ ref('mart_major_supply_demand') }}
),

breaks as (
    select major_award_key, 'box disagrees with many_graduates / is_shrinking' as rule
    from m
    where box is not null and box <> case
        when is_shrinking and many_graduates then 'crowded'
        when not is_shrinking and many_graduates then 'growing_many'
        when is_shrinking then 'shrinking_few'
        else 'growing_few' end
    union all
    select major_award_key, 'box null although ratio and growth exist' from m
    where box is null and graduates_per_opening is not null and projected_change_2022_2032_pct is not null
    union all
    select major_award_key, 'many_graduates disagrees with ratio > 1.0' from m
    where graduates_per_opening is not null and many_graduates is distinct from (graduates_per_opening > 1.0)
    union all
    select major_award_key, 'is_shrinking disagrees with projected change <= 0' from m
    where projected_change_2022_2032_pct is not null and is_shrinking is distinct from (projected_change_2022_2032_pct <= 0)
    union all
    select major_award_key, 'ratio / growth / box / high share on a non-linked major' from m
    where link_status <> 'linked' and (graduates_per_opening is not null or projected_change_2022_2032_pct is not null
                                       or box is not null or ai_high_share is not null or top_exposed_jobs is not null)
    union all
    select major_award_key, 'linked major with a rated job but no ratio' from m
    where link_status = 'linked' and n_jobs_with_ratio > 0 and graduates_per_opening is null
    union all
    select major_award_key, 'linked major with a ratio but no openings weight' from m
    where link_status = 'linked' and not has_openings_weight and graduates_per_opening is not null
    union all
    select major_award_key, 'dispersed major without the destinations wording key or with a bridge-basis exposure' from m
    where link_status = 'dispersed' and (wording_key is distinct from 'dispersed_see_destinations'
                                         or ai_exposure_basis is distinct from 'by where its graduates work')
    union all
    select major_award_key, 'linked major with exposure but the wrong basis' from m
    where link_status = 'linked' and ai_exposure is not null and ai_exposure_basis is distinct from 'by the jobs it leads to'
    union all
    select major_award_key, 'transfer / no-link major carries a number it should not' from m
    where link_status in ('transfer_pathway', 'not_in_crosswalk')
      and (ai_exposure is not null or ai_band is not null or wording_key is not null or counts_as_supply
           or graduates_per_opening_d20_off is not null)
    union all
    select major_award_key, 'wording key disagrees with the box' from m
    where box is not null and wording_key is distinct from case box
        when 'crowded' then 'crowded_more_competition'
        when 'growing_many' then 'growing_many_more_graduates_than_openings_even_as_job_grows'
        when 'shrinking_few' then 'shrinking_few'
        else 'growing_few' end
    union all
    select major_award_key, 'ai_band disagrees with the D7 cutoffs' from m
    where ai_exposure is not null and ai_band is distinct from case
        when ai_exposure = 0 then 'Not seen yet' when ai_exposure < 0.10 then 'Low' when ai_exposure < 0.30 then 'Medium' else 'High' end
    union all
    select major_award_key, 'coverage outside [0, 1.0005]' from m
    where ai_exposure_coverage not between 0 and 1.0005 or ratio_weight_coverage not between 0 and 1.0005
       or actual_weight_coverage not between 0 and 1.0005
    union all
    select major_award_key, 'low-coverage flag disagrees with coverage < 0.7' from m
    where ai_exposure_coverage is not null and ai_exposure_low_coverage is distinct from (ai_exposure_coverage < 0.7)
    union all
    select major_award_key, 'high share outside [0, 1.0005]' from m
    where ai_high_share not between 0 and 1.0005
    union all
    select major_award_key, 'negative awards or CUNY above all NYC' from m
    where awards_2024_nyc < 0 or awards_2019_nyc < 0 or awards_2024_cuny > awards_2024_nyc or awards_2019_cuny > awards_2019_nyc
    union all
    select major_award_key, 'counts_as_supply disagrees with link_status' from m
    where counts_as_supply is distinct from (link_status = 'linked')
)

select * from breaks
