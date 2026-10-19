-- mart.bridge_job_cluster keeps every core bridge row (every bridged code is a detailed job in mart.dim_job).
select 'row count' as check_name, c.n as core_rows, m.n as mart_rows
from (select count(*) as n from {{ ref('bridge_job_cluster') }}) c,
     (select count(*) as n from {{ ref('mart_bridge_job_cluster') }}) m
where c.n <> m.n
