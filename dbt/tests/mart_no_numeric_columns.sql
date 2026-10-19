-- No mart view exposes a numeric column: Power BI's PostgreSQL connector fails on numerics past .NET Decimal's
-- 28-29 significant digits, so every mart model wraps its body in mart_numeric_as_double() (macros/). One row per
-- offending column; a new mart view that forgets the wrapper fails here. The refs order it after every mart view.
-- depends_on: {{ ref('mart_ai_group_exposure') }}
-- depends_on: {{ ref('mart_bridge_industry_cluster') }}
-- depends_on: {{ ref('mart_bridge_job_cluster') }}
-- depends_on: {{ ref('mart_bridge_major_cluster') }}
-- depends_on: {{ ref('mart_dim_area') }}
-- depends_on: {{ ref('mart_dim_cluster') }}
-- depends_on: {{ ref('mart_dim_college') }}
-- depends_on: {{ ref('mart_dim_date') }}
-- depends_on: {{ ref('mart_dim_field') }}
-- depends_on: {{ ref('mart_dim_industry') }}
-- depends_on: {{ ref('mart_dim_job') }}
-- depends_on: {{ ref('mart_dim_major') }}
-- depends_on: {{ ref('mart_dim_source') }}
-- depends_on: {{ ref('mart_footnote') }}
-- depends_on: {{ ref('mart_grad_outcome_destination') }}
-- depends_on: {{ ref('mart_grad_outcome_field') }}
-- depends_on: {{ ref('mart_hottest_jobs') }}
-- depends_on: {{ ref('mart_industry_employment_monthly') }}
-- depends_on: {{ ref('mart_industry_employment_trend') }}
-- depends_on: {{ ref('mart_industry_hiring_trend') }}
-- depends_on: {{ ref('mart_industry_profile') }}
-- depends_on: {{ ref('mart_job_employment_trend') }}
-- depends_on: {{ ref('mart_job_entry_signal') }}
-- depends_on: {{ ref('mart_job_escape_route') }}
-- depends_on: {{ ref('mart_job_industry_mix') }}
-- depends_on: {{ ref('mart_job_major_link') }}
-- depends_on: {{ ref('mart_job_profile') }}
-- depends_on: {{ ref('mart_job_skill_top') }}
-- depends_on: {{ ref('mart_labor_market_monthly') }}
-- depends_on: {{ ref('mart_major_awards_trend') }}
-- depends_on: {{ ref('mart_major_supply_demand') }}
-- depends_on: {{ ref('mart_overview_kpi') }}
-- depends_on: {{ ref('mart_postings_monthly') }}
select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'mart'
  and data_type = 'numeric'
order by table_name, ordinal_position
