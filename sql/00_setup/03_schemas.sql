-- =============================================================================
-- sql/00_setup/03_schemas.sql
-- Purpose: Create the three MVP physical schemas within CUSTOMER360_DB
-- Administrative role required: C360_ADMIN (owns the database)
-- Idempotent: Uses IF NOT EXISTS
-- =============================================================================

USE DATABASE CUSTOMER360_DB;

-- -----------------------------------------------------------------------------
-- RAW schema — landing zone for source data (owned by DATA_ENGINEER)
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Landing zone: synthetic source data loaded as-is. Append-only by convention. Owned by C360_DATA_ENGINEER.';

GRANT OWNERSHIP ON SCHEMA RAW TO ROLE C360_DATA_ENGINEER COPY CURRENT GRANTS;

-- -----------------------------------------------------------------------------
-- ANALYTICS schema — curated, enriched, serving, and config layers collapsed
-- (owned by DATA_ENGINEER)
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS ANALYTICS
    COMMENT = 'Curated + AI-enriched + serving + config layers. Dynamic tables, enrichment results, Customer 360 view. Owned by C360_DATA_ENGINEER.';

GRANT OWNERSHIP ON SCHEMA ANALYTICS TO ROLE C360_DATA_ENGINEER COPY CURRENT GRANTS;

-- -----------------------------------------------------------------------------
-- DECISION schema — immutable audit trail (owned by C360_ADMIN)
-- DATA_ENGINEER does not own this schema to enforce separation of concerns.
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS DECISION
    COMMENT = 'Immutable decision audit: RECOMMENDATION_LOG, FOLLOW_UP_LOG, DECISION_AUDIT_EVENT, ACTION_OUTCOME. Append-only. Owned by C360_ADMIN.';

-- DECISION schema ownership stays with C360_ADMIN (not transferred to DATA_ENGINEER)
-- This prevents pipeline roles from modifying or dropping audit tables.
