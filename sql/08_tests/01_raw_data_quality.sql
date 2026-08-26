-- =============================================================================
-- sql/08_tests/01_raw_data_quality.sql
-- Purpose: Formal data-quality test suite for RAW layer
-- Administrative role required: C360_DATA_ENGINEER
-- Output: One row per test with check_name, status (PASS/FAIL), detail
-- Run after: 03_load_raw.sql completes successfully
-- =============================================================================

USE DATABASE CUSTOMER360_DB;
USE SCHEMA RAW;
USE WAREHOUSE CUSTOMER360_WH;

-- =============================================================================
-- Test framework: Each CTE produces exactly one row with check_name, status, detail.
-- Final SELECT unions all results into a single result set.
-- =============================================================================

WITH

-- ─────────────────────────────────────────────────────────────────────────────
-- T01: Source and target row counts match
-- ─────────────────────────────────────────────────────────────────────────────
t01_row_counts AS (
    SELECT
        'T01_ROW_COUNTS_MATCH' AS check_name,
        CASE
            WHEN c = 100 AND p = 250 AND cv = 565 AND cl = 30
                 AND pay = 669 AND i = 200 AND t = 50 AND sr = 5
            THEN 'PASS'
            ELSE 'FAIL'
        END AS status,
        'customers=' || c || ' policies=' || p || ' coverages=' || cv ||
        ' claims=' || cl || ' payments=' || pay || ' interactions=' || i ||
        ' transcripts=' || t || ' reps=' || sr AS detail
    FROM (
        SELECT
            (SELECT COUNT(*) FROM RAW_CUSTOMERS) AS c,
            (SELECT COUNT(*) FROM RAW_POLICIES) AS p,
            (SELECT COUNT(*) FROM RAW_COVERAGES) AS cv,
            (SELECT COUNT(*) FROM RAW_CLAIMS) AS cl,
            (SELECT COUNT(*) FROM RAW_PAYMENTS) AS pay,
            (SELECT COUNT(*) FROM RAW_INTERACTIONS) AS i,
            (SELECT COUNT(*) FROM RAW_TRANSCRIPTS) AS t,
            (SELECT COUNT(*) FROM RAW_SERVICE_REPRESENTATIVES) AS sr
    )
),

-- ─────────────────────────────────────────────────────────────────────────────
-- T02: No duplicate primary identifiers
-- ─────────────────────────────────────────────────────────────────────────────
t02_pk_uniqueness AS (
    SELECT
        'T02_NO_DUPLICATE_PKS' AS check_name,
        CASE WHEN dup_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        dup_count || ' duplicate PKs found' AS detail
    FROM (
        SELECT SUM(dups) AS dup_count FROM (
            SELECT COUNT(*) - COUNT(DISTINCT customer_id) AS dups FROM RAW_CUSTOMERS
            UNION ALL SELECT COUNT(*) - COUNT(DISTINCT policy_id) FROM RAW_POLICIES
            UNION ALL SELECT COUNT(*) - COUNT(DISTINCT coverage_id) FROM RAW_COVERAGES
            UNION ALL SELECT COUNT(*) - COUNT(DISTINCT claim_id) FROM RAW_CLAIMS
            UNION ALL SELECT COUNT(*) - COUNT(DISTINCT payment_id) FROM RAW_PAYMENTS
            UNION ALL SELECT COUNT(*) - COUNT(DISTINCT interaction_id) FROM RAW_INTERACTIONS
            UNION ALL SELECT COUNT(*) - COUNT(DISTINCT transcript_id) FROM RAW_TRANSCRIPTS
            UNION ALL SELECT COUNT(*) - COUNT(DISTINCT representative_id) FROM RAW_SERVICE_REPRESENTATIVES
        )
    )
),

-- ─────────────────────────────────────────────────────────────────────────────
-- T03: No orphan customer references
-- ─────────────────────────────────────────────────────────────────────────────
t03_orphan_customers AS (
    SELECT
        'T03_NO_ORPHAN_CUSTOMER_REFS' AS check_name,
        CASE WHEN orphan_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        orphan_count || ' orphan customer_id references' AS detail
    FROM (
        SELECT SUM(cnt) AS orphan_count FROM (
            SELECT COUNT(*) AS cnt FROM RAW_POLICIES p
            WHERE NOT EXISTS (SELECT 1 FROM RAW_CUSTOMERS c WHERE c.customer_id = p.customer_id)
            UNION ALL
            SELECT COUNT(*) FROM RAW_CLAIMS cl
            WHERE NOT EXISTS (SELECT 1 FROM RAW_CUSTOMERS c WHERE c.customer_id = cl.customer_id)
            UNION ALL
            SELECT COUNT(*) FROM RAW_PAYMENTS pay
            WHERE NOT EXISTS (SELECT 1 FROM RAW_CUSTOMERS c WHERE c.customer_id = pay.customer_id)
            UNION ALL
            SELECT COUNT(*) FROM RAW_INTERACTIONS i
            WHERE NOT EXISTS (SELECT 1 FROM RAW_CUSTOMERS c WHERE c.customer_id = i.customer_id)
        )
    )
),

