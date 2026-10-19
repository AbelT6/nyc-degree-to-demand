-- Trace guards (plan §4c): Registered Nursing 51.3801 passes one job, Registered Nurses 29-1141, with both weights 1
-- at both levels; Computer Science 11.0701 at the bachelor's level passes 12 jobs whose openings sum to about 9,999,
-- with Software Developers 15-1252 (imputed, 4,308 openings) at weight 4,308 / 9,999 = 0.4308, and at the associate's
-- level passes only 15-1231 Computer Network Support Specialists (459 openings, associate's entry).
with rn as (
    select * from {{ ref('bridge_major_job') }} where cip_code = '51.3801'
),
cs as (
    select * from {{ ref('bridge_major_job') }} where cip_code = '11.0701'
)
select 'rn' as problem, award_level::text || ' ' || soc_code as detail
from rn
where soc_code <> '29-1141' or n_jobs_in_major <> 1 or abs(weight_openings - 1) > 1e-9 or abs(weight_equal - 1) > 1e-9
union all
select 'rn_levels', count(*)::text from rn having count(*) <> 2
union all
select 'cs_bachelor_jobs', count(*)::text || ' jobs, ' || round(sum(openings_nyc), 2)::text || ' openings'
from cs where award_level = 5
having count(*) <> 12 or sum(openings_nyc) not between 9990 and 10010
union all
select 'cs_software_developers', soc_code || ' ' || openings_basis || ' ' || round(openings_nyc, 2)::text || ' w=' || round(weight_openings, 6)::text
from cs
where award_level = 5 and soc_code = '15-1252'
  and not (openings_basis = 'imputed' and openings_nyc between 4300 and 4320
           and weight_openings between 0.4305 and 0.4312 and abs(weight_equal - 1.0 / 12) < 1e-9)
union all
select 'cs_associate', string_agg(soc_code, ' ')
from cs where award_level = 3
having count(*) <> 1 or max(soc_code) <> '15-1231'
