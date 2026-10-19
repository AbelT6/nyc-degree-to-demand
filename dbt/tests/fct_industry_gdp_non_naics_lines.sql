-- Plan §4 item 14: BEA line 2 (private industries, an ownership total) and line 83 (government, all public
-- ownership) never carry a NAICS-level industry_key. Line 2 is null; line 83 is CES-90 through industry_code_alias.
select f.year, f.area_key, f.line_code, f.industry_key
from {{ ref('fct_industry_gdp') }} as f
join {{ ref('dim_industry') }} as d
    on d.industry_key = f.industry_key
where f.line_code in (2, 83) and d.is_naics