-- ─────────────────────────────────────────────────────────────────────────────
-- T04: No orphan policy references
-- ─────────────────────────────────────────────────────────────────────────────
t04_orphan_policies AS (
    SELECT
        'T04_NO_ORPHAN_POLICY_REFS' AS check_name,
        CASE WHEN orphan_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        orphan_count || ' orphan policy_id references' AS detail
    FROM (
        SELECT SUM(cnt) AS orphan_count FROM (
            SELECT COUNT(*) AS cnt FROM RAW_COVERAGES cv
            WHERE NOT EXISTS (SELECT 1 FROM RAW_POLICIES p WHERE p.policy_id = cv.policy_id)
            UNION ALL
            SELECT COUNT(*) FROM RAW_CLAIMS cl
            WHERE NOT EXISTS (SELECT 1 FROM RAW_POLICIES p WHERE p.policy_id = cl.policy_id)
            UNION ALL
            SELECT COUNT(*) FROM RAW_PAYMENTS pay
            WHERE NOT EXISTS (SELECT 1 FROM RAW_POLICIES p WHERE p.policy_id = pay.policy_id)
        )
    )
),

-- ─────────────────────────────────────────────────────────────────────────────
-- T05: Claim customer matches policy customer
-- ─────────────────────────────────────────────────────────────────────────────
t05_claim_ownership AS (
    SELECT
        'T05_CLAIM_CUSTOMER_MATCHES_POLICY' AS check_name,
        CASE WHEN mismatch_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        mismatch_count || ' claims where customer_id != policy owner' AS detail
    FROM (
        SELECT COUNT(*) AS mismatch_count
        FROM RAW_CLAIMS cl
        JOIN RAW_POLICIES p ON cl.policy_id = p.policy_id
        WHERE cl.customer_id != p.customer_id
    )
),

-- ─────────────────────────────────────────────────────────────────────────────
-- T06: Payment customer matches policy customer
-- ─────────────────────────────────────────────────────────────────────────────
t06_payment_ownership AS (
    SELECT
        'T06_PAYMENT_CUSTOMER_MATCHES_POLICY' AS check_name,
        CASE WHEN mismatch_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        mismatch_count || ' payments where customer_id != policy owner' AS detail
    FROM (
        SELECT COUNT(*) AS mismatch_count
        FROM RAW_PAYMENTS pay
        JOIN RAW_POLICIES p ON pay.policy_id = p.policy_id
        WHERE pay.customer_id != p.customer_id
    )
),

-- ─────────────────────────────────────────────────────────────────────────────
-- T07: Transcript interaction exists
-- ─────────────────────────────────────────────────────────────────────────────
t07_transcript_interaction AS (
    SELECT
        'T07_TRANSCRIPT_INTERACTION_EXISTS' AS check_name,
        CASE WHEN orphan_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        orphan_count || ' transcripts referencing non-existent interactions' AS detail
    FROM (
        SELECT COUNT(*) AS orphan_count
        FROM RAW_TRANSCRIPTS t
        WHERE NOT EXISTS (SELECT 1 FROM RAW_INTERACTIONS i WHERE i.interaction_id = t.interaction_id)
    )
),

-- ─────────────────────────────────────────────────────────────────────────────
-- T08: One transcript maximum per interaction
-- ─────────────────────────────────────────────────────────────────────────────
t08_transcript_one_to_one AS (
    SELECT
        'T08_ONE_TRANSCRIPT_PER_INTERACTION' AS check_name,
        CASE WHEN dup_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        dup_count || ' interactions with multiple transcripts' AS detail
    FROM (
        SELECT COUNT(*) AS dup_count
        FROM (
            SELECT interaction_id
            FROM RAW_TRANSCRIPTS
            GROUP BY interaction_id
            HAVING COUNT(*) > 1
        )
    )
),

