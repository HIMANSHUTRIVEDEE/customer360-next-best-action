-- =============================================================================
-- sql/04_ai/05_demo_validation.sql
-- Purpose: End-to-end validation suite for Day 4 AI enrichment pipeline.
--          Confirms the golden demo customer (Maria Chen, CUST-001) flows
--          correctly through every layer: enrichment → risk → NBA → 360.
--          Returns one row per test with PASS or FAIL.
-- Role: C360_DATA_ENGINEER
-- Idempotent: SELECT-only (safe rerun, no side effects)
-- Run after: 01–04 scripts have been executed in order
-- =============================================================================

USE DATABASE CUSTOMER360_DB;
USE SCHEMA ANALYTICS;
USE WAREHOUSE CUSTOMER360_WH;

-- =============================================================================
-- Test framework: identical pattern to 08_tests/01_raw_data_quality.sql.
-- Each CTE produces exactly one row: (check_name, status, detail).
-- Final UNION ALL produces the complete test report.
-- =============================================================================

WITH

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION A: INTERACTIONS_ENRICHED — transcript enrichment layer
-- ═══════════════════════════════════════════════════════════════════════════

-- T01: Table exists and has expected row count (200 interactions)
t01_enriched_exists AS (
    SELECT
        'T01_ENRICHED_TABLE_EXISTS' AS check_name,
        CASE WHEN cnt = 200 THEN 'PASS' ELSE 'FAIL' END AS status,
        'INTERACTIONS_ENRICHED rows=' || cnt || ' (expected 200)' AS detail
    FROM (SELECT COUNT(*) AS cnt FROM INTERACTIONS_ENRICHED)
),

-- T02: All 49 consented transcripts have enrichment_status = 'completed'
t02_consented_enriched AS (
    SELECT
        'T02_CONSENTED_TRANSCRIPTS_ENRICHED' AS check_name,
        CASE WHEN completed = 49 AND failed = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'completed=' || completed || ' failed=' || failed ||
        ' consent_withheld=' || withheld || ' not_applicable=' || na AS detail
    FROM (
        SELECT
            COUNT(CASE WHEN enrichment_status = 'completed'       THEN 1 END) AS completed,
            COUNT(CASE WHEN enrichment_status = 'failed'          THEN 1 END) AS failed,
            COUNT(CASE WHEN enrichment_status = 'consent_withheld' THEN 1 END) AS withheld,
            COUNT(CASE WHEN enrichment_status = 'not_applicable'  THEN 1 END) AS na
        FROM INTERACTIONS_ENRICHED
    )
),

-- T03: No NULL sentiment_score where enrichment_status = 'completed'
t03_sentiment_not_null AS (
    SELECT
        'T03_SENTIMENT_SCORE_NOT_NULL' AS check_name,
        CASE WHEN null_cnt = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'NULL sentiment_score in completed rows: ' || null_cnt AS detail
    FROM (
        SELECT COUNT(*) AS null_cnt
        FROM INTERACTIONS_ENRICHED
        WHERE enrichment_status = 'completed' AND sentiment_score IS NULL
    )
),

-- T04: All sentiment_scores in valid range [-1, +1]
t04_sentiment_range AS (
    SELECT
        'T04_SENTIMENT_SCORE_RANGE' AS check_name,
        CASE WHEN out_of_range = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Out-of-range sentiment scores: ' || out_of_range AS detail
    FROM (
        SELECT COUNT(*) AS out_of_range
        FROM INTERACTIONS_ENRICHED
        WHERE enrichment_status = 'completed'
          AND (sentiment_score < -1.0 OR sentiment_score > 1.0)
    )
),

-- T05: sentiment_label matches score thresholds
t05_sentiment_label_consistency AS (
    SELECT
        'T05_SENTIMENT_LABEL_CONSISTENT' AS check_name,
        CASE WHEN mismatches = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Label/score mismatches: ' || mismatches AS detail
    FROM (
        SELECT COUNT(*) AS mismatches
        FROM INTERACTIONS_ENRICHED
        WHERE enrichment_status = 'completed'
          AND NOT (
              (sentiment_score < -0.2 AND sentiment_label = 'negative') OR
              (sentiment_score >  0.2 AND sentiment_label = 'positive') OR
              (sentiment_score BETWEEN -0.2 AND 0.2 AND sentiment_label = 'neutral')
          )
    )
),

