-- =============================================================================
-- sql/01_raw/04_reconciliation.sql
-- Purpose: Source-to-target reconciliation after RAW load
-- Administrative role required: C360_DATA_ENGINEER
-- Run after: 03_load_raw.sql completes successfully
--
-- Behavior:
--   - Compares expected row counts (from manifest.json) to actual table counts
--   - Checks for primary key duplicates
--   - Checks referential integrity across tables
--   - Checks for rejected rows (COPY_HISTORY)
--   - Returns PASS/FAIL for each check
--   - Does NOT silently repair failures
-- =============================================================================

USE DATABASE CUSTOMER360_DB;
USE SCHEMA RAW;
USE WAREHOUSE CUSTOMER360_WH;

-- =============================================================================
-- 1. ROW COUNT RECONCILIATION
-- Expected counts from manifest (hardcoded from generation; update if regenerated):
--   service_representatives: 5
--   customers: 100
--   policies: 250
--   coverages: 565
--   claims: 30
--   payments: 669
--   interactions: 200
--   transcripts: 50
-- =============================================================================

SELECT
    'ROW_COUNT_CHECK' AS check_type,
    table_name,
    expected_count,
    actual_count,
    CASE WHEN actual_count = expected_count THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    SELECT 'RAW_SERVICE_REPRESENTATIVES' AS table_name, 5 AS expected_count,
           (SELECT COUNT(*) FROM RAW_SERVICE_REPRESENTATIVES) AS actual_count
    UNION ALL
    SELECT 'RAW_CUSTOMERS', 100,
           (SELECT COUNT(*) FROM RAW_CUSTOMERS)
    UNION ALL
    SELECT 'RAW_POLICIES', 250,
           (SELECT COUNT(*) FROM RAW_POLICIES)
    UNION ALL
    SELECT 'RAW_COVERAGES', 565,
           (SELECT COUNT(*) FROM RAW_COVERAGES)
    UNION ALL
    SELECT 'RAW_CLAIMS', 30,
           (SELECT COUNT(*) FROM RAW_CLAIMS)
    UNION ALL
    SELECT 'RAW_PAYMENTS', 669,
           (SELECT COUNT(*) FROM RAW_PAYMENTS)
    UNION ALL
    SELECT 'RAW_INTERACTIONS', 200,
           (SELECT COUNT(*) FROM RAW_INTERACTIONS)
    UNION ALL
    SELECT 'RAW_TRANSCRIPTS', 50,
           (SELECT COUNT(*) FROM RAW_TRANSCRIPTS)
);

-- =============================================================================
-- 2. PRIMARY KEY UNIQUENESS
-- =============================================================================

SELECT
    'PK_UNIQUENESS' AS check_type,
    table_name,
    pk_column,
    total_rows,
    distinct_keys,
    CASE WHEN total_rows = distinct_keys THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    SELECT 'RAW_CUSTOMERS' AS table_name, 'customer_id' AS pk_column,
           COUNT(*) AS total_rows, COUNT(DISTINCT customer_id) AS distinct_keys
    FROM RAW_CUSTOMERS
    UNION ALL
    SELECT 'RAW_POLICIES', 'policy_id',
           COUNT(*), COUNT(DISTINCT policy_id)
    FROM RAW_POLICIES
    UNION ALL
    SELECT 'RAW_COVERAGES', 'coverage_id',
           COUNT(*), COUNT(DISTINCT coverage_id)
    FROM RAW_COVERAGES
    UNION ALL
    SELECT 'RAW_CLAIMS', 'claim_id',
           COUNT(*), COUNT(DISTINCT claim_id)
    FROM RAW_CLAIMS
    UNION ALL
    SELECT 'RAW_PAYMENTS', 'payment_id',
           COUNT(*), COUNT(DISTINCT payment_id)
    FROM RAW_PAYMENTS
    UNION ALL
    SELECT 'RAW_INTERACTIONS', 'interaction_id',
           COUNT(*), COUNT(DISTINCT interaction_id)
    FROM RAW_INTERACTIONS
    UNION ALL
    SELECT 'RAW_TRANSCRIPTS', 'transcript_id',
           COUNT(*), COUNT(DISTINCT transcript_id)
    FROM RAW_TRANSCRIPTS
    UNION ALL
    SELECT 'RAW_SERVICE_REPRESENTATIVES', 'representative_id',
           COUNT(*), COUNT(DISTINCT representative_id)
    FROM RAW_SERVICE_REPRESENTATIVES
);

-- =============================================================================
-- 3. FOREIGN KEY REFERENTIAL INTEGRITY
-- =============================================================================

