-- mart.industry_profile has exactly one row per sector in mart.dim_industry (20): no sector dropped by the left
-- joins and no fan-out through the QCEW, GDP, pattern, hiring or CES joins.
select 'row count' as check_name, d.n as sectors_in_dim, p.n as profile_rows
from (select count(*) as n from {{ ref('mart_dim_industry') }} where is_sector) d,
     (select count(*) as n from {{ ref('mart_industry_profile') }}) p
where d.n <> p.n or p.n <> 20