-- T06: No NULL summary where enrichment_status = 'completed'
t06_summary_populated AS (
    SELECT
        'T06_SUMMARY_POPULATED' AS check_name,
        CASE WHEN null_cnt = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'NULL summary in completed rows: ' || null_cnt AS detail
    FROM (
        SELECT COUNT(*) AS null_cnt
        FROM INTERACTIONS_ENRICHED
        WHERE enrichment_status = 'completed' AND summary IS NULL
    )
),

-- T07: primary_topic is from closed enum set
t07_topic_enum AS (
    SELECT
        'T07_TOPIC_ENUM_VALID' AS check_name,
        CASE WHEN invalid_cnt = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Invalid topic values: ' || invalid_cnt AS detail
    FROM (
        SELECT COUNT(*) AS invalid_cnt
        FROM INTERACTIONS_ENRICHED
        WHERE enrichment_status = 'completed'
          AND primary_topic NOT IN ('billing', 'claims', 'coverage', 'service', 'cancellation', 'general')
    )
),

-- T08: primary_intent is from closed enum set
t08_intent_enum AS (
    SELECT
        'T08_INTENT_ENUM_VALID' AS check_name,
        CASE WHEN invalid_cnt = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Invalid intent values: ' || invalid_cnt AS detail
    FROM (
        SELECT COUNT(*) AS invalid_cnt
        FROM INTERACTIONS_ENRICHED
        WHERE enrichment_status = 'completed'
          AND primary_intent NOT IN ('complaint', 'inquiry', 'request', 'praise', 'escalation')
    )
),

-- T09: urgency_level is from closed enum set (all rows, not just completed)
t09_urgency_enum AS (
    SELECT
        'T09_URGENCY_ENUM_VALID' AS check_name,
        CASE WHEN invalid_cnt = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Invalid urgency values: ' || invalid_cnt AS detail
    FROM (
        SELECT COUNT(*) AS invalid_cnt
        FROM INTERACTIONS_ENRICHED
        WHERE urgency_level NOT IN ('critical', 'high', 'medium', 'low')
    )
),

-- T10: No duplicate interaction_id (PK integrity)
t10_enriched_no_dupes AS (
    SELECT
        'T10_ENRICHED_NO_DUPLICATES' AS check_name,
        CASE WHEN dupe_cnt = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Duplicate interaction_ids: ' || dupe_cnt AS detail
    FROM (
        SELECT COUNT(*) AS dupe_cnt FROM (
            SELECT interaction_id FROM INTERACTIONS_ENRICHED
            GROUP BY interaction_id HAVING COUNT(*) > 1
        )
    )
),

-- T11: consent_withheld row has no AI output
t11_consent_respected AS (
    SELECT
        'T11_CONSENT_WITHHELD_NO_AI' AS check_name,
        CASE WHEN leak_cnt = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Consent-withheld rows with AI output: ' || leak_cnt AS detail
    FROM (
        SELECT COUNT(*) AS leak_cnt
        FROM INTERACTIONS_ENRICHED
        WHERE enrichment_status = 'consent_withheld'
          AND (sentiment_score IS NOT NULL OR summary IS NOT NULL
               OR primary_topic IS NOT NULL OR primary_intent IS NOT NULL)
    )
),

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION B: GOLDEN DEMO — Maria Chen (CUST-001) specific validations
-- ═══════════════════════════════════════════════════════════════════════════

-- T12: Maria Chen exists in CUSTOMER_360_BASE
t12_maria_exists AS (
    SELECT
        'T12_MARIA_CHEN_EXISTS' AS check_name,
        CASE WHEN cnt = 1 THEN 'PASS' ELSE 'FAIL' END AS status,
        'CUST-001 rows in CUSTOMER_360_BASE: ' || cnt AS detail
    FROM (
        SELECT COUNT(*) AS cnt
        FROM CUSTOMER_360_BASE
        WHERE customer_id = 'CUST-001'
          AND first_name = 'Maria' AND last_name = 'Chen'
    )
),

