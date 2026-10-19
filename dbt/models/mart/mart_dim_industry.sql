-- mart.dim_industry: every industry row core facts land on (20 NAICS sectors, the all-industries total,
-- the CES aggregates and supersectors, the OEWS government designation), with the one series-break note
-- a page must show (docs/mart-plan.md §4a; nb 41 finding).
{{ config(alias='dim_industry') }}

select
    d.industry_key,
    d.level,
    d.industry_title,
    coalesce(s.short_title, d.industry_title) as industry_short_title,
    naics_sector,
    is_naics,
    sort_order,
    ces_supersector_title,
    case
        when d.industry_key = '48-49'
            then 'An employer reclassification in 2024 Q1 added about 43,000 payroll jobs and 128,000 QWI "new hires" to this sector; 2024 rates are not comparable with 2019.'
        when d.industry_key = '62'
            then 'In 2025 Q2 QWI shows about 261,000 "new hires" and 277,000 "separations" in one quarter with flat employment, in every borough: on April 1, 2025 New York moved its home-care CDPAP program from about 600 fiscal intermediaries to a single statewide employer (PPL), re-registering over 195,000 personal assistants. 2025 hiring rates for this sector are not comparable with earlier years.'
    end as break_note,
    case when level = 'sector' then true else false end as is_sector
from {{ ref('dim_industry') }} d
left join {{ ref('ref_industry_short_title') }} s on s.industry_key = d.industry_key
