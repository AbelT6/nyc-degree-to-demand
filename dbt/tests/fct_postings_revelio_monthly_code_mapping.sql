-- Revelio code mapping (plan §4 item 16, D10): soc_major_code is null exactly for the 00 Unknown/Other group (923 rows)
-- and never 00-0000; industry_key is null exactly for industry 00 Unknown/Other and never industry 00 ("all").
select 'soc_null_mismatch' as problem, count(*)::text as detail
from {{ ref('fct_postings_revelio_monthly') }}
where (soc_major_code is null) <> (soc_group_code = '00')
having count(*) > 0
union all
select 'soc_all_jobs_row', count(*)::text
from {{ ref('fct_postings_revelio_monthly') }}
where soc_major_code = '00-0000'
having count(*) > 0
union all
select 'unknown_group_rows', count(*)::text
from {{ ref('fct_postings_revelio_monthly') }}
where soc_group_code = '00'
having count(*) <> 923
union all
select 'industry_null_mismatch', count(*)::text
from {{ ref('fct_postings_revelio_monthly') }}
where (industry_key is null) <> (industry_code_source = '00')
having count(*) > 0
union all
select 'industry_all_row', count(*)::text
from {{ ref('fct_postings_revelio_monthly') }}
where industry_key = '00'
having count(*) > 0
union all
select 'combined_sector_' || industry_code_source, string_agg(distinct coalesce(industry_key, 'null'), ',')
from {{ ref('fct_postings_revelio_monthly') }}
where industry_code_source in ('52-53', '54-56', '61-62', '71-72')
group by industry_code_source
having string_agg(distinct coalesce(industry_key, 'null'), ',') <> case industry_code_source
    when '52-53' then 'CES-55' when '54-56' then 'CES-60' when '61-62' then 'CES-65' when '71-72' then 'CES-70' end