-- T13: Maria has 4 interactions, all enriched
t13_maria_interactions AS (
    SELECT
        'T13_MARIA_INTERACTIONS_ENRICHED' AS check_name,
        CASE
            WHEN total = 4 AND with_transcript = 4 AND completed = 4
            THEN 'PASS' ELSE 'FAIL'
        END AS status,
        'total=' || total || ' with_transcript=' || with_transcript ||
        ' completed=' || completed AS detail
    FROM (
        SELECT
            COUNT(*) AS total,
            COUNT(transcript_id) AS with_transcript,
            COUNT(CASE WHEN enrichment_status = 'completed' THEN 1 END) AS completed
        FROM INTERACTIONS_ENRICHED
        WHERE customer_id = 'CUST-001'
    )
),

-- T14: Maria has at least 2 negative-sentiment interactions in recent 90 days
t14_maria_negative_sentiment AS (
    SELECT
        'T14_MARIA_NEGATIVE_SENTIMENT' AS check_name,
        CASE WHEN neg_90d >= 2 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Negative interactions in 90d: ' || neg_90d ||
        ' (sentiment scores: ' || scores || ')' AS detail
    FROM (
        SELECT
            COUNT(*) AS neg_90d,
            LISTAGG(ROUND(sentiment_score, 3)::VARCHAR, ', ')
                WITHIN GROUP (ORDER BY interaction_date DESC) AS scores
        FROM INTERACTIONS_ENRICHED
        WHERE customer_id = 'CUST-001'
          AND sentiment_label = 'negative'
          AND interaction_date >= DATEADD('day', -90, CURRENT_TIMESTAMP())
    )
),

-- T15: Maria has at least one interaction with is_complaint = TRUE
t15_maria_complaint AS (
    SELECT
        'T15_MARIA_HAS_COMPLAINT' AS check_name,
        CASE WHEN complaint_cnt >= 1 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Complaint-flagged interactions: ' || complaint_cnt AS detail
    FROM (
        SELECT COUNT(*) AS complaint_cnt
        FROM INTERACTIONS_ENRICHED
        WHERE customer_id = 'CUST-001' AND is_complaint = TRUE
    )
),

-- T16: Maria's enriched interactions have non-null summaries
t16_maria_summaries AS (
    SELECT
        'T16_MARIA_SUMMARIES_POPULATED' AS check_name,
        CASE WHEN null_cnt = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'CUST-001 completed rows with NULL summary: ' || null_cnt AS detail
    FROM (
        SELECT COUNT(*) AS null_cnt
        FROM INTERACTIONS_ENRICHED
        WHERE customer_id = 'CUST-001'
          AND enrichment_status = 'completed'
          AND summary IS NULL
    )
),

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION C: RISK SIGNALS — per-customer risk computation
-- ═══════════════════════════════════════════════════════════════════════════

-- T17: CUSTOMER_RISK_SIGNALS view returns rows
t17_risk_signals_exist AS (
    SELECT
        'T17_RISK_SIGNALS_POPULATED' AS check_name,
        CASE WHEN cnt > 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Total risk signal rows: ' || cnt AS detail
    FROM (SELECT COUNT(*) AS cnt FROM CUSTOMER_RISK_SIGNALS)
),

-- T18: All 8 signal types present for Maria Chen
t18_maria_signal_types AS (
    SELECT
        'T18_MARIA_ALL_SIGNAL_TYPES' AS check_name,
        CASE WHEN signal_cnt = 8 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Signal types for CUST-001: ' || signal_cnt || '/8 (' || signal_list || ')' AS detail
    FROM (
        SELECT
            COUNT(DISTINCT signal_type) AS signal_cnt,
            LISTAGG(DISTINCT signal_type, ', ') WITHIN GROUP (ORDER BY signal_type) AS signal_list
        FROM CUSTOMER_RISK_SIGNALS
        WHERE customer_id = 'CUST-001'
    )
),