SELECT
    'FK_INTEGRITY' AS check_type,
    relationship,
    orphan_count,
    CASE WHEN orphan_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    -- policies.customer_id → customers
    SELECT 'policies.customer_id → customers' AS relationship,
           COUNT(*) AS orphan_count
    FROM RAW_POLICIES p
    WHERE NOT EXISTS (SELECT 1 FROM RAW_CUSTOMERS c WHERE c.customer_id = p.customer_id)

    UNION ALL
    -- coverages.policy_id → policies
    SELECT 'coverages.policy_id → policies',
           COUNT(*)
    FROM RAW_COVERAGES cv
    WHERE NOT EXISTS (SELECT 1 FROM RAW_POLICIES p WHERE p.policy_id = cv.policy_id)

    UNION ALL
    -- claims.policy_id → policies
    SELECT 'claims.policy_id → policies',
           COUNT(*)
    FROM RAW_CLAIMS cl
    WHERE NOT EXISTS (SELECT 1 FROM RAW_POLICIES p WHERE p.policy_id = cl.policy_id)

    UNION ALL
    -- claims.customer_id → customers
    SELECT 'claims.customer_id → customers',
           COUNT(*)
    FROM RAW_CLAIMS cl
    WHERE NOT EXISTS (SELECT 1 FROM RAW_CUSTOMERS c WHERE c.customer_id = cl.customer_id)

    UNION ALL
    -- claims ownership: customer matches policy owner
    SELECT 'claims.customer_id matches policy owner',
           COUNT(*)
    FROM RAW_CLAIMS cl
    JOIN RAW_POLICIES p ON cl.policy_id = p.policy_id
    WHERE cl.customer_id != p.customer_id

    UNION ALL
    -- payments.customer_id → customers
    SELECT 'payments.customer_id → customers',
           COUNT(*)
    FROM RAW_PAYMENTS pay
    WHERE NOT EXISTS (SELECT 1 FROM RAW_CUSTOMERS c WHERE c.customer_id = pay.customer_id)

    UNION ALL
    -- payments.policy_id → policies
    SELECT 'payments.policy_id → policies',
           COUNT(*)
    FROM RAW_PAYMENTS pay
    WHERE NOT EXISTS (SELECT 1 FROM RAW_POLICIES p WHERE p.policy_id = pay.policy_id)

    UNION ALL
    -- interactions.customer_id → customers
    SELECT 'interactions.customer_id → customers',
           COUNT(*)
    FROM RAW_INTERACTIONS i
    WHERE NOT EXISTS (SELECT 1 FROM RAW_CUSTOMERS c WHERE c.customer_id = i.customer_id)

    UNION ALL
    -- interactions.representative_id → service_representatives (where not null)
    SELECT 'interactions.representative_id → service_reps',
           COUNT(*)
    FROM RAW_INTERACTIONS i
    WHERE i.representative_id IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM RAW_SERVICE_REPRESENTATIVES r
                      WHERE r.representative_id = i.representative_id)

    UNION ALL
    -- transcripts.interaction_id → interactions
    SELECT 'transcripts.interaction_id → interactions',
           COUNT(*)
    FROM RAW_TRANSCRIPTS t
    WHERE NOT EXISTS (SELECT 1 FROM RAW_INTERACTIONS i WHERE i.interaction_id = t.interaction_id)
);

-- =============================================================================
-- 4. TRANSCRIPT 1:1 CONSTRAINT
-- No interaction should have more than one transcript
-- =============================================================================

SELECT
    'TRANSCRIPT_1_TO_1' AS check_type,
    'interaction_id uniqueness in transcripts' AS description,
    COUNT(*) AS duplicate_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    SELECT interaction_id
    FROM RAW_TRANSCRIPTS
    GROUP BY interaction_id
    HAVING COUNT(*) > 1
);

-- =============================================================================
-- 5. ACTIVE POLICIES HAVE COVERAGE
-- =============================================================================

SELECT
    'ACTIVE_POLICY_COVERAGE' AS check_type,
    'active policies without coverage' AS description,
    COUNT(*) AS missing_coverage_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM RAW_POLICIES p
WHERE p.status = 'active'
  AND NOT EXISTS (SELECT 1 FROM RAW_COVERAGES cv WHERE cv.policy_id = p.policy_id);

-- =============================================================================
-- 6. DOMAIN RULE: effective_date < expiration_date
-- =============================================================================

SELECT
    'DATE_ORDERING' AS check_type,
    'policies with effective_date >= expiration_date' AS description,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM RAW_POLICIES
WHERE effective_date >= expiration_date;

