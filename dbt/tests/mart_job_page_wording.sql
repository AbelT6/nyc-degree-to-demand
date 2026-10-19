-- Job page wording keys and display columns (page 3 build plan §3.2-§3.5, §3.8, §3.9, §5, §6; design brief §11.12 v4.1):
-- card 3's key recomputed from job_major_link, the counts per key over the 202 named jobs, the
-- route and majors display columns, the job page's footer rows, and the §5 tie-outs for 13-2011 and 25-2021.
-- D57: the 4 jobs BLS rates only as a group (29-2010, 25-2052, 13-1020, 13-2020) now have majors (no_major 6 -> 2,
-- one_for_every_n 109 -> 113, split 143 -> 146, all_count 13 -> 14, both levels 26 -> 27); Accounting also links to
-- 13-2020 (13-2011: 1,150 / 856 -> 1,140 / 849 after D58's part share) and Elementary Education to 25-2052 (25-2021: 1 for every 5 -> 6,
-- 674 / 485 -> 626 / 450).
-- Returns one row per failed check.
with p as (
    select * from {{ ref('mart_job_profile') }}
),

named as (
    select * from p where not is_all_other
),

r as (
    select * from {{ ref('mart_job_escape_route') }}
),

m as (
    select * from {{ ref('mart_job_major_link') }}
),

f as (
    select * from {{ ref('mart_footnote') }} where page_key = 'job'
),

