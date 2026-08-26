-- =============================================================================
-- sql/00_setup/02_database_warehouse.sql
-- Purpose: Create project database and warehouse
-- Administrative role required: SYSADMIN (or ACCOUNTADMIN)
-- Idempotent: Uses IF NOT EXISTS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Database
-- -----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS CUSTOMER360_DB
    COMMENT = 'Customer 360 and Next Best Action prototype. Synthetic data only. Hackathon scope.';

-- -----------------------------------------------------------------------------
-- Warehouse — X-Small for development; auto-suspend after 60 seconds
-- -----------------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS CUSTOMER360_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 300
    COMMENT = 'Customer360 compute. XS for prototype. Auto-suspend 60s. Statement timeout 5 min cost guard.';

-- -----------------------------------------------------------------------------
-- Transfer ownership to C360_ADMIN for ongoing management
-- -----------------------------------------------------------------------------
GRANT OWNERSHIP ON DATABASE CUSTOMER360_DB TO ROLE C360_ADMIN COPY CURRENT GRANTS;
GRANT OWNERSHIP ON WAREHOUSE CUSTOMER360_WH TO ROLE C360_ADMIN COPY CURRENT GRANTS;