-- T19: Maria's renewal_proximity signal has score > 0 (renewal within 30 days)
t19_maria_renewal_signal AS (
    SELECT
        'T19_MARIA_RENEWAL_PROXIMITY_ACTIVE' AS check_name,
        CASE WHEN signal_score > 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'renewal_proximity score=' || COALESCE(signal_score::VARCHAR, 'NULL') ||
        ' value=' || COALESCE(signal_value::VARCHAR, 'NULL') || ' days' AS detail
    FROM (
        SELECT signal_score, signal_value
        FROM CUSTOMER_RISK_SIGNALS
        WHERE customer_id = 'CUST-001' AND signal_type = 'renewal_proximity'
    )
),

-- T20: Maria's sentiment_negative signal has score > 0
t20_maria_sentiment_signal AS (
    SELECT
        'T20_MARIA_NEGATIVE_SENTIMENT_ACTIVE' AS check_name,
        CASE WHEN signal_score > 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'sentiment_negative score=' || COALESCE(signal_score::VARCHAR, 'NULL') ||
        ' (' || COALESCE(evidence_text, 'no evidence') || ')' AS detail
    FROM (
        SELECT signal_score, evidence_text
        FROM CUSTOMER_RISK_SIGNALS
        WHERE customer_id = 'CUST-001' AND signal_type = 'sentiment_negative'
    )
),

-- T21: Maria's composite risk is 'high' or 'critical'
t21_maria_risk_tier AS (
    SELECT
        'T21_MARIA_RISK_TIER_ELEVATED' AS check_name,
        CASE WHEN risk_tier IN ('high', 'critical') THEN 'PASS' ELSE 'FAIL' END AS status,
        'risk_tier=' || COALESCE(risk_tier, 'NULL') ||
        ' composite_score=' || COALESCE(composite_risk_score::VARCHAR, 'NULL') AS detail
    FROM (
        SELECT risk_tier, composite_risk_score
        FROM CUSTOMER_RISK_SUMMARY
        WHERE customer_id = 'CUST-001'
    )
),

-- T22: Risk signal scores are in valid range [0, 1]
t22_signal_score_range AS (
    SELECT
        'T22_SIGNAL_SCORES_IN_RANGE' AS check_name,
        CASE WHEN out_of_range = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Signal scores outside [0,1]: ' || out_of_range AS detail
    FROM (
        SELECT COUNT(*) AS out_of_range
        FROM CUSTOMER_RISK_SIGNALS
        WHERE signal_score < 0 OR signal_score > 1
    )
),

-- T23: Signal weights sum to 1.0 (from SIGNAL_WEIGHTS config)
t23_weights_sum AS (
    SELECT
        'T23_SIGNAL_WEIGHTS_SUM_TO_ONE' AS check_name,
        CASE WHEN ABS(weight_sum - 1.0) < 0.001 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Sum of signal weights: ' || ROUND(weight_sum, 4)::VARCHAR AS detail
    FROM (
        SELECT SUM(signal_weight) AS weight_sum FROM SIGNAL_WEIGHTS
    )
),

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION D: NBA RECOMMENDATIONS — action scoring and ranking
-- ═══════════════════════════════════════════════════════════════════════════

-- T24: ACTION_LIBRARY has 8 actions loaded
t24_action_library AS (
    SELECT
        'T24_ACTION_LIBRARY_LOADED' AS check_name,
        CASE WHEN cnt = 8 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Actions in ACTION_LIBRARY: ' || cnt AS detail
    FROM (SELECT COUNT(*) AS cnt FROM ACTION_LIBRARY)
),

-- T25: NBA_RECOMMENDATIONS view returns rows
t25_nba_populated AS (
    SELECT
        'T25_NBA_RECOMMENDATIONS_POPULATED' AS check_name,
        CASE WHEN cnt > 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Total NBA recommendation rows: ' || cnt AS detail
    FROM (SELECT COUNT(*) AS cnt FROM NBA_RECOMMENDATIONS)
),

-- T26: Maria has a primary recommendation (action_rank = 1)
t26_maria_primary_nba AS (
    SELECT
        'T26_MARIA_PRIMARY_NBA_EXISTS' AS check_name,
        CASE WHEN cnt = 1 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Primary recommendations for CUST-001: ' || cnt AS detail
    FROM (
        SELECT COUNT(*) AS cnt
        FROM NBA_RECOMMENDATIONS
        WHERE customer_id = 'CUST-001' AND action_rank = 1
    )
),

