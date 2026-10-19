-- mart.major_awards_trend: one row per year x major x award level x college, 2015-2024 (docs/mart-plan.md §4c;
-- nb 05 rule: first majors only, major_number = 1; levels 3 and 5 = the v1 scope of dim_major_award; 2024 is the
-- IPEDS provisional release). awards = awards_total summed over the key; is_cuny / college_group drive the S9
-- "CUNY vs all NYC" split. Grain test: tests/mart_major_awards_trend_grain.sql.
{{ config(alias='major_awards_trend') }}

{% call mart_numeric_as_double() %}
select
    a.year,
    make_date(a.year, 1, 1)                                   as year_start,
    a.cip_code || '|' || a.award_level                        as major_award_key,
    a.cip_code,
    a.award_level,
    a.unitid,
    c.is_cuny,
    case when c.is_cuny then 'CUNY' else 'Other NYC colleges' end as college_group,
    sum(a.awards_total)                                       as awards,
    sum(a.awards_men)                                         as awards_men,
    sum(a.awards_women)                                       as awards_women,
    max(a.release)                                            as release,
    bool_or(a.release = 'provisional')                        as is_provisional,
    'ipeds_completions'                                       as source_key,
    'NCES IPEDS Completions 2015-2024 (2024 provisional), first majors, associate''s (3) and bachelor''s (5)' as as_of
from {{ ref('fct_degree_awards') }} as a
join {{ ref('dim_college') }} as c on c.unitid = a.unitid
where a.major_number = 1 and a.award_level in (3, 5)
group by a.year, a.cip_code, a.award_level, a.unitid, c.is_cuny
{% endcall %}
