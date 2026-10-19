-- One-time setup of the cuny_gap database (docs/schema-design.md §1 and §7).
-- Run as the postgres superuser with psql, passing the two role passwords as variables
-- (they come from the git-ignored .env, never from this file):
--   psql -U postgres -v writer_pw="..." -v reader_pw="..." -f 00_setup_database.sql
-- Safe to re-run.

\set ON_ERROR_STOP on

-- Roles: pipeline_writer owns and builds every schema; powerbi_reader can only read mart.
SELECT format('CREATE ROLE pipeline_writer LOGIN PASSWORD %L', :'writer_pw')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'pipeline_writer') \gexec
SELECT format('CREATE ROLE powerbi_reader LOGIN PASSWORD %L', :'reader_pw')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powerbi_reader') \gexec

SELECT 'CREATE DATABASE cuny_gap OWNER pipeline_writer ENCODING ''UTF8'' TEMPLATE template0'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'cuny_gap') \gexec

\connect cuny_gap

-- Nobody but the owner creates objects in public.
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

CREATE SCHEMA IF NOT EXISTS staging AUTHORIZATION pipeline_writer;  -- loaded by notebooks
CREATE SCHEMA IF NOT EXISTS ref     AUTHORIZATION pipeline_writer;  -- hand-built tables (dbt seeds)
CREATE SCHEMA IF NOT EXISTS core    AUTHORIZATION pipeline_writer;  -- dbt: dims, bridges, facts
CREATE SCHEMA IF NOT EXISTS mart    AUTHORIZATION pipeline_writer;  -- dbt: views for Power BI

-- Power BI sees mart only, including views dbt creates later.
GRANT CONNECT ON DATABASE cuny_gap TO powerbi_reader;
GRANT USAGE ON SCHEMA mart TO powerbi_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA mart TO powerbi_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE pipeline_writer IN SCHEMA mart GRANT SELECT ON TABLES TO powerbi_reader;
