-- D5 direction check (plan §4 item 6): within the BLS experience bands none -> under_5_years -> 5_years_plus, the
-- median O*NET newcomer share and the median unsuppressed ACS young share both fall strictly. Built at
-- O*NET 0.228 / 0.115 / 0.000 and ACS 0.184 / 0.157 / 0.128.
with bls as (
    select soc_code, value as experience_rank
    from {{ ref('fct_job_entry_signal') }}
    where measure = 'bls_experience'
),

medians as (
    select
        b.experience_rank,
        percentile_cont(0.5) within group (order by o.value) as med_onet,
        percentile_cont(0.5) within group (order by a.value) as med_acs
    from bls as b
    left join {{ ref('fct_job_entry_signal') }} as o
        on o.soc_code = b.soc_code and o.measure = 'onet_newcomer'
    left join {{ ref('fct_job_entry_signal') }} as a
        on a.soc_code = b.soc_code and a.measure = 'acs_young_share' and not a.suppressed
    group by b.experience_rank
),

lagged as (
    select
        experience_rank,
        med_onet,
        lag(med_onet) over (order by experience_rank) as prev_onet,
        med_acs,
        lag(med_acs) over (order by experience_rank) as prev_acs
    from medians
)

select experience_rank, med_onet, prev_onet, med_acs, prev_acs
from lagged
where experience_rank > 1
  and (med_onet is null or prev_onet is null or med_onet >= prev_onet
       or med_acs is null or prev_acs is null or med_acs >= prev_acs)
