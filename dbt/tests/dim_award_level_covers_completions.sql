-- Every award level in IPEDS completions is a dim_award_level row, and the seed has 13 rows.
select 'missing_award_level' as problem, award_level::text as detail
from (select distinct award_level from {{ source('staging', 'stg_ipeds__completions') }}) as c
where award_level not in (select award_level from {{ ref('dim_award_level') }})
union all
select 'row_count', count(*)::text from {{ ref('dim_award_level') }} having count(*) <> 13