-- ─────────────────────────────────────────────────────────────────────────────
-- T09: Active policies have coverage
-- ─────────────────────────────────────────────────────────────────────────────
t09_active_policy_coverage AS (
    SELECT
        'T09_ACTIVE_POLICIES_HAVE_COVERAGE' AS check_name,
        CASE WHEN missing_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        missing_count || ' active policies without coverage rows' AS detail
    FROM (
        SELECT COUNT(*) AS missing_count
        FROM RAW_POLICIES p
        WHERE p.status = 'active'
          AND NOT EXISTS (SELECT 1 FROM RAW_COVERAGES cv WHERE cv.policy_id = p.policy_id)
    )
),

-- ─────────────────────────────────────────────────────────────────────────────
-- T10: Valid policy dates (effective_date < expiration_date)
-- ─────────────────────────────────────────────────────────────────────────────
t10_policy_dates AS (
    SELECT
        'T10_VALID_POLICY_DATES' AS check_name,
        CASE WHEN violation_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        violation_count || ' policies with effective_date >= expiration_date' AS detail
    FROM (
        SELECT COUNT(*) AS violation_count
        FROM RAW_POLICIES
        WHERE effective_date >= expiration_date
    )
),

-- ─────────────────────────────────────────────────────────────────────────────
-- T11: Positive payment amounts
-- ─────────────────────────────────────────────────────────────────────────────
t11_payment_amounts AS (
    SELECT
        'T11_POSITIVE_PAYMENT_AMOUNTS' AS check_name,
        CASE WHEN violation_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        violation_count || ' payments with amount <= 0' AS detail
    FROM (
        SELECT COUNT(*) AS violation_count
        FROM RAW_PAYMENTS
        WHERE amount <= 0
    )
),

-- ─────────────────────────────────────────────────────────────────────────────
-- T12: Valid enumerations
-- ─────────────────────────────────────────────────────────────────────────────
t12_valid_enums AS (
    SELECT
        'T12_VALID_ENUMERATIONS' AS check_name,
        CASE WHEN total_violations = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        total_violations || ' enum violations' AS detail
    FROM (
        SELECT SUM(cnt) AS total_violations FROM (
            -- customer status
            SELECT COUNT(*) AS cnt FROM RAW_CUSTOMERS
            WHERE status NOT IN ('active', 'inactive', 'prospect')
            UNION ALL
            -- product_type
            SELECT COUNT(*) FROM RAW_POLICIES
            WHERE product_type NOT IN ('auto', 'home', 'umbrella', 'renters')
            UNION ALL
            -- policy status
            SELECT COUNT(*) FROM RAW_POLICIES
            WHERE status NOT IN ('quoted', 'bound', 'active', 'renewed', 'lapsed', 'cancelled')
            UNION ALL
            -- payment_frequency
            SELECT COUNT(*) FROM RAW_POLICIES
            WHERE payment_frequency NOT IN ('monthly', 'quarterly', 'semi_annual', 'annual')
            UNION ALL
            -- payment status
            SELECT COUNT(*) FROM RAW_PAYMENTS
            WHERE status NOT IN ('on_time', 'late', 'grace_period', 'missed', 'pending')
            UNION ALL
            -- claim status
            SELECT COUNT(*) FROM RAW_CLAIMS
            WHERE status NOT IN ('filed', 'under_review', 'settled', 'denied', 'withdrawn')
            UNION ALL
            -- channel
            SELECT COUNT(*) FROM RAW_INTERACTIONS
            WHERE channel NOT IN ('phone', 'email', 'chat')
            UNION ALL
            -- direction
            SELECT COUNT(*) FROM RAW_INTERACTIONS
            WHERE direction NOT IN ('inbound', 'outbound', 'internal_note')
            UNION ALL
            -- disposition
            SELECT COUNT(*) FROM RAW_INTERACTIONS
            WHERE disposition NOT IN ('inquiry', 'complaint', 'request', 'notification', 'general')
            UNION ALL
            -- content_type
            SELECT COUNT(*) FROM RAW_TRANSCRIPTS
            WHERE content_type NOT IN ('call_transcript', 'email_body', 'agent_note')
            UNION ALL
            -- rep role
            SELECT COUNT(*) FROM RAW_SERVICE_REPRESENTATIVES
            WHERE role NOT IN ('service_rep', 'retention_specialist', 'supervisor')
        )
    )
),

