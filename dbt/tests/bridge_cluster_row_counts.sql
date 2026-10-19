-- Cluster bridges keep every published row: 1,203 job rows (851 jobs) and 112 sector rows.
select 'job_cluster_rows' as problem, count(*)::text as detail from {{ ref('bridge_job_cluster') }} having count(*) <> 1203
union all
select 'job_cluster_jobs', count(distinct soc_code)::text from {{ ref('bridge_job_cluster') }} having count(distinct soc_code) <> 851
union all
select 'industry_cluster_rows', count(*)::text from {{ ref('bridge_industry_cluster') }} having count(*) <> 112