-- card 3 recomputed from job_major_link (its job totals are tested equal to job_profile's elsewhere)
card3 as (
    select
        p.soc_code,
        p.per_opening_key,
        p.per_opening_n,
        case
            when not p.has_projection then 'needs_projection'
            when j.soc_code is null then 'no_major'
            when a.awards_all = 0 then 'zero_graduates'
            when a.awards_linked = 0 then 'majors_dispersed'
            when j.job_graduates_per_opening = 0 then 'zero_graduates'
            when j.job_graduates_per_opening < 0.01 then 'under_1_per_100'
            when 1 / j.job_graduates_per_opening >= 1.5 then 'one_for_every_n'
            when j.job_graduates_per_opening < 1.5 then 'about_one'
            else 'n_per_opening'
        end as key_recomputed
    from p
    left join (select distinct soc_code, job_n_majors_linked, job_graduates_per_opening from m) as j on j.soc_code = p.soc_code
    left join (select soc_code, coalesce(sum(awards_2024_nyc), 0) as awards_all,
                      coalesce(sum(awards_2024_nyc) filter (where counts_as_supply), 0) as awards_linked
               from m group by soc_code) as a on a.soc_code = p.soc_code
),

checks as (
    select 'card 3 key = recomputed from job_major_link' as check_name, 0::numeric as expected,
           count(*) filter (where per_opening_key is distinct from key_recomputed)::numeric as got from card3
    union all
    select 'card 3 and the majors sentence agree (sweep: 3 jobs disagreed)', 0::numeric,
           count(*) filter (where has_projection and ((per_opening_key = 'zero_graduates') <> (majors_split_key = 'no_graduates_2024')
                                                     or (per_opening_key = 'majors_dispersed') <> (majors_split_key = 'all_dispersed')))::numeric from p
    union all
    select 'one_for_every_n never says 1', 0, count(*) filter (where per_opening_key = 'one_for_every_n' and per_opening_n < 2) from p
    union all
    select 'per_opening_n only where the sentence has a number', 0,
           count(*) filter (where (per_opening_n is null) <> (per_opening_key not in ('one_for_every_n', 'about_one', 'n_per_opening'))) from p
    union all
    select 'card 3: needs_projection 38', 38, count(*) filter (where per_opening_key = 'needs_projection') from named
    union all
    select 'card 3: no_major 2', 2, count(*) filter (where per_opening_key = 'no_major') from named
    union all
    select 'card 3: majors_dispersed 2', 2, count(*) filter (where per_opening_key = 'majors_dispersed') from named
    union all
    select 'card 3: zero_graduates 12', 12, count(*) filter (where per_opening_key = 'zero_graduates') from named
    union all
    select 'card 3: under_1_per_100 13', 13, count(*) filter (where per_opening_key = 'under_1_per_100') from named
    union all
    select 'card 3: one_for_every_n 113', 113, count(*) filter (where per_opening_key = 'one_for_every_n') from named
    union all
    select 'card 3: about_one 14 (13 + 17-3011 at r 0.667)', 14, count(*) filter (where per_opening_key = 'about_one') from named
    union all
    select 'card 3: n_per_opening 8', 8, count(*) filter (where per_opening_key = 'n_per_opening') from named
    union all
    select 'majors: split 146', 146, count(*) filter (where majors_split_key = 'split') from named
    union all
    select 'majors: all_count 14', 14, count(*) filter (where majors_split_key = 'all_count') from named
    union all
    select 'majors: under_one 7', 7, count(*) filter (where majors_split_key = 'under_one') from named
    union all
    select 'majors: none_counted 3', 3, count(*) filter (where majors_split_key = 'none_counted') from named
    union all
    select 'majors: all_dispersed 2', 2, count(*) filter (where majors_split_key = 'all_dispersed') from named
    union all
    select 'majors: no_graduates_2024 28', 28, count(*) filter (where majors_split_key = 'no_graduates_2024') from named
    union all
    select 'majors: no_major 2', 2, count(*) filter (where majors_split_key = 'no_major') from named
    union all
    select 'majors: a number exactly where the sentence has one', 0,
           count(*) filter (where (majors_split_n is null) <> (majors_split_key not in ('split', 'all_count', 'no_graduates_2024'))) from p
    union all
    select 'majors levels label: both levels on 27 named jobs', 27,
           count(*) filter (where majors_levels_label = 'Bachelor''s & associate graduates, 2024') from named
    union all
    select 'majors levels label in its three forms', 0,
           count(*) filter (where majors_levels_label not in ('Bachelor''s graduates, 2024', 'Associate graduates, 2024',
                                                              'Bachelor''s & associate graduates, 2024')) from p
    union all
    select 'majors levels label null only when no major had graduates', 0,
           count(*) filter (where (majors_levels_label is null) <> (majors_split_key in ('no_major', 'no_graduates_2024'))) from p
    union all
    select '"Assoc. · " only on associate rows of two-level jobs', 0,
           count(*) filter (where (major_label like 'Assoc. · %') <> (job_has_both_levels and award_level = 3)) from m
    union all
    select '✦ only on dispersed majors', 0, count(*) filter (where (major_label_details like '✦ %') <> (not counts_as_supply)) from m
    union all
    select 'major_rank_in_job on exactly the majors with graduates', 0,
           count(*) filter (where (major_rank_in_job is null) <> (awards_2024_nyc = 0)) from m
    union all
    select 'routes: listed 27', 27, count(*) filter (where routes_status = 'listed') from named
    union all
    select 'routes: none_qualify 1 (15-1244)', 1, count(*) filter (where routes_status = 'none_qualify' and soc_code = '15-1244') from named
    union all
    select 'routes: no_skill_ratings 2 (13-2051, 29-9021)', 2,
           count(*) filter (where routes_status = 'no_skill_ratings' and soc_code in ('13-2051', '29-9021')) from named
    union all
    select 'routes: no_nyc_wage 1 (43-9111)', 1, count(*) filter (where routes_status = 'no_nyc_wage' and soc_code = '43-9111') from named
    union all
    select 'routes: not_high = Medium + Low (106)', 106, count(*) filter (where routes_status = 'not_high') from named
    union all
    select 'routes: listed = has a route row with a destination', 0, count(*) filter (where (routes_status = 'listed') <> exists (
               select 1 from r where r.origin_soc_code = p.soc_code and r.destination_soc_code is not null)) from p
    union all
    select 'every route destination has a job_label, title, description and pay words', 0,
           count(*) filter (where destination_soc_code is not null and (destination_label is null or destination_title is null
                            or destination_description is null or pay_words is null or destination_entry_wage is null)) from r
    union all
    select 'pay words: 3.4 times (43-4161 -> 11-3121)', 1,
           count(*) filter (where pay_words = 'pays 3.4 times as much') from r where origin_soc_code = '43-4161' and destination_soc_code = '11-3121'
    union all
    select 'employer bar label: GOV-OEWS = Government', 0,
           count(*) filter (where industry_key = 'GOV-OEWS' and industry_short_title <> 'Government')
    from {{ ref('mart_job_industry_mix') }}
    union all
    select 'job footer: 8 notes with a short sentence', 8, count(*) filter (where coalesce(short_text, '') <> '' and footnote_key in
           ('nyc_jobs_estimate', 'entry_wage_definition', 'ai_exposure_observed', 'escape_route', 'imputed_projection',
            'hybrid_2019', 'sources_job_summary', 'sources_job_details')) from f
    union all
    select 'job footer sentences fit one column (95 characters, D11c)', 0, count(*) filter (where length(short_text) > 95) from f
    union all
    select 'D5 note no longer says degree-holding (§3.8)', 0, count(*) filter (where footnote_text ilike '%degree-holding%')
    from {{ ref('mart_footnote') }} where footnote_key = 'd5_three_signals'
    union all
    select 'escape route note no longer says similar pay (§3.8)', 0, count(*) filter (where footnote_text ilike '%similar pay%')
    from {{ ref('mart_footnote') }} where footnote_key = 'escape_route'
)

select check_name, expected, got from checks where got is distinct from expected
union all
-- build plan §5 tie-outs
select * from (
    select '13-2011 card 3: 1 for every 6' as check_name, 1::numeric as expected,
           count(*) filter (where per_opening_key = 'one_for_every_n' and per_opening_n = 6)::numeric as got from p where soc_code = '13-2011'
    union all
    select '13-2011 majors: 1,140 (CUNY 849) count', 1,
           count(*) filter (where majors_split_key = 'split' and majors_split_n = 1140 and majors_split_n_cuny = 849) from p where soc_code = '13-2011'
    union all
    select '25-2021 card 3: 1 for every 6', 1,
           count(*) filter (where per_opening_key = 'one_for_every_n' and per_opening_n = 6) from p where soc_code = '25-2021'
    union all
    select '25-2021 majors: 626 (CUNY 450) count', 1,
           count(*) filter (where majors_split_n = 626 and majors_split_n_cuny = 450) from p where soc_code = '25-2021'
    union all
    select '13-2011 routes: Financial Examiners 25% more, Insurance Underwriters 9% less, Actuaries 50% more', 3,
           count(*) filter (where (route_rank, destination_title, pay_words) in ((1, 'Financial Examiners', 'pays 25% more'),
               (2, 'Insurance Underwriters', 'pays 9% less'), (3, 'Actuaries', 'pays 50% more'))) from r where origin_soc_code = '13-2011'
    union all
    select '13-2011 majors 1-3: Accounting, Fraud Investigation ✦, Accounting and Finance', 3,
           count(*) filter (where (major_rank_in_job, major_label_details) in ((1, 'Accounting'),
               (2, '✦ Financial Forensics and Fraud Investigation'), (3, 'Accounting and Finance'))) from m where soc_code = '13-2011'
    union all
    select '13-2011 employers 1-4: Professional services, Finance and insurance, Health care, Government', 4,
           count(*) filter (where (rank_in_job, industry_short_title) in ((1, 'Professional services'), (2, 'Finance and insurance'),
               (3, 'Health care'), (4, 'Government'))) from {{ ref('mart_job_industry_mix') }} where soc_code = '13-2011'
) as t
where got is distinct from expected