-- ─────────────────────────────────────────────────────────────────────────────
-- T13: Consent flag populated (no nulls, valid values)
-- ─────────────────────────────────────────────────────────────────────────────
t13_consent_flag AS (
    SELECT
        'T13_CONSENT_FLAG_POPULATED' AS check_name,
        CASE WHEN violation_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        violation_count || ' transcripts with invalid/missing consent flag' AS detail
    FROM (
        SELECT COUNT(*) AS violation_count
        FROM RAW_TRANSCRIPTS
        WHERE recording_consent_flag IS NULL
           OR recording_consent_flag NOT IN ('TRUE', 'FALSE')
    )
),

-- ─────────────────────────────────────────────────────────────────────────────
-- T14: Audit columns populated (_loaded_at, _source_file, _batch_id, _row_hash)
-- ─────────────────────────────────────────────────────────────────────────────
t14_audit_columns AS (
    SELECT
        'T14_AUDIT_COLUMNS_POPULATED' AS check_name,
        CASE WHEN null_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        null_count || ' rows with null audit columns' AS detail
    FROM (
        SELECT SUM(cnt) AS null_count FROM (
            SELECT COUNT(*) AS cnt FROM RAW_CUSTOMERS
            WHERE _loaded_at IS NULL OR _source_file IS NULL OR _batch_id IS NULL OR _row_hash IS NULL
            UNION ALL
            SELECT COUNT(*) FROM RAW_POLICIES
            WHERE _loaded_at IS NULL OR _source_file IS NULL OR _batch_id IS NULL OR _row_hash IS NULL
            UNION ALL
            SELECT COUNT(*) FROM RAW_INTERACTIONS
            WHERE _loaded_at IS NULL OR _source_file IS NULL OR _batch_id IS NULL OR _row_hash IS NULL
            UNION ALL
            SELECT COUNT(*) FROM RAW_TRANSCRIPTS
            WHERE _loaded_at IS NULL OR _source_file IS NULL OR _batch_id IS NULL OR _row_hash IS NULL
            UNION ALL
            SELECT COUNT(*) FROM RAW_PAYMENTS
            WHERE _loaded_at IS NULL OR _source_file IS NULL OR _batch_id IS NULL OR _row_hash IS NULL
            UNION ALL
            SELECT COUNT(*) FROM RAW_CLAIMS
            WHERE _loaded_at IS NULL OR _source_file IS NULL OR _batch_id IS NULL OR _row_hash IS NULL
            UNION ALL
            SELECT COUNT(*) FROM RAW_COVERAGES
            WHERE _loaded_at IS NULL OR _source_file IS NULL OR _batch_id IS NULL OR _row_hash IS NULL
            UNION ALL
            SELECT COUNT(*) FROM RAW_SERVICE_REPRESENTATIVES
            WHERE _loaded_at IS NULL OR _source_file IS NULL OR _batch_id IS NULL OR _row_hash IS NULL
        )
    )
),

-- ─────────────────────────────────────────────────────────────────────────────
-- T15: Golden-demo graph complete (Maria Chen end-to-end)
-- ─────────────────────────────────────────────────────────────────────────────
t15_golden_demo AS (
    SELECT
        'T15_GOLDEN_DEMO_GRAPH_COMPLETE' AS check_name,
        CASE
            WHEN cust_exists AND policy_count = 2 AND interaction_count >= 4
                 AND transcript_count >= 4 AND all_consent_true
            THEN 'PASS'
            ELSE 'FAIL'
        END AS status,
        'customer=' || cust_exists || ' policies=' || policy_count ||
        ' interactions=' || interaction_count || ' transcripts=' || transcript_count ||
        ' all_consent=' || all_consent_true AS detail
    FROM (
        SELECT
            EXISTS(SELECT 1 FROM RAW_CUSTOMERS WHERE customer_id = 'CUST-001' AND household_id = 'HH-001') AS cust_exists,
            (SELECT COUNT(*) FROM RAW_POLICIES WHERE customer_id = 'CUST-001' AND status = 'active') AS policy_count,
            (SELECT COUNT(*) FROM RAW_INTERACTIONS WHERE customer_id = 'CUST-001') AS interaction_count,
            (SELECT COUNT(*) FROM RAW_TRANSCRIPTS t JOIN RAW_INTERACTIONS i ON t.interaction_id = i.interaction_id WHERE i.customer_id = 'CUST-001') AS transcript_count,
            (SELECT COUNT(*) = 0 FROM RAW_TRANSCRIPTS t JOIN RAW_INTERACTIONS i ON t.interaction_id = i.interaction_id WHERE i.customer_id = 'CUST-001' AND t.recording_consent_flag != 'TRUE') AS all_consent_true
    )
),

