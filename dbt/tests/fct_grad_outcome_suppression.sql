-- Suppression (plan §4 item 15, D5, brief S13): suppressed = n_unweighted < 30 and earnings_suppressed = n_ftyr < 30;
-- suppressed rows carry no estimate or MOE; unsuppressed rows carry workers, share and their MOEs; the earnings
-- estimates and their MOEs are present exactly when neither flag is set.
select period, cut, group_1, group_2, age_band, degree_level, n_unweighted, n_ftyr, suppressed, earnings_suppressed
from {{ ref('fct_grad_outcome') }}
where suppressed <> (n_unweighted < 30)
   or earnings_suppressed <> (n_ftyr < 30)
   or (suppressed and (
        workers is not null or moe_workers is not null or share_of_group is not null or moe_share is not null))
   or (not suppressed and (
        workers is null or moe_workers is null or share_of_group is null or moe_share is null))
   or ((suppressed or earnings_suppressed) and (
        mean_earnings_2024usd is not null or moe_mean_earnings is not null
        or median_earnings_2024usd is not null or moe_median_earnings is not null))
   or (not suppressed and not earnings_suppressed and (
        mean_earnings_2024usd is null or moe_mean_earnings is null
        or median_earnings_2024usd is null or moe_median_earnings is null))
