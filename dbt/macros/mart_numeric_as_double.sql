-- Wrap a mart model's body in a call block of this macro (call mart_numeric_as_double() ... endcall): every numeric output column
-- leaves the view as double precision, every other column passes through unchanged, in the same order.
-- Why: Postgres numeric division keeps 20 to 400 digits (job_profile.annual_openings_avg had 195), and Power BI's
-- PostgreSQL connector reads numeric through .NET Decimal (28-29 significant digits), failing the refresh with
-- "Numeric value does not fit in a System.Decimal". Power BI stores Decimal Number as a double anyway (15-17
-- significant digits), so the cast loses nothing a report can show. tests/mart_no_numeric_columns.sql enforces it.
-- The column types come from adapter.get_column_schema_from_query (dbt >= 1.5), which runs the body with `where false`;
-- dbt-postgres names numeric 'DECIMAL' (psycopg2's type name), so both spellings match.
{% macro mart_numeric_as_double() -%}
    {%- set body = caller() -%}
    {%- if execute -%}
        {%- set columns = adapter.get_column_schema_from_query(body) -%}
select
    {%- for c in columns %}
    {% if c.dtype | lower in ('numeric', 'decimal') -%}
        {{ adapter.quote(c.name) }}::double precision as {{ adapter.quote(c.name) }}
    {%- else -%}
        {{ adapter.quote(c.name) }}
    {%- endif %}{{ ',' if not loop.last }}
    {%- endfor %}
from (
{{ body }}
) as mart_body
    {%- else -%}
{{ body }}
    {%- endif -%}
{%- endmacro %}
