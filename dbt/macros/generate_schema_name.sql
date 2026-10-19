-- Use the schema names from dbt_project.yml as-is (core, mart, ref) instead of dbt's
-- default "<target schema>_<custom schema>" (core_mart ...). Pattern from the dbt docs:
-- https://docs.getdbt.com/docs/build/custom-schemas
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}{{ target.schema }}{%- else -%}{{ custom_schema_name | trim }}{%- endif -%}
{%- endmacro %}
