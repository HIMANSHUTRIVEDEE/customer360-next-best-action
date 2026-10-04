-- =============================================================================
-- sql/01_raw/03_load_raw.sql
-- Purpose: Load generated CSVs from internal stage into RAW tables
-- Administrative role required: C360_DATA_ENGINEER (RAW schema owner)
-- Idempotent: TRUNCATE + COPY pattern ensures clean reload
-- Error handling: ON_ERROR = 'ABORT_STATEMENT' — no silent data loss
-- Pattern: Two-step load — COPY with NULL _row_hash, then UPDATE with SHA2
--          (SHA2 is not supported inside COPY INTO transformations)
-- =============================================================================

USE ROLE C360_DATA_ENGINEER;
USE DATABASE CUSTOMER360_DB;
USE SCHEMA RAW;
USE WAREHOUSE CUSTOMER360_WH;

-- =============================================================================
-- Batch identifier for this load run (timestamp-based, deterministic per run)
-- =============================================================================
SET batch_id = (SELECT 'BATCH-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD-HH24MISS'));

-- =============================================================================
-- Stage the eight approved source CSV files.
-- Windows file URIs are quoted and use forward slashes.
-- These PUT statements must be executed by a client that supports local PUT.
-- =============================================================================

PUT 'file://C:/Users/kisha/OneDrive/Desktop/coco_hack/customer360-next-best-action/data/generated/scenario_expectations.csv'
    @CUSTOMER360_DB.RAW.C360_LOAD_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT 'file://C:/Users/kisha/OneDrive/Desktop/coco_hack/customer360-next-best-action/data/generated/customers.csv'
    @CUSTOMER360_DB.RAW.C360_LOAD_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT 'file://C:/Users/kisha/OneDrive/Desktop/coco_hack/customer360-next-best-action/data/generated/policies.csv'
    @CUSTOMER360_DB.RAW.C360_LOAD_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT 'file://C:/Users/kisha/OneDrive/Desktop/coco_hack/customer360-next-best-action/data/generated/coverages.csv'
    @CUSTOMER360_DB.RAW.C360_LOAD_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT 'file://C:/Users/kisha/OneDrive/Desktop/coco_hack/customer360-next-best-action/data/generated/claims.csv'
    @CUSTOMER360_DB.RAW.C360_LOAD_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT 'file://C:/Users/kisha/OneDrive/Desktop/coco_hack/customer360-next-best-action/data/generated/payments.csv'
    @CUSTOMER360_DB.RAW.C360_LOAD_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT 'file://C:/Users/kisha/OneDrive/Desktop/coco_hack/customer360-next-best-action/data/generated/interactions.csv'
    @CUSTOMER360_DB.RAW.C360_LOAD_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT 'file://C:/Users/kisha/OneDrive/Desktop/coco_hack/customer360-next-best-action/data/generated/transcripts.csv'
    @CUSTOMER360_DB.RAW.C360_LOAD_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- Confirm staged files before any table is truncated or loaded.
LIST @CUSTOMER360_DB.RAW.C360_LOAD_STAGE;

-- =============================================================================
-- 1. RAW_SERVICE_REPRESENTATIVES
-- =============================================================================
TRUNCATE TABLE IF EXISTS RAW_SERVICE_REPRESENTATIVES;

COPY INTO RAW_SERVICE_REPRESENTATIVES (
    representative_id, name, role, active, team,
    _loaded_at, _source_file, _batch_id, _row_hash
)
FROM (
    SELECT
        $1,                                     -- representative_id
        $2,                                     -- name
        $3,                                     -- role
        $4,                                     -- active
        $5,                                     -- team
        CURRENT_TIMESTAMP(),                    -- _loaded_at
        METADATA$FILENAME,                      -- _source_file
        $batch_id,                              -- _batch_id
        NULL                                    -- _row_hash (populated by UPDATE below)
    FROM @C360_LOAD_STAGE/service_representatives.csv
)
ON_ERROR = 'ABORT_STATEMENT'
PURGE = FALSE;

UPDATE RAW_SERVICE_REPRESENTATIVES
SET _row_hash = SHA2(CONCAT_WS('|', representative_id, name, role, active, NVL(team, '')), 256)
WHERE _row_hash IS NULL;

SELECT 'RAW_SERVICE_REPRESENTATIVES' AS table_name,
       COUNT(*) AS rows_loaded,
       COUNT(*) - COUNT(_row_hash) AS null_hashes,
       CASE WHEN COUNT(*) = 5 AND COUNT(*) - COUNT(_row_hash) = 0
                 AND MIN(LENGTH(_row_hash)) = 64 THEN 'PASS' ELSE 'FAIL' END AS status
