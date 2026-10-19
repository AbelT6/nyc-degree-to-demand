-- Every passing job has an openings basis, openings are never negative, a basis of none means 0 openings and vice
-- versa, and the jobs with no openings input are exactly the 23 listed in plan §4a (all without an OEWS NY metro
-- 2025 employment row and without a NYS DOL 2022-32 row).
with none_jobs as (
    select distinct soc_code from {{ ref('bridge_major_job') }} where openings_basis = 'none'
),

expected as (
    select unnest(array[
        '11-9071', '13-1032', '17-2021', '17-2151', '17-2161', '17-2171', '19-1011', '19-2011', '19-3041', '19-3092',
        '19-4012', '19-4044', '27-1012', '39-4011', '43-2099', '43-3041', '49-9045', '49-9064', '51-7031', '51-7032',
        '51-7099', '51-8011', '53-5022'
    ]) as soc_code
)

select 'bad_row' as problem, cip_code || ' ' || award_level::text || ' ' || soc_code as detail
from {{ ref('bridge_major_job') }}
where openings_basis is null
   or openings_nyc is null
   or openings_nyc < 0
   or (openings_basis = 'none') <> (openings_nyc = 0)
union all
select 'unexpected_none', soc_code from none_jobs where soc_code not in (select soc_code from expected)
union all
select 'expected_none_missing', soc_code from expected where soc_code not in (select soc_code from none_jobs)
