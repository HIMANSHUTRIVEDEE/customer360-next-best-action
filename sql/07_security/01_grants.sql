-- =============================================================================
-- sql/07_security/01_grants.sql
-- Purpose: Least-privilege grants for all four roles
-- Administrative role required: C360_ADMIN (or SECURITYADMIN for role grants)
-- Idempotent: GRANT statements are idempotent in Snowflake (re-granting is a no-op)
-- =============================================================================

USE DATABASE CUSTOMER360_DB;

-- =============================================================================
-- WAREHOUSE USAGE
-- =============================================================================

-- DATA_ENGINEER: needs OPERATE for pipeline refresh + USAGE for queries
GRANT USAGE ON WAREHOUSE CUSTOMER360_WH TO ROLE C360_DATA_ENGINEER;
GRANT OPERATE ON WAREHOUSE CUSTOMER360_WH TO ROLE C360_DATA_ENGINEER;

-- SERVICE_APP: needs USAGE for application queries only (no OPERATE)
GRANT USAGE ON WAREHOUSE CUSTOMER360_WH TO ROLE C360_SERVICE_APP;

-- AUDITOR: needs USAGE for read-only queries
GRANT USAGE ON WAREHOUSE CUSTOMER360_WH TO ROLE C360_AUDITOR;

-- =============================================================================
-- DATABASE-LEVEL GRANTS
-- =============================================================================

GRANT USAGE ON DATABASE CUSTOMER360_DB TO ROLE C360_DATA_ENGINEER;
GRANT USAGE ON DATABASE CUSTOMER360_DB TO ROLE C360_SERVICE_APP;
GRANT USAGE ON DATABASE CUSTOMER360_DB TO ROLE C360_AUDITOR;

-- =============================================================================
-- RAW SCHEMA — C360_DATA_ENGINEER: full control (owner)
--              All other roles: NO ACCESS
-- =============================================================================

-- DATA_ENGINEER owns RAW (granted in 03_schemas.sql), so has all privileges implicitly.
-- Explicit USAGE grant for defense-in-depth (survives ownership edge cases):
GRANT USAGE ON SCHEMA RAW TO ROLE C360_DATA_ENGINEER;

-- Owner-implicit privileges cover tables, stages, file formats.
-- No additional ALL PRIVILEGES grants needed — ownership is sufficient.

-- SERVICE_APP: explicitly NO grants on RAW (cannot read or write source data)
-- AUDITOR: explicitly NO grants on RAW (no access to raw landing zone)
-- (No GRANT statements = no access. Snowflake deny-by-default.)

-- =============================================================================
-- ANALYTICS SCHEMA — C360_DATA_ENGINEER: full control (owner)
--                    C360_SERVICE_APP: SELECT only (future tables/views/DTs)
--                    C360_AUDITOR: SELECT only (future tables/views/DTs, with masking)
-- =============================================================================

-- DATA_ENGINEER owns ANALYTICS, has full implicit privileges.

-- SERVICE_APP: read-only on ANALYTICS objects
GRANT USAGE ON SCHEMA ANALYTICS TO ROLE C360_SERVICE_APP;
GRANT SELECT ON ALL TABLES IN SCHEMA ANALYTICS TO ROLE C360_SERVICE_APP;
GRANT SELECT ON FUTURE TABLES IN SCHEMA ANALYTICS TO ROLE C360_SERVICE_APP;
GRANT SELECT ON ALL VIEWS IN SCHEMA ANALYTICS TO ROLE C360_SERVICE_APP;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA ANALYTICS TO ROLE C360_SERVICE_APP;
GRANT SELECT ON ALL DYNAMIC TABLES IN SCHEMA ANALYTICS TO ROLE C360_SERVICE_APP;
GRANT SELECT ON FUTURE DYNAMIC TABLES IN SCHEMA ANALYTICS TO ROLE C360_SERVICE_APP;

-- AUDITOR: read-only on ANALYTICS (masking policies will restrict PII columns)
GRANT USAGE ON SCHEMA ANALYTICS TO ROLE C360_AUDITOR;
GRANT SELECT ON ALL TABLES IN SCHEMA ANALYTICS TO ROLE C360_AUDITOR;
GRANT SELECT ON FUTURE TABLES IN SCHEMA ANALYTICS TO ROLE C360_AUDITOR;
GRANT SELECT ON ALL VIEWS IN SCHEMA ANALYTICS TO ROLE C360_AUDITOR;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA ANALYTICS TO ROLE C360_AUDITOR;
GRANT SELECT ON ALL DYNAMIC TABLES IN SCHEMA ANALYTICS TO ROLE C360_AUDITOR;
GRANT SELECT ON FUTURE DYNAMIC TABLES IN SCHEMA ANALYTICS TO ROLE C360_AUDITOR;

