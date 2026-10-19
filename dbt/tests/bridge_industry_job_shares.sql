-- Per sector, share_of_industry sums to the disclosed coverage (between 0.75 and 1.0001: agriculture 0.77 and mining 0.83
-- are tiny NY sectors with suppressed cells; every other sector is above 0.91); per job, share_of_job sums to 1;
-- every NY row has a dim_industry key; 20 sectors and the government designation are present.
select 'industry_share_out_of_range' as problem, naics_sector as detail, sum(share_of_industry)::text as value
from {{ ref('bridge_industry_job') }} where in_ny_research group by naics_sector
having sum(share_of_industry) < 0.75 or sum(share_of_industry) > 1.0001
union all
select 'job_share_not_one', soc_code, sum(share_of_job)::text
from {{ ref('bridge_industry_job') }} where in_ny_research and share_of_job is not null group by soc_code
having abs(sum(share_of_job) - 1) > 1e-6
union all
select 'ny_row_without_industry_key', naics_sector || ' ' || soc_code, null
from {{ ref('bridge_industry_job') }} where in_ny_research and industry_key is null
union all
select 'ny_sector_count', count(distinct naics_sector)::text, null
from {{ ref('bridge_industry_job') }} where in_ny_research having count(distinct naics_sector) <> 20
union all
select 'research_99_not_government', naics_sector, industry_key
from {{ ref('bridge_industry_job') }} where naics_sector = '99' and industry_key <> 'GOV-OEWS' group by 1, 2, 3
