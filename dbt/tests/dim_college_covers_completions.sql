-- Every unitid in IPEDS completions has a dim_college row, and dim_college holds 225 colleges, 21 of them CUNY.
select 'missing_unitid' as problem, unitid as detail
from (select distinct unitid from {{ source('staging', 'stg_ipeds__completions') }}) as c
where unitid not in (select unitid from {{ ref('dim_college') }})
union all
select 'row_count', count(*)::text from {{ ref('dim_college') }} having count(*) <> 225
union all
select 'cuny_count', count(*)::text from {{ ref('dim_college') }} where is_cuny having count(*) <> 21
