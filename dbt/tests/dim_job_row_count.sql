-- dim_job must hold exactly the planned universe of codes:
-- 1,447 SOC 2018 codes + 5 BLS aggregates + 00-0000 (docs/step1-dimensions-plan.md §2).
select count(*) as n
from {{ ref('dim_job') }}
having count(*) <> 1453
