-- core.dim_award_level: the 13 IPEDS AWLEVEL codes, from the hand-built seed ref/ipeds_award_level.csv
-- (labels copied from the downloaded C2024 dictionary). Measured years_used come from completions.

with used as (
    select award_level, min(year) as first_year_seen, max(year) as last_year_seen, sum(awards_total) as awards_2015_2024
    from {{ source('staging', 'stg_ipeds__completions') }}
    group by award_level
)

select
    a.award_level,
    a.award_label,
    a.award_group,
    a.is_degree,
    a.in_v1_scope,
    a.sort_order,
    a.bls_entry_education,
    a.bls_attainment_level,
    u.first_year_seen,
    u.last_year_seen,
    u.awards_2015_2024,
    a.note
from {{ ref('ipeds_award_level') }} as a
left join used as u on u.award_level = a.award_level