-- T27: Maria's primary NBA is a retention action (acknowledge_retain or retention_outreach)
t27_maria_nba_is_retention AS (
    SELECT
        'T27_MARIA_NBA_IS_RETENTION' AS check_name,
        CASE
            WHEN action_type IN ('retention_outreach', 'complaint_followup')
            THEN 'PASS' ELSE 'FAIL'
        END AS status,
        'Primary action_type=' || COALESCE(action_type, 'NULL') ||
        ' (' || COALESCE(action_name, 'NULL') || ')' AS detail
    FROM (
        SELECT action_type, action_name
        FROM NBA_RECOMMENDATIONS
        WHERE customer_id = 'CUST-001' AND action_rank = 1
    )
),

-- T28: Maria has at least one alternative action (rank 2+)
t28_maria_alternatives AS (
    SELECT
        'T28_MARIA_HAS_ALTERNATIVES' AS check_name,
        CASE WHEN alt_cnt >= 1 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Alternative actions for CUST-001: ' || alt_cnt AS detail
    FROM (
        SELECT COUNT(*) AS alt_cnt
        FROM NBA_RECOMMENDATIONS
        WHERE customer_id = 'CUST-001' AND action_rank > 1
    )
),

-- T29: Maria's primary NBA has confidence_level populated and not 'low'
t29_maria_confidence AS (
    SELECT
        'T29_MARIA_CONFIDENCE_NOT_LOW' AS check_name,
        CASE
            WHEN confidence_level IN ('high', 'medium_high', 'medium')
            THEN 'PASS' ELSE 'FAIL'
        END AS status,
        'confidence_level=' || COALESCE(confidence_level, 'NULL') ||
        ' confidence_score=' || COALESCE(confidence_score::VARCHAR, 'NULL') AS detail
    FROM (
        SELECT confidence_level, confidence_score
        FROM NBA_RECOMMENDATIONS
        WHERE customer_id = 'CUST-001' AND action_rank = 1
    )
),

-- T30: Maria's NBA has evidence_signals populated (non-empty ARRAY)
t30_maria_evidence_populated AS (
    SELECT
        'T30_MARIA_EVIDENCE_SIGNALS_POPULATED' AS check_name,
        CASE
            WHEN evidence_signals IS NOT NULL AND ARRAY_SIZE(evidence_signals) > 0
            THEN 'PASS' ELSE 'FAIL'
        END AS status,
        'Evidence signal count: ' ||
        COALESCE(ARRAY_SIZE(evidence_signals)::VARCHAR, 'NULL') AS detail
    FROM (
        SELECT evidence_signals
        FROM NBA_RECOMMENDATIONS
        WHERE customer_id = 'CUST-001' AND action_rank = 1
    )
),

-- T31: Maria's NBA has data_completeness populated
t31_maria_data_completeness AS (
    SELECT
        'T31_MARIA_DATA_COMPLETENESS_POPULATED' AS check_name,
        CASE
            WHEN data_completeness IS NOT NULL
                 AND data_completeness:enrichment_coverage_pct IS NOT NULL
                 AND data_completeness:risk_signals_computed IS NOT NULL
            THEN 'PASS' ELSE 'FAIL'
        END AS status,
        'data_completeness=' || COALESCE(data_completeness::VARCHAR, 'NULL') AS detail
    FROM (
        SELECT data_completeness
        FROM NBA_RECOMMENDATIONS
        WHERE customer_id = 'CUST-001' AND action_rank = 1
    )
),

-- T32: Maria's final_score > 0 (recommendation is meaningful, not default)
t32_maria_score_positive AS (
    SELECT
        'T32_MARIA_FINAL_SCORE_POSITIVE' AS check_name,
        CASE WHEN final_score > 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'final_score=' || COALESCE(final_score::VARCHAR, 'NULL') ||
        ' relevance=' || COALESCE(relevance_score::VARCHAR, 'NULL') ||
        ' safety=' || COALESCE(safety_score::VARCHAR, 'NULL') AS detail
    FROM (
        SELECT final_score, relevance_score, safety_score
        FROM NBA_RECOMMENDATIONS
        WHERE customer_id = 'CUST-001' AND action_rank = 1
    )
),

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION E: CUSTOMER_360_ENRICHED — unified view integration
-- ═══════════════════════════════════════════════════════════════════════════

