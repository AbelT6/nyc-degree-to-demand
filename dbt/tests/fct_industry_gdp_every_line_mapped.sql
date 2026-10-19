-- Plan §3d: every BEA line on fct_industry_gdp maps to a dim_industry row, except line 2 (private industries), and line 2 maps to none.
select distinct line_code, line_title, naics_label, industry_key
from {{ ref('fct_industry_gdp') }}
where (line_code <> 2 and industry_key is null)
   or (line_code = 2 and industry_key is not null)