-- ─────────────────────────────────────────────────────────────────────────────
-- T16: All scenario IDs represented (CUST-001 through CUST-012)
-- ─────────────────────────────────────────────────────────────────────────────
t16_scenario_coverage AS (
    SELECT
        'T16_ALL_SCENARIOS_REPRESENTED' AS check_name,
        CASE WHEN scenario_count = 12 THEN 'PASS' ELSE 'FAIL' END AS status,
        scenario_count || '/12 scenario customers found' AS detail
    FROM (
        SELECT COUNT(DISTINCT customer_id) AS scenario_count
        FROM RAW_CUSTOMERS
        WHERE customer_id IN (
            'CUST-001','CUST-002','CUST-003','CUST-004','CUST-005','CUST-006',
            'CUST-007','CUST-008','CUST-009','CUST-010','CUST-011','CUST-012'
        )
    )
),

-- ─────────────────────────────────────────────────────────────────────────────
-- T17: No load errors (check COPY_HISTORY for recent errors)
-- ─────────────────────────────────────────────────────────────────────────────
t17_no_load_errors AS (
    SELECT
        'T17_NO_LOAD_ERRORS' AS check_name,
        CASE WHEN error_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        error_count || ' files with load errors in last hour' AS detail
    FROM (
        SELECT COUNT(*) AS error_count
        FROM (
            SELECT 1 FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
                TABLE_NAME => 'RAW_CUSTOMERS', START_TIME => DATEADD(hours, -1, CURRENT_TIMESTAMP())
            )) WHERE ERROR_COUNT > 0
            UNION ALL
            SELECT 1 FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
                TABLE_NAME => 'RAW_POLICIES', START_TIME => DATEADD(hours, -1, CURRENT_TIMESTAMP())
            )) WHERE ERROR_COUNT > 0
            UNION ALL
            SELECT 1 FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
                TABLE_NAME => 'RAW_COVERAGES', START_TIME => DATEADD(hours, -1, CURRENT_TIMESTAMP())
            )) WHERE ERROR_COUNT > 0
            UNION ALL
            SELECT 1 FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
                TABLE_NAME => 'RAW_CLAIMS', START_TIME => DATEADD(hours, -1, CURRENT_TIMESTAMP())
            )) WHERE ERROR_COUNT > 0
            UNION ALL
            SELECT 1 FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
                TABLE_NAME => 'RAW_PAYMENTS', START_TIME => DATEADD(hours, -1, CURRENT_TIMESTAMP())
            )) WHERE ERROR_COUNT > 0
            UNION ALL
            SELECT 1 FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
                TABLE_NAME => 'RAW_INTERACTIONS', START_TIME => DATEADD(hours, -1, CURRENT_TIMESTAMP())
            )) WHERE ERROR_COUNT > 0
            UNION ALL
            SELECT 1 FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
                TABLE_NAME => 'RAW_TRANSCRIPTS', START_TIME => DATEADD(hours, -1, CURRENT_TIMESTAMP())
            )) WHERE ERROR_COUNT > 0
            UNION ALL
            SELECT 1 FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
                TABLE_NAME => 'RAW_SERVICE_REPRESENTATIVES', START_TIME => DATEADD(hours, -1, CURRENT_TIMESTAMP())
            )) WHERE ERROR_COUNT > 0
        )
    )
)

-- =============================================================================
-- FINAL OUTPUT: Union all test results
-- =============================================================================
SELECT check_name, status, detail FROM t01_row_counts
UNION ALL SELECT * FROM t02_pk_uniqueness
UNION ALL SELECT * FROM t03_orphan_customers
UNION ALL SELECT * FROM t04_orphan_policies
UNION ALL SELECT * FROM t05_claim_ownership
UNION ALL SELECT * FROM t06_payment_ownership
UNION ALL SELECT * FROM t07_transcript_interaction
UNION ALL SELECT * FROM t08_transcript_one_to_one
UNION ALL SELECT * FROM t09_active_policy_coverage
UNION ALL SELECT * FROM t10_policy_dates
UNION ALL SELECT * FROM t11_payment_amounts
UNION ALL SELECT * FROM t12_valid_enums
UNION ALL SELECT * FROM t13_consent_flag
UNION ALL SELECT * FROM t14_audit_columns
UNION ALL SELECT * FROM t15_golden_demo
UNION ALL SELECT * FROM t16_scenario_coverage
UNION ALL SELECT * FROM t17_no_load_errors
ORDER BY check_name;