FROM RAW_SERVICE_REPRESENTATIVES;

-- =============================================================================
-- 2. RAW_CUSTOMERS
-- =============================================================================
TRUNCATE TABLE IF EXISTS RAW_CUSTOMERS;

COPY INTO RAW_CUSTOMERS (
    customer_id, household_id, first_name, last_name, customer_since, status,
    date_of_birth, email, phone, address_line_1, city, state, postal_code,
    _loaded_at, _source_file, _batch_id, _row_hash
)
FROM (
    SELECT
        $1,                                     -- customer_id
        $2,                                     -- household_id
        $3,                                     -- first_name
        $4,                                     -- last_name
        $5,                                     -- customer_since
        $6,                                     -- status
        $7,                                     -- date_of_birth
        $8,                                     -- email
        $9,                                     -- phone
        $10,                                    -- address_line_1
        $11,                                    -- city
        $12,                                    -- state
        $13,                                    -- postal_code
        CURRENT_TIMESTAMP(),                    -- _loaded_at
        METADATA$FILENAME,                      -- _source_file
        $batch_id,                              -- _batch_id
        NULL                                    -- _row_hash (populated by UPDATE below)
    FROM @C360_LOAD_STAGE/customers.csv
)
ON_ERROR = 'ABORT_STATEMENT'
PURGE = FALSE;

UPDATE RAW_CUSTOMERS
SET _row_hash = SHA2(CONCAT_WS('|', customer_id, household_id, first_name, last_name,
    customer_since, status, NVL(TO_VARCHAR(date_of_birth), ''), NVL(email, ''),
    NVL(phone, ''), address_line_1, city, state, postal_code), 256)
WHERE _row_hash IS NULL;

SELECT 'RAW_CUSTOMERS' AS table_name,
       COUNT(*) AS rows_loaded,
       COUNT(*) - COUNT(_row_hash) AS null_hashes,
       CASE WHEN COUNT(*) = 100 AND COUNT(*) - COUNT(_row_hash) = 0
                 AND MIN(LENGTH(_row_hash)) = 64 THEN 'PASS' ELSE 'FAIL' END AS status
FROM RAW_CUSTOMERS;

-- =============================================================================
-- 3. RAW_POLICIES
-- =============================================================================
TRUNCATE TABLE IF EXISTS RAW_POLICIES;

COPY INTO RAW_POLICIES (
    policy_id, customer_id, product_type, status, effective_date, expiration_date,
    premium_amount, payment_frequency, bound_date,
    _loaded_at, _source_file, _batch_id, _row_hash
)
FROM (
    SELECT
        $1,                                     -- policy_id
        $2,                                     -- customer_id
        $3,                                     -- product_type
        $4,                                     -- status
        $5,                                     -- effective_date
        $6,                                     -- expiration_date
        $7,                                     -- premium_amount
        $8,                                     -- payment_frequency
        $9,                                     -- bound_date
        CURRENT_TIMESTAMP(),                    -- _loaded_at
        METADATA$FILENAME,                      -- _source_file
        $batch_id,                              -- _batch_id
        NULL                                    -- _row_hash (populated by UPDATE below)
    FROM @C360_LOAD_STAGE/policies.csv
)
ON_ERROR = 'ABORT_STATEMENT'
PURGE = FALSE;

UPDATE RAW_POLICIES
SET _row_hash = SHA2(CONCAT_WS('|', policy_id, customer_id, product_type, status,
    effective_date, expiration_date, premium_amount, payment_frequency,
    NVL(TO_VARCHAR(bound_date), '')), 256)
WHERE _row_hash IS NULL;

SELECT 'RAW_POLICIES' AS table_name,
       COUNT(*) AS rows_loaded,
       COUNT(*) - COUNT(_row_hash) AS null_hashes,
       CASE WHEN COUNT(*) = 250 AND COUNT(*) - COUNT(_row_hash) = 0
                 AND MIN(LENGTH(_row_hash)) = 64 THEN 'PASS' ELSE 'FAIL' END AS status
FROM RAW_POLICIES;

-- =============================================================================
-- 4. RAW_COVERAGES
-- =============================================================================
TRUNCATE TABLE IF EXISTS RAW_COVERAGES;