-- T33: Maria exists in CUSTOMER_360_ENRICHED with all sections populated
t33_maria_360_enriched AS (
    SELECT
        'T33_MARIA_360_ENRICHED_EXISTS' AS check_name,
        CASE
            WHEN customer_id IS NOT NULL
                 AND has_enrichment = TRUE
                 AND has_risk_signals = TRUE
                 AND has_recommendation = TRUE
            THEN 'PASS' ELSE 'FAIL'
        END AS status,
        'has_enrichment=' || has_enrichment::VARCHAR ||
        ' has_risk_signals=' || has_risk_signals::VARCHAR ||
        ' has_recommendation=' || has_recommendation::VARCHAR AS detail
    FROM CUSTOMER_360_ENRICHED
    WHERE customer_id = 'CUST-001'
),

-- T34: Maria's system_status is 'full' (no degradation)
t34_maria_system_full AS (
    SELECT
        'T34_MARIA_SYSTEM_STATUS_FULL' AS check_name,
        CASE WHEN system_status = 'full' THEN 'PASS' ELSE 'FAIL' END AS status,
        'system_status=' || COALESCE(system_status, 'NULL') ||
        COALESCE(' message=' || system_message, '') AS detail
    FROM CUSTOMER_360_ENRICHED
    WHERE customer_id = 'CUST-001'
),

-- T35: Maria's 360 shows negative_count_90d >= 2
t35_maria_360_sentiment AS (
    SELECT
        'T35_MARIA_360_NEGATIVE_COUNT' AS check_name,
        CASE WHEN negative_count_90d >= 2 THEN 'PASS' ELSE 'FAIL' END AS status,
        'negative_count_90d=' || negative_count_90d ||
        ' avg_sentiment_90d=' || COALESCE(ROUND(avg_sentiment_90d, 3)::VARCHAR, 'NULL') ||
        ' direction=' || sentiment_direction AS detail
    FROM CUSTOMER_360_ENRICHED
    WHERE customer_id = 'CUST-001'
),

-- T36: Maria's 360 shows days_to_renewal <= 30
t36_maria_360_renewal AS (
    SELECT
        'T36_MARIA_RENEWAL_IN_WINDOW' AS check_name,
        CASE WHEN days_to_renewal <= 30 AND days_to_renewal > 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'days_to_renewal=' || COALESCE(days_to_renewal::VARCHAR, 'NULL') ||
        ' nearest_renewal_date=' || COALESCE(nearest_renewal_date::VARCHAR, 'NULL') AS detail
    FROM CUSTOMER_360_ENRICHED
    WHERE customer_id = 'CUST-001'
),

-- T37: Maria's 360 has nba_action_type populated
t37_maria_360_nba AS (
    SELECT
        'T37_MARIA_360_NBA_POPULATED' AS check_name,
        CASE WHEN nba_action_type IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS status,
        'nba_action_type=' || COALESCE(nba_action_type, 'NULL') ||
        ' nba_confidence=' || COALESCE(nba_confidence_level, 'NULL') ||
        ' risk_tier=' || COALESCE(risk_tier, 'NULL') AS detail
    FROM CUSTOMER_360_ENRICHED
    WHERE customer_id = 'CUST-001'
),

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION F: CROSS-CUTTING — data integrity across layers
-- ═══════════════════════════════════════════════════════════════════════════

-- T38: Every customer in INTERACTIONS_ENRICHED exists in CUSTOMER_360_BASE
t38_orphan_enriched AS (
    SELECT
        'T38_NO_ORPHAN_ENRICHED_CUSTOMERS' AS check_name,
        CASE WHEN orphan_cnt = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Enriched customers not in 360 base: ' || orphan_cnt AS detail
    FROM (
        SELECT COUNT(DISTINCT ie.customer_id) AS orphan_cnt
        FROM INTERACTIONS_ENRICHED ie
        LEFT JOIN CUSTOMER_360_BASE b ON ie.customer_id = b.customer_id
        WHERE b.customer_id IS NULL
    )
),