-- =============================================================================
-- 7. DOMAIN RULE: payment amount > 0
-- =============================================================================

SELECT
    'PAYMENT_AMOUNT_POSITIVE' AS check_type,
    'payments with amount <= 0' AS description,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM RAW_PAYMENTS
WHERE amount <= 0;

-- =============================================================================
-- 8. BATCH CONSISTENCY
-- All rows in a table should share the same _batch_id from the most recent load
-- =============================================================================

SELECT
    'BATCH_CONSISTENCY' AS check_type,
    table_name,
    distinct_batches,
    CASE WHEN distinct_batches = 1 THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    SELECT 'RAW_CUSTOMERS' AS table_name, COUNT(DISTINCT _batch_id) AS distinct_batches FROM RAW_CUSTOMERS
    UNION ALL
    SELECT 'RAW_POLICIES', COUNT(DISTINCT _batch_id) FROM RAW_POLICIES
    UNION ALL
    SELECT 'RAW_INTERACTIONS', COUNT(DISTINCT _batch_id) FROM RAW_INTERACTIONS
    UNION ALL
    SELECT 'RAW_TRANSCRIPTS', COUNT(DISTINCT _batch_id) FROM RAW_TRANSCRIPTS
);

-- =============================================================================
-- 9. REJECTED ROWS CHECK (COPY_HISTORY)
-- Verify no rows were rejected during the most recent load
-- =============================================================================

SELECT
    'REJECTED_ROWS' AS check_type,
    file_name,
    error_count,
    first_error,
    CASE WHEN error_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    SELECT
        FILE_NAME AS file_name,
        ERROR_COUNT AS error_count,
        FIRST_ERROR AS first_error
    FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
        TABLE_NAME => 'RAW_CUSTOMERS',
        START_TIME => DATEADD(hours, -1, CURRENT_TIMESTAMP())
    ))
    WHERE ERROR_COUNT > 0

    UNION ALL

    SELECT FILE_NAME, ERROR_COUNT, FIRST_ERROR
    FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
        TABLE_NAME => 'RAW_POLICIES',
        START_TIME => DATEADD(hours, -1, CURRENT_TIMESTAMP())
    ))
    WHERE ERROR_COUNT > 0

    UNION ALL

    SELECT FILE_NAME, ERROR_COUNT, FIRST_ERROR
    FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
        TABLE_NAME => 'RAW_TRANSCRIPTS',
        START_TIME => DATEADD(hours, -1, CURRENT_TIMESTAMP())
    ))
    WHERE ERROR_COUNT > 0
);

-- If the above returns 0 rows, all loads were clean.
-- A non-zero result indicates rejected rows that require investigation.

-- =============================================================================
-- 10. GOLDEN DEMO CUSTOMER VERIFICATION
-- =============================================================================

SELECT
    'GOLDEN_DEMO' AS check_type,
    check_name,
    CASE WHEN check_passed THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    -- Maria Chen exists
    SELECT 'CUST-001 exists' AS check_name,
           EXISTS(SELECT 1 FROM RAW_CUSTOMERS WHERE customer_id = 'CUST-001') AS check_passed
    UNION ALL
    -- Has 2 active policies
    SELECT 'CUST-001 has 2 active policies',
           (SELECT COUNT(*) FROM RAW_POLICIES WHERE customer_id = 'CUST-001' AND status = 'active') = 2
    UNION ALL
    -- Has interactions
    SELECT 'CUST-001 has >= 4 interactions',
           (SELECT COUNT(*) FROM RAW_INTERACTIONS WHERE customer_id = 'CUST-001') >= 4
    UNION ALL
    -- Has transcripts
    SELECT 'CUST-001 has >= 4 transcripts',
           (SELECT COUNT(*) FROM RAW_TRANSCRIPTS t
            JOIN RAW_INTERACTIONS i ON t.interaction_id = i.interaction_id
            WHERE i.customer_id = 'CUST-001') >= 4
    UNION ALL
    -- All scenario customers exist
    SELECT 'All 12 scenario customers exist',
           (SELECT COUNT(DISTINCT customer_id) FROM RAW_CUSTOMERS
            WHERE customer_id IN ('CUST-001','CUST-002','CUST-003','CUST-004','CUST-005',
                                  'CUST-006','CUST-007','CUST-008','CUST-009','CUST-010',
                                  'CUST-011','CUST-012')) = 12
);

-- =============================================================================
-- SUMMARY
-- =============================================================================
SELECT 'RECONCILIATION COMPLETE' AS status, CURRENT_TIMESTAMP() AS completed_at;
