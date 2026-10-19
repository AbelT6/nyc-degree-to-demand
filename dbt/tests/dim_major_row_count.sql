-- dim_major holds every CIP 2020 code: 50 families + 473 series + 2,325 detailed = 2,848 (plan §6).
select cip_level, count(*) as n
from {{ ref('dim_major') }}
group by cip_level
having (cip_level = 'family' and count(*) <> 50)
    or (cip_level = 'series' and count(*) <> 473)
    or (cip_level = 'detailed' and count(*) <> 2325)