-- AUDITOR: MONITOR on dynamic tables for pipeline health visibility
-- (Requires MONITOR privilege — granted on future DTs)
GRANT MONITOR ON ALL DYNAMIC TABLES IN SCHEMA ANALYTICS TO ROLE C360_AUDITOR;
GRANT MONITOR ON FUTURE DYNAMIC TABLES IN SCHEMA ANALYTICS TO ROLE C360_AUDITOR;

-- =============================================================================
-- DECISION SCHEMA — C360_ADMIN: owner (full control)
--                   C360_SERVICE_APP: INSERT on specific tables (append-only)
--                   C360_AUDITOR: SELECT only (full read)
--                   C360_DATA_ENGINEER: NO ACCESS
-- =============================================================================

-- SERVICE_APP: can use schema and insert into decision tables (append-only)
GRANT USAGE ON SCHEMA DECISION TO ROLE C360_SERVICE_APP;
GRANT SELECT ON ALL TABLES IN SCHEMA DECISION TO ROLE C360_SERVICE_APP;
GRANT SELECT ON FUTURE TABLES IN SCHEMA DECISION TO ROLE C360_SERVICE_APP;
GRANT INSERT ON ALL TABLES IN SCHEMA DECISION TO ROLE C360_SERVICE_APP;
GRANT INSERT ON FUTURE TABLES IN SCHEMA DECISION TO ROLE C360_SERVICE_APP;
-- NOTE: No UPDATE or DELETE granted. DECISION is append-only for SERVICE_APP.
-- NOTE: SELECT grants full read on all DECISION records. Production would add
--       row-level security to restrict SERVICE_APP to own-session records only.
--       RLS is documented as a production enhancement (architecture.md §14).

-- AUDITOR: read-only on all DECISION tables
GRANT USAGE ON SCHEMA DECISION TO ROLE C360_AUDITOR;
GRANT SELECT ON ALL TABLES IN SCHEMA DECISION TO ROLE C360_AUDITOR;
GRANT SELECT ON FUTURE TABLES IN SCHEMA DECISION TO ROLE C360_AUDITOR;

-- DATA_ENGINEER: explicitly NO grants on DECISION schema
-- (No GRANT = no access. DATA_ENGINEER cannot read or write audit records.)

-- =============================================================================
-- EXPLICIT PROHIBITIONS (documented, not DENY statements — Snowflake is deny-by-default)
-- =============================================================================
-- The following are NOT granted and rely on Snowflake's deny-by-default model:
--
-- C360_SERVICE_APP:
--   • No SELECT/INSERT on RAW.* (no USAGE on RAW schema)
--   • No CREATE/ALTER/DROP anywhere (no DDL grants)
--   • No UPDATE/DELETE on DECISION.* (only INSERT granted)
--   • No OPERATE on warehouse (cannot suspend/resume)
--
-- C360_AUDITOR:
--   • No INSERT/UPDATE/DELETE anywhere (only SELECT granted)
--   • No DDL anywhere
--   • No access to RAW schema (no USAGE granted)
--
-- C360_DATA_ENGINEER:
--   • No SELECT/INSERT on DECISION.* (no USAGE on DECISION schema)
--   • Cannot impersonate SERVICE_APP (no GRANT ROLE statement)
--
-- These are enforced by absence of grants and validated by security tests T1-T7.

-- =============================================================================
-- REVOKE any unintended PUBLIC grants (defense in depth)
-- =============================================================================
REVOKE ALL PRIVILEGES ON DATABASE CUSTOMER360_DB FROM ROLE PUBLIC;
REVOKE ALL PRIVILEGES ON SCHEMA RAW FROM ROLE PUBLIC;
REVOKE ALL PRIVILEGES ON SCHEMA ANALYTICS FROM ROLE PUBLIC;
REVOKE ALL PRIVILEGES ON SCHEMA DECISION FROM ROLE PUBLIC;
REVOKE USAGE ON WAREHOUSE CUSTOMER360_WH FROM ROLE PUBLIC;
