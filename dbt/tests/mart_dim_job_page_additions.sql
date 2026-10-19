-- mart.dim_job job page additions (page 3 build plan §3.7, §4 item 4, §6; D29, D32): job_label and job_description on
-- exactly the 225 job-page rows, the label's marks equal job_profile's flags, the description rule and its counts,
-- and the 260-character limit. Returns one row per failed check.
with d as (
    select * from {{ ref('mart_dim_job') }}
),

p as (
    select * from {{ ref('mart_job_profile') }}
),

dp as (
    select d.*, p.is_all_other as p_is_all_other, coalesce(p.is_imputed, false) as p_is_imputed, p.split_2019 as p_split_2019
    from d join p using (soc_code)
),

seed as (
    select * from {{ ref('ref_job_description_override') }}
),

ooh as (
    select * from {{ source('staging', 'stg_bls__ooh_description') }}
),

checks as (
    select 'job_label filled on 225 rows' as check_name, 225 as expected, count(job_label)::int as got from d
    union all
    select 'every job_profile row has a job_label', 0, count(*) filter (where job_label is null)::int from dp
    union all
    select 'no job_label outside job_profile', 0, count(*)::int from d where job_label is not null and soc_code not in (select soc_code from p)
    union all
    select 'job_label = display title + marks', 0, count(*) filter (where job_label is distinct from
           soc_short_title || case when p_is_imputed or p_split_2019 then ' ' else '' end
           || case when p_is_imputed then '°' else '' end || case when p_split_2019 then '◆' else '' end)::int from dp
    union all
    select 'named jobs with ° = 18 (design brief §11.3)', 18, count(*) filter (where job_label like '%°%' and not p_is_all_other)::int from dp
    union all
    select 'named jobs with ◆ = 16', 16, count(*) filter (where job_label like '%◆%' and not p_is_all_other)::int from dp
    union all
    select 'named jobs with both = 14', 14, count(*) filter (where job_label like '%°◆' and not p_is_all_other)::int from dp
    union all
    select 'Software Developers carry both marks', 1, count(*) filter (where job_label = 'Software Developers °◆')::int from d where soc_code = '15-1252'
    union all
    select 'job_description on 225 rows', 225, count(job_description)::int from d
    union all
    select 'job_description at most 260 characters (D32)', 0, count(*) filter (where length(job_description) > 260)::int from d
    union all
    select 'description_basis ooh_own_profile = 124', 124, count(*) filter (where description_basis = 'ooh_own_profile')::int from d
    union all
    select 'description_basis ooh_shared_profile = 47', 47, count(*) filter (where description_basis = 'ooh_shared_profile')::int from d
    union all
    select 'description_basis ooh_profile_part = 9', 9, count(*) filter (where description_basis = 'ooh_profile_part')::int from d
    union all
    select 'description_basis ooh_type_sentence = 7', 7, count(*) filter (where description_basis = 'ooh_type_sentence')::int from d
    union all
    select 'description_basis onet_first_sentence = 12', 12, count(*) filter (where description_basis = 'onet_first_sentence')::int from d
    union all
    select 'description_basis onet_all_other = 23', 23, count(*) filter (where description_basis = 'onet_all_other')::int from d
    union all
    select 'description_basis shortened_to_fit = 3 (sweep)', 3, count(*) filter (where description_basis = 'shortened_to_fit')::int from d
    union all
    select 'shortened lines are the start of the source''s own text', 0, count(*)::int
    from seed join d using (soc_code)
    left join ooh using (soc_code)
    left join {{ source('staging', 'stg_onet__occupation') }} as o on o.onet_soc_code = seed.soc_code || '.00'
    where seed.verdict = 'shortened'
      and (d.job_description is distinct from seed.description
           or left(coalesce(ooh.description, o.description), length(trim(trailing '.' from seed.description)))
              is distinct from trim(trailing '.' from seed.description))
    union all
    select 'seed replacements used word for word', 0, count(*)::int
    from seed join d using (soc_code)
    where seed.verdict in ('profile_part', 'bls_type', 'shortened') and d.job_description is distinct from seed.description
    union all
    select 'own and kept profiles use the OOH sentence', 0, count(*)::int
    from d join ooh using (soc_code)
    where d.description_basis in ('ooh_own_profile', 'ooh_shared_profile') and d.job_description is distinct from ooh.description
    union all
    select 'every named job with an OOH profile uses BLS', 0, count(*)::int
    from dp join ooh using (soc_code)
    where not dp.p_is_all_other and dp.description_source <> 'bls_ooh'
    union all
    select '13-2011 description (build plan §5)', 1,
           count(*) filter (where job_description = 'Accountants and auditors prepare and examine financial records.')::int
    from d where soc_code = '13-2011'
    union all
    select '33-3031 no longer gets the police sentence', 0, count(*) filter (where job_description ilike 'police%')::int
    from d where soc_code = '33-3031'
)

select * from checks where got is distinct from expected
