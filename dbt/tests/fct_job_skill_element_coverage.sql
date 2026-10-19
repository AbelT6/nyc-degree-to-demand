-- Plan §4 item 7: every job with ratings carries the full element set on both scales: 33 knowledge x 2, 10 essential
-- skills x 2, 25 transferable skills x 2 = 136 rows, including the 5 pooled BLS aggregates.
with per_job as (
    select
        soc_code,
        count(*) as n_rows,
        count(*) filter (where domain = 'knowledge')          as n_knowledge,
        count(*) filter (where domain = 'skill_essential')    as n_essential,
        count(*) filter (where domain = 'skill_transferable') as n_transferable,
        count(distinct scale)                                 as n_scales
    from {{ ref('fct_job_skill') }}
    group by soc_code
)
select *
from per_job
where n_rows <> 136 or n_knowledge <> 66 or n_essential <> 20 or n_transferable <> 50 or n_scales <> 2
union all
select 'aggregates', count(*), null, null, null, null
from per_job
where soc_code in (select soc_code from {{ ref('dim_job') }} where soc_level = 'bls_aggregate')
having count(*) <> 5
