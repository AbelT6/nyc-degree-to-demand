-- mart.job_skill_demand: one row per job x rank, up to 6, for the job page's "Skills employers ask for"
-- (docs/page3-build-plan.md §4 item 5; design brief §11.10 R1; D32; card docs/source-cards/onet_in_demand.md).
--   * Source: O*NET OnLine's In Demand Software Skills, the share of the job's unique U.S. job postings that mention the
--     product (Lightcast, calendar 2025), staged per O*NET-SOC code by nb 36.
--   * The .00 profile only (D32): each O*NET profile has its own posting pool, so specialty lists are not added,
--     averaged or borrowed. 162 named jobs get a list; Registered Nurses and 17-3024 (lists on specialty profiles
--     only) and the jobs with no in-demand software show the empty state.
--   * rank = % descending, then O*NET's row order (csv_order): O*NET's own order breaks its whole-number ties
--     (105 codes tie, 20 at the 6th place), and it is not alphabetical.
--   * product_display = O*NET's name without a trailing " software" ("Microsoft Office software" -> "Microsoft Office"),
--     with each spelled-out acronym put in brackets: an all-capital word spelled out by the words before it (their
--     initials, for / of / and / the skipped, are the acronym or appear in it in order) becomes "(SQL)":
--     "Structured query language SQL" -> "Structured query language (SQL)", "Hypertext markup language (HTML)",
--     "Microsoft Visual Basic for Applications (VBA)"; "(GIS) systems" drops the repeated "systems" unless the job
--     also lists the plain "(GIS)" (Geographers list both), so a job never shows one name twice.
--     Names that only contain capitals (PowerPoint, ArcGIS, MATLAB, Oracle HRIS) are left as O*NET writes them.
--   * share_of_job_ads is a fraction (O*NET publishes whole percents), like every share in the mart.
-- Publishing is gated on O*NET confirming the percentages are covered by CC BY 4.0 (docs/email-onet-in-demand-terms.md).
{{ config(alias='job_skill_demand') }}

{% call mart_numeric_as_double() %}
with ranked as (
    select
        d.soc_code,
        d.onet_soc_code,
        d.product,
        d.pct_of_job_ads,
        d.is_hot_technology,
        d.csv_order,
        d.window_start,
        d.window_end,
        d.retrieved_at,
        row_number() over (partition by d.soc_code order by d.pct_of_job_ads desc, d.csv_order) as rank
    from {{ source('staging', 'stg_onet__in_demand_pct') }} as d
    where d.onet_soc_code = d.soc_code || '.00'
),

words as (
    select r.soc_code, r.rank, w.word, w.pos
    from ranked as r
    cross join lateral unnest(string_to_array(regexp_replace(r.product, ' software$', ''), ' ')) with ordinality as w (word, pos)
),

acronyms as (
    -- an all-capital word spelled out by the k >= 2 words just before it (skipping for / of / and / the): their initials
    -- are the acronym, or appear in it in order with its first and last letter ("Hypertext markup language HTML")
    select a.soc_code, a.rank, a.pos
    from words as a
    where a.word ~ '^[A-Z]{2,}$'
      and exists (
          select 1
          from generate_series(2, length(a.word)) as k (n)
          cross join lateral (
              select count(*) as cnt, upper(string_agg(left(p.word, 1), '' order by p.pos)) as ini
              from (
                  select b.word, b.pos
                  from words as b
                  where b.soc_code = a.soc_code and b.rank = a.rank and b.pos < a.pos
                    and lower(b.word) not in ('for', 'of', 'and', 'the')
                  order by b.pos desc
                  limit k.n
              ) as p
          ) as i
          where i.cnt = k.n
            and (i.ini = a.word
                 or (left(i.ini, 1) = left(a.word, 1) and right(i.ini, 1) = right(a.word, 1)
                     and a.word ~ ('^' || array_to_string(regexp_split_to_array(i.ini, ''), '.*') || '$')))
      )
),

bracketed as (
    select
        w.soc_code,
        w.rank,
        string_agg(case when a.pos is not null then '(' || w.word || ')' else w.word end, ' ' order by w.pos) as name
    from words as w
    left join acronyms as a on a.soc_code = w.soc_code and a.rank = w.rank and a.pos = w.pos
    group by w.soc_code, w.rank
),

display as (
    -- "(GIS) systems" drops the repeated "systems", unless the job also lists the plain name (19-3092 lists both)
    select
        b.soc_code,
        b.rank,
        case when count(*) over (partition by b.soc_code, regexp_replace(b.name, '\(GIS\) systems$', '(GIS)')) = 1
             then regexp_replace(b.name, '\(GIS\) systems$', '(GIS)') else b.name end as product_display
    from bracketed as b
),

shortened as (
    -- the job page's skill cell holds about 200 px of 8 pt Inter (Desktop cuts the rest with "..."); the four
    -- names wider than that get a short form here, the full O*NET name stays in `product` (tw.py widths in brackets)
    select
        soc_code,
        rank,
        case product_display
            when 'Very high speed integrated circuit (VHSIC) hardware description language (VHDL) simulation'
                then 'VHDL simulation'                               -- 469 -> 83 px (17-2061)
            when 'Microsoft Visual Basic for Applications (VBA)'
                then 'Visual Basic for Applications (VBA)'           -- 228 -> 177 px (15-2011)
            when 'Geographic information system (GIS) systems'
                then 'GIS systems'                                   -- 231 -> 63 px (19-3092, which also lists the
                                                                     -- spelled-out "Geographic information system (GIS)")
            when 'Tax compliance property tax management'
                then 'Property tax management'                       -- 210 -> 128 px (13-2081)
            else product_display
        end as product_display
    from display
)

select
    r.soc_code,
    r.rank,
    r.onet_soc_code,
    r.product,
    dp.product_display,
    r.pct_of_job_ads / 100.0                                    as share_of_job_ads,
    r.pct_of_job_ads,
    r.is_hot_technology,
    r.csv_order,
    r.window_start,
    r.window_end,
    r.retrieved_at,
    'onet_in_demand'                                            as source_key,
    'O*NET OnLine In Demand Software Skills: share of U.S. job postings, Lightcast, '
        || to_char(r.window_start, 'FMMonth FMDD, YYYY') || ' to ' || to_char(r.window_end, 'FMMonth FMDD, YYYY')
        || ' (retrieved ' || to_char(r.retrieved_at, 'YYYY-MM-DD') || ')' as as_of
from ranked as r
join {{ ref('dim_job') }} as j on j.soc_code = r.soc_code
join shortened as dp on dp.soc_code = r.soc_code and dp.rank = r.rank
where r.rank <= 6
{% endcall %}
