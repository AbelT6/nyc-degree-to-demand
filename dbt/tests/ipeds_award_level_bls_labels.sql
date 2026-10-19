-- The BLS labels on the award-level seed (plan step2b §2, §9 step 1) must be spelled exactly as the tables they are
-- compared against spell them: bls_entry_education in dim_job.entry_education, bls_attainment_level in
-- stg_bls__ep_attainment.attainment_level. Both are filled for the two in-scope levels (3 and 5) and for the degree
-- codes 7, 17, 18, 19, and empty for certificates.
select 'entry_label_unknown' as problem, award_level::text || ' ' || bls_entry_education as detail
from {{ ref('dim_award_level') }} as a
where bls_entry_education is not null
  and not exists (select 1 from {{ ref('dim_job') }} j where j.entry_education = a.bls_entry_education)
union all
select 'attainment_label_unknown', award_level::text || ' ' || bls_attainment_level
from {{ ref('dim_award_level') }} as a
where bls_attainment_level is not null
  and not exists (select 1 from {{ source('staging', 'stg_bls__ep_attainment') }} s where s.attainment_level = a.bls_attainment_level)
union all
select 'filled_rows', string_agg(award_level::text, ' ' order by award_level)
from {{ ref('dim_award_level') }}
where bls_entry_education is not null or bls_attainment_level is not null
having string_agg(award_level::text, ' ' order by award_level) <> '3 5 7 17 18 19'
union all
select 'in_scope_unfilled', award_level::text
from {{ ref('dim_award_level') }}
where in_v1_scope and (bls_entry_education is null or bls_attainment_level is null)
