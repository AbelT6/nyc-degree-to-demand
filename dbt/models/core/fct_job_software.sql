-- core.fct_job_software: O*NET Technology Skills (software products) per job, the union across the O*NET-SOC
-- profiles of the same SOC. Grain: soc_code x product.
-- Plan: docs/step4-facts-plan.md §3b (design), §4 item 8 (tests).
--
-- Staging carries the SOC of each O*NET-SOC code, so no bridge is needed (798 SOC codes, all in dim_job). When two
-- profiles of one SOC list the same product, is_hot_technology / is_in_demand are OR'd, the UNSPSC commodity is the
-- pair with the lowest commodity_id (a product is occasionally filed under two commodities), and
-- n_specialties_listing counts the profiles that list it. The 5 BLS aggregates in dim_job have no rows here (their
-- parts do); the mart unions parts if it needs them.

with src as (
    select * from {{ source('staging', 'stg_onet__software') }}
),

ranked as (
    select
        *,
        row_number() over (partition by soc_code, product order by commodity_id, commodity_title, onet_soc_code) as rn
    from src
)

select
    soc_code,
    product,
    bool_or(is_hot_technology)                                  as is_hot_technology,
    bool_or(is_in_demand)                                       as is_in_demand,
    max(commodity_id)    filter (where rn = 1)                  as commodity_id,
    max(commodity_title) filter (where rn = 1)                  as commodity_title,
    count(distinct onet_soc_code)                               as n_specialties_listing,
    max(onet_release)                                           as onet_release,
    'onet'                                                      as source_key
from ranked
group by soc_code, product