COPY INTO RAW_COVERAGES (
    coverage_id, policy_id, coverage_type, limit_amount, deductible_amount,
    _loaded_at, _source_file, _batch_id, _row_hash
)
FROM (
    SELECT
        $1,                                     -- coverage_id
        $2,                                     -- policy_id
        $3,                                     -- coverage_type
        $4,                                     -- limit_amount
        $5,                                     -- deductible_amount
        CURRENT_TIMESTAMP(),                    -- _loaded_at
        METADATA$FILENAME,                      -- _source_file
        $batch_id,                              -- _batch_id
        NULL                                    -- _row_hash (populated by UPDATE below)
    FROM @C360_LOAD_STAGE/coverages.csv
)
ON_ERROR = 'ABORT_STATEMENT'
PURGE = FALSE;

UPDATE RAW_COVERAGES
SET _row_hash = SHA2(CONCAT_WS('|', coverage_id, policy_id, coverage_type,
    limit_amount, deductible_amount), 256)
WHERE _row_hash IS NULL;

SELECT 'RAW_COVERAGES' AS table_name,
       COUNT(*) AS rows_loaded,
       COUNT(*) - COUNT(_row_hash) AS null_hashes,
       CASE WHEN COUNT(*) = 565 AND COUNT(*) - COUNT(_row_hash) = 0
                 AND MIN(LENGTH(_row_hash)) = 64 THEN 'PASS' ELSE 'FAIL' END AS status
FROM RAW_COVERAGES;

-- =============================================================================
-- 5. RAW_CLAIMS
-- =============================================================================
TRUNCATE TABLE IF EXISTS RAW_CLAIMS;

COPY INTO RAW_CLAIMS (
    claim_id, policy_id, customer_id, filed_date, status, loss_date, loss_type,
    reserve_amount, paid_amount, closed_date,
    _loaded_at, _source_file, _batch_id, _row_hash
)
FROM (
    SELECT
        $1,                                     -- claim_id
        $2,                                     -- policy_id
        $3,                                     -- customer_id
        $4,                                     -- filed_date
        $5,                                     -- status
        $6,                                     -- loss_date
        $7,                                     -- loss_type
        $8,                                     -- reserve_amount
        $9,                                     -- paid_amount
        $10,                                    -- closed_date
        CURRENT_TIMESTAMP(),                    -- _loaded_at
        METADATA$FILENAME,                      -- _source_file
        $batch_id,                              -- _batch_id
        NULL                                    -- _row_hash (populated by UPDATE below)
    FROM @C360_LOAD_STAGE/claims.csv
)
ON_ERROR = 'ABORT_STATEMENT'
PURGE = FALSE;

UPDATE RAW_CLAIMS
SET _row_hash = SHA2(CONCAT_WS('|', claim_id, policy_id, customer_id, filed_date,
    status, loss_date, loss_type, NVL(TO_VARCHAR(reserve_amount), ''),
    NVL(TO_VARCHAR(paid_amount), ''), NVL(TO_VARCHAR(closed_date), '')), 256)
WHERE _row_hash IS NULL;

SELECT 'RAW_CLAIMS' AS table_name,
       COUNT(*) AS rows_loaded,
       COUNT(*) - COUNT(_row_hash) AS null_hashes,
       CASE WHEN COUNT(*) = 30 AND COUNT(*) - COUNT(_row_hash) = 0
                 AND MIN(LENGTH(_row_hash)) = 64 THEN 'PASS' ELSE 'FAIL' END AS status
FROM RAW_CLAIMS;

-- =============================================================================
-- 6. RAW_PAYMENTS
-- =============================================================================
TRUNCATE TABLE IF EXISTS RAW_PAYMENTS;

COPY INTO RAW_PAYMENTS (
    payment_id, customer_id, policy_id, due_date, amount, status, paid_date, amount_paid,
    _loaded_at, _source_file, _batch_id, _row_hash
)
FROM (
    SELECT
        $1,                                     -- payment_id
        $2,                                     -- customer_id
        $3,                                     -- policy_id
        $4,                                     -- due_date
        $5,                                     -- amount
        $6,                                     -- status
        $7,                                     -- paid_date
        $8,                                     -- amount_paid
        CURRENT_TIMESTAMP(),                    -- _loaded_at
        METADATA$FILENAME,                      -- _source_file
        $batch_id,                              -- _batch_id
        NULL                                    -- _row_hash (populated by UPDATE below)
    FROM @C360_LOAD_STAGE/payments.csv
)
ON_ERROR = 'ABORT_STATEMENT'
PURGE = FALSE;

