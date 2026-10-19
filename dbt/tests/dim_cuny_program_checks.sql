-- dim_cuny_program (plan §3c, §4 item 10): 2,991 programs; the enrollment staging table lists exactly the same
-- programs with the same attributes; every associate / bachelor program has an IPEDS award level (3 / 5) and the
-- staged CUNY award_level agrees with the seed's grouping.
with dim as (
    select * from {{ ref('dim_cuny_program') }}
),

enrollment_programs as (
    select distinct
        irp_code || '|' || college || '|' || award_name as program_key,
        unitid, unitid_is_parent_assumption, program_name, award_level, award_number, cip_code,
        date_registered, date_closed, tap_eligible, apts_eligible, vvta_eligible
    from {{ source('staging', 'stg_cuny__program_enrollment') }}
)

select 'row_count' as problem, count(*)::text as detail from dim having count(*) <> 2991

union all
select 'in_enrollment_not_in_dim', program_key from enrollment_programs where program_key not in (select program_key from dim)

union all
select 'in_dim_not_in_enrollment', program_key from dim where program_key not in (select program_key from enrollment_programs)

union all
select 'attributes_differ_from_enrollment', e.program_key
from enrollment_programs as e
join dim as d on d.program_key = e.program_key
where (d.unitid, d.unitid_is_parent_assumption, d.program_name, d.award_level, d.award_number, d.cip_code,
       d.date_registered, d.date_closed, d.tap_eligible, d.apts_eligible, d.vvta_eligible)
      is distinct from
      (e.unitid, e.unitid_is_parent_assumption, e.program_name, e.award_level, e.award_number, e.cip_code,
       e.date_registered, e.date_closed, e.tap_eligible, e.apts_eligible, e.vvta_eligible)

union all
select 'undergraduate_without_ipeds_level', program_key from dim
where award_level in ('associate', 'bachelor') and ipeds_award_level is null

union all
select 'ipeds_level_disagrees_with_group', program_key from dim
where (award_level = 'associate' and ipeds_award_level <> 3)
   or (award_level = 'bachelor' and ipeds_award_level <> 5)
   or (award_level in ('certificate', 'graduate') and ipeds_award_level is not null)

union all
select 'seed_group_disagrees_with_staging', d.program_key
from dim as d
join {{ ref('cuny_award_level') }} as s on s.award_name = d.award_name
where s.award_level <> d.award_level

union all
select 'closed_flag', program_key from dim where is_closed <> (date_closed is not null)