-- T39: Every customer with risk signals has at least one interaction
t39_risk_without_interaction AS (
    SELECT
        'T39_RISK_SIGNALS_HAVE_INTERACTIONS' AS check_name,
        CASE WHEN orphan_cnt = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Customers with risk signals but no interactions: ' || orphan_cnt AS detail
    FROM (
        SELECT COUNT(DISTINCT rs.customer_id) AS orphan_cnt
        FROM CUSTOMER_RISK_SIGNALS rs
        LEFT JOIN INTERACTIONS_ENRICHED ie ON rs.customer_id = ie.customer_id
        WHERE ie.customer_id IS NULL
          AND rs.signal_type IN ('sentiment_negative', 'complaint_activity')
          AND rs.signal_score > 0
    )
),

-- T40: No customer has more than one primary recommendation
t40_unique_primary_nba AS (
    SELECT
        'T40_UNIQUE_PRIMARY_NBA_PER_CUSTOMER' AS check_name,
        CASE WHEN dupe_cnt = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Customers with >1 primary NBA: ' || dupe_cnt AS detail
    FROM (
        SELECT COUNT(*) AS dupe_cnt FROM (
            SELECT customer_id
            FROM NBA_RECOMMENDATIONS
            WHERE action_rank = 1
            GROUP BY customer_id
            HAVING COUNT(*) > 1
        )
    )
)

-- =============================================================================
-- Final result: one row per test, ordered by check_name
-- =============================================================================
SELECT check_name, status, detail FROM t01_enriched_exists
UNION ALL SELECT * FROM t02_consented_enriched
UNION ALL SELECT * FROM t03_sentiment_not_null
UNION ALL SELECT * FROM t04_sentiment_range
UNION ALL SELECT * FROM t05_sentiment_label_consistency
UNION ALL SELECT * FROM t06_summary_populated
UNION ALL SELECT * FROM t07_topic_enum
UNION ALL SELECT * FROM t08_intent_enum
UNION ALL SELECT * FROM t09_urgency_enum
UNION ALL SELECT * FROM t10_enriched_no_dupes
UNION ALL SELECT * FROM t11_consent_respected
UNION ALL SELECT * FROM t12_maria_exists
UNION ALL SELECT * FROM t13_maria_interactions
UNION ALL SELECT * FROM t14_maria_negative_sentiment
UNION ALL SELECT * FROM t15_maria_complaint
UNION ALL SELECT * FROM t16_maria_summaries
UNION ALL SELECT * FROM t17_risk_signals_exist
UNION ALL SELECT * FROM t18_maria_signal_types
UNION ALL SELECT * FROM t19_maria_renewal_signal
UNION ALL SELECT * FROM t20_maria_sentiment_signal
UNION ALL SELECT * FROM t21_maria_risk_tier
UNION ALL SELECT * FROM t22_signal_score_range
UNION ALL SELECT * FROM t23_weights_sum
UNION ALL SELECT * FROM t24_action_library
UNION ALL SELECT * FROM t25_nba_populated
UNION ALL SELECT * FROM t26_maria_primary_nba
UNION ALL SELECT * FROM t27_maria_nba_is_retention
UNION ALL SELECT * FROM t28_maria_alternatives
UNION ALL SELECT * FROM t29_maria_confidence
UNION ALL SELECT * FROM t30_maria_evidence_populated
UNION ALL SELECT * FROM t31_maria_data_completeness
UNION ALL SELECT * FROM t32_maria_score_positive
UNION ALL SELECT * FROM t33_maria_360_enriched
UNION ALL SELECT * FROM t34_maria_system_full
UNION ALL SELECT * FROM t35_maria_360_sentiment
UNION ALL SELECT * FROM t36_maria_360_renewal
UNION ALL SELECT * FROM t37_maria_360_nba
UNION ALL SELECT * FROM t38_orphan_enriched
UNION ALL SELECT * FROM t39_risk_without_interaction
UNION ALL SELECT * FROM t40_unique_primary_nba
ORDER BY check_name;