UPDATE RAW_PAYMENTS
SET _row_hash = SHA2(CONCAT_WS('|', payment_id, customer_id, policy_id, due_date,
    amount, status, NVL(TO_VARCHAR(paid_date), ''), NVL(TO_VARCHAR(amount_paid), '')), 256)
WHERE _row_hash IS NULL;

SELECT 'RAW_PAYMENTS' AS table_name,
       COUNT(*) AS rows_loaded,
       COUNT(*) - COUNT(_row_hash) AS null_hashes,
       CASE WHEN COUNT(*) = 669 AND COUNT(*) - COUNT(_row_hash) = 0
                 AND MIN(LENGTH(_row_hash)) = 64 THEN 'PASS' ELSE 'FAIL' END AS status
FROM RAW_PAYMENTS;

-- =============================================================================
-- 7. RAW_INTERACTIONS
-- =============================================================================
TRUNCATE TABLE IF EXISTS RAW_INTERACTIONS;

COPY INTO RAW_INTERACTIONS (
    interaction_id, customer_id, channel, direction, disposition, interaction_date,
    duration_seconds, representative_id,
    _loaded_at, _source_file, _batch_id, _row_hash
)
FROM (
    SELECT
        $1,                                     -- interaction_id
        $2,                                     -- customer_id
        $3,                                     -- channel
        $4,                                     -- direction
        $5,                                     -- disposition
        $6,                                     -- interaction_date
        $7,                                     -- duration_seconds
        $8,                                     -- representative_id
        CURRENT_TIMESTAMP(),                    -- _loaded_at
        METADATA$FILENAME,                      -- _source_file
        $batch_id,                              -- _batch_id
        NULL                                    -- _row_hash (populated by UPDATE below)
    FROM @C360_LOAD_STAGE/interactions.csv
)
ON_ERROR = 'ABORT_STATEMENT'
PURGE = FALSE;

UPDATE RAW_INTERACTIONS
SET _row_hash = SHA2(CONCAT_WS('|', interaction_id, customer_id, channel, direction,
    disposition, interaction_date, NVL(TO_VARCHAR(duration_seconds), ''),
    NVL(representative_id, '')), 256)
WHERE _row_hash IS NULL;

SELECT 'RAW_INTERACTIONS' AS table_name,
       COUNT(*) AS rows_loaded,
       COUNT(*) - COUNT(_row_hash) AS null_hashes,
       CASE WHEN COUNT(*) = 200 AND COUNT(*) - COUNT(_row_hash) = 0
                 AND MIN(LENGTH(_row_hash)) = 64 THEN 'PASS' ELSE 'FAIL' END AS status
FROM RAW_INTERACTIONS;

-- =============================================================================
-- 8. RAW_TRANSCRIPTS
-- =============================================================================
TRUNCATE TABLE IF EXISTS RAW_TRANSCRIPTS;

COPY INTO RAW_TRANSCRIPTS (
    transcript_id, interaction_id, content_type, raw_text, word_count, recording_consent_flag,
    _loaded_at, _source_file, _batch_id, _row_hash
)
FROM (
    SELECT
        $1,                                     -- transcript_id
        $2,                                     -- interaction_id
        $3,                                     -- content_type
        $4,                                     -- raw_text
        $5,                                     -- word_count
        $6,                                     -- recording_consent_flag
        CURRENT_TIMESTAMP(),                    -- _loaded_at
        METADATA$FILENAME,                      -- _source_file
        $batch_id,                              -- _batch_id
        NULL                                    -- _row_hash (populated by UPDATE below)
    FROM @C360_LOAD_STAGE/transcripts.csv
)
ON_ERROR = 'ABORT_STATEMENT'
PURGE = FALSE;

UPDATE RAW_TRANSCRIPTS
SET _row_hash = SHA2(CONCAT_WS('|', transcript_id, interaction_id, content_type,
    raw_text, word_count, recording_consent_flag), 256)
WHERE _row_hash IS NULL;

SELECT 'RAW_TRANSCRIPTS' AS table_name,
       COUNT(*) AS rows_loaded,
       COUNT(*) - COUNT(_row_hash) AS null_hashes,
       CASE WHEN COUNT(*) = 50 AND COUNT(*) - COUNT(_row_hash) = 0
                 AND MIN(LENGTH(_row_hash)) = 64 THEN 'PASS' ELSE 'FAIL' END AS status
FROM RAW_TRANSCRIPTS;

-- =============================================================================
-- Load summary
-- =============================================================================
SELECT 'LOAD COMPLETE' AS status, $batch_id AS batch_id, CURRENT_TIMESTAMP() AS completed_at;
