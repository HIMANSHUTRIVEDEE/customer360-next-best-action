-- =============================================================================
-- sql/00_setup/01_roles.sql
-- Purpose: Create project roles with least-privilege design
-- Administrative role required: USERADMIN or SECURITYADMIN
-- Idempotent: Uses IF NOT EXISTS
-- =============================================================================

-- Project admin role — manages grants and masking policies
CREATE ROLE IF NOT EXISTS C360_ADMIN
    COMMENT = 'Customer360 admin: manages roles, grants, masking policies. Does not inherit data access.';

-- Data engineer role — owns pipeline, loads data, manages schemas
CREATE ROLE IF NOT EXISTS C360_DATA_ENGINEER
    COMMENT = 'Customer360 data engineer: owns RAW and ANALYTICS schemas, loads data, manages pipeline objects.';

-- Service application role — Streamlit runtime identity
CREATE ROLE IF NOT EXISTS C360_SERVICE_APP
    COMMENT = 'Customer360 service app: Streamlit owner-rights role. Reads ANALYTICS, inserts into DECISION. No DDL, no RAW access.';

-- Auditor role — read-only compliance reviewer
CREATE ROLE IF NOT EXISTS C360_AUDITOR
    COMMENT = 'Customer360 auditor: read-only access to DECISION and ANALYTICS (with masking). No write privileges anywhere.';

-- =============================================================================
-- Role hierarchy: FLAT. No functional role inherits from another.
-- C360_ADMIN does NOT receive child roles — it cannot passively inherit
-- data access. An admin must explicitly USE ROLE to assume a data role.
-- =============================================================================

-- Grant C360_ADMIN to SYSADMIN for account-level administration chain.
-- This does NOT give SYSADMIN data access (SYSADMIN must USE ROLE C360_ADMIN,
-- then USE ROLE <child> — two explicit hops, both logged in ACCESS_HISTORY).
GRANT ROLE C360_ADMIN TO ROLE SYSADMIN;

-- Functional roles are NOT granted to C360_ADMIN.
-- To manage objects as DATA_ENGINEER, an admin must: USE ROLE C360_DATA_ENGINEER.
-- This creates an auditable role-switch event and prevents privilege accumulation.

-- =============================================================================
-- Note: User-to-role assignments are NOT included here.
-- Assign roles to named users via separate operational grants:
--   GRANT ROLE C360_DATA_ENGINEER TO USER <username>;
-- This avoids hard-coded user references in version-controlled scripts.
-- =============================================================================
