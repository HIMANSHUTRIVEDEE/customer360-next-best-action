-- =============================================================================
-- sql/04_ai/02_customer_risk_signals.sql
-- Purpose: Compute named, weighted, directional risk signals per customer.
--          Pure SQL — zero Cortex calls. Reads from CUSTOMER_360_BASE +
--          INTERACTIONS_ENRICHED. Each signal is individually addressable,
--          auditable, and explainable.
-- Role: C360_DATA_ENGINEER
-- Idempotent: CREATE OR REPLACE VIEW (safe rerun)
-- Cost: Zero Cortex credits. Standard SQL compute only.
-- =============================================================================

USE DATABASE CUSTOMER360_DB;
USE SCHEMA ANALYTICS;

-- =============================================================================
-- CUSTOMER_RISK_SIGNALS
-- Grain: One row per customer per signal type (unpivoted for explainability).
-- The NBA engine reads these rows to score candidate actions.
-- The Streamlit app displays them as the evidence trail.
--
-- Signal types:
--   1. renewal_proximity   — how close is the nearest renewal date
--   2. sentiment_negative  — count + severity of negative interactions (90d)
--   3. sentiment_trend     — direction of sentiment over time
--   4. payment_risk        — late/missed payment ratio
--   5. complaint_activity  — recent complaint + escalation count
--   6. claim_activity      — open/recent claims indicating service load
--   7. engagement_drop     — declining interaction frequency
--   8. cross_sell_gap      — missing product types vs household norm
--
-- Each signal produces:
--   signal_value  — the raw metric (days, count, ratio)
--   signal_score  — normalized 0.0–1.0 (higher = more risk OR more opportunity)
--   signal_weight — relative importance for NBA scoring
--   signal_direction — improving, stable, worsening
--   evidence_text — human-readable explanation
-- =============================================================================
CREATE OR REPLACE VIEW CUSTOMER_RISK_SIGNALS AS

WITH base AS (
    SELECT * FROM CUSTOMER_360_BASE
),

-- Sentiment aggregates from enriched interactions (90-day and prior-90-day windows)
sentiment_90d AS (
    SELECT
        customer_id,
        COUNT(*)                                                    AS total_enriched_90d,
        COUNT(CASE WHEN sentiment_label = 'negative' THEN 1 END)   AS negative_count_90d,
        COUNT(CASE WHEN is_complaint THEN 1 END)                   AS complaint_count_90d,
        COUNT(CASE WHEN is_escalation THEN 1 END)                  AS escalation_count_90d,
        AVG(sentiment_score)                                        AS avg_sentiment_90d,
        MIN(sentiment_score)                                        AS worst_sentiment_90d,
        MAX(CASE WHEN sentiment_label = 'negative'
            THEN interaction_date END)                              AS last_negative_date
    FROM INTERACTIONS_ENRICHED
    WHERE enrichment_status = 'completed'
      AND interaction_date >= DATEADD('day', -90, CURRENT_TIMESTAMP())
    GROUP BY customer_id
),

sentiment_prior AS (
    SELECT
        customer_id,
        AVG(sentiment_score) AS avg_sentiment_prior_90d
    FROM INTERACTIONS_ENRICHED
    WHERE enrichment_status = 'completed'
      AND interaction_date >= DATEADD('day', -180, CURRENT_TIMESTAMP())
      AND interaction_date <  DATEADD('day',  -90, CURRENT_TIMESTAMP())
    GROUP BY customer_id
),

-- Interaction frequency: current 90d vs prior 90d
interaction_freq AS (
    SELECT
        customer_id,
        COUNT(CASE WHEN interaction_date >= DATEADD('day', -90, CURRENT_TIMESTAMP()) THEN 1 END)
            AS interactions_current_90d,
        COUNT(CASE WHEN interaction_date >= DATEADD('day', -180, CURRENT_TIMESTAMP())
                    AND interaction_date <  DATEADD('day',  -90, CURRENT_TIMESTAMP()) THEN 1 END)
            AS interactions_prior_90d
    FROM FACT_INTERACTION
    GROUP BY customer_id
),

-- Cross-sell: which product types does the customer NOT have
product_gaps AS (
    SELECT
        c.customer_id,
        c.active_policies,
        CASE WHEN c.product_holdings NOT LIKE '%home%'     THEN TRUE ELSE FALSE END AS missing_home,
        CASE WHEN c.product_holdings NOT LIKE '%umbrella%' THEN TRUE ELSE FALSE END AS missing_umbrella,
        CASE WHEN c.product_holdings NOT LIKE '%auto%'     THEN TRUE ELSE FALSE END AS missing_auto,
        CASE WHEN c.product_holdings NOT LIKE '%renters%'  THEN TRUE ELSE FALSE END AS missing_renters
    FROM AGG_CUSTOMER_POLICY c
),

-- Combine all signals into a unified row per customer (wide format first)
wide_signals AS (
    SELECT
        b.customer_id,
        b.first_name,
        b.last_name,

        -- Renewal proximity
        b.nearest_renewal_date,
        DATEDIFF('day', CURRENT_DATE(), b.nearest_renewal_date) AS days_to_renewal,

        -- Sentiment
        COALESCE(s.negative_count_90d, 0)    AS negative_count_90d,
        COALESCE(s.complaint_count_90d, 0)   AS complaint_count_90d,
        COALESCE(s.escalation_count_90d, 0)  AS escalation_count_90d,
        s.avg_sentiment_90d,
        s.worst_sentiment_90d,
        s.last_negative_date,
        sp.avg_sentiment_prior_90d,

        -- Payment risk
        b.payments_late,
        b.payments_missed,
        b.total_payments,

        -- Claims
        b.open_claims,
        b.total_claims,

        -- Interaction frequency
        COALESCE(ifr.interactions_current_90d, 0)  AS interactions_current_90d,
        COALESCE(ifr.interactions_prior_90d, 0)    AS interactions_prior_90d,

        -- Cross-sell
        b.active_policies,
        COALESCE(pg.missing_home, TRUE)      AS missing_home,
        COALESCE(pg.missing_umbrella, TRUE)  AS missing_umbrella,
        b.product_holdings

    FROM base b
    LEFT JOIN sentiment_90d s       ON b.customer_id = s.customer_id
    LEFT JOIN sentiment_prior sp    ON b.customer_id = sp.customer_id
    LEFT JOIN interaction_freq ifr  ON b.customer_id = ifr.customer_id
    LEFT JOIN product_gaps pg       ON b.customer_id = pg.customer_id
),

-- Unpivot into one row per customer × signal_type
all_signals AS (

    -- 1. RENEWAL_PROXIMITY
    SELECT
        customer_id,
        'renewal_proximity'     AS signal_type,
        days_to_renewal         AS signal_value,
        -- Score: 1.0 at 0 days, 0.0 at 60+ days (linear decay)
        GREATEST(0, LEAST(1.0, (60.0 - COALESCE(days_to_renewal, 999)) / 60.0))
                                AS signal_score,
        0.30                    AS signal_weight,
        'stable'                AS signal_direction,
        'Nearest renewal in ' || COALESCE(days_to_renewal::VARCHAR, 'N/A') || ' days'
            || CASE WHEN days_to_renewal <= 14 THEN ' — URGENT' 
                    WHEN days_to_renewal <= 30 THEN ' — approaching'
                    ELSE '' END
                                AS evidence_text
    FROM wide_signals
    WHERE nearest_renewal_date IS NOT NULL

    UNION ALL

    -- 2. SENTIMENT_NEGATIVE
    SELECT
        customer_id,
        'sentiment_negative'    AS signal_type,
        negative_count_90d      AS signal_value,
        -- Score: 0 negatives = 0.0, 1 = 0.4, 2 = 0.7, 3+ = 1.0
        CASE
            WHEN negative_count_90d = 0 THEN 0.0
            WHEN negative_count_90d = 1 THEN 0.4
            WHEN negative_count_90d = 2 THEN 0.7
            ELSE 1.0
        END                     AS signal_score,
        0.25                    AS signal_weight,
        -- Direction: compare current vs prior 90d average
        CASE
            WHEN avg_sentiment_90d IS NULL OR avg_sentiment_prior_90d IS NULL THEN 'stable'
            WHEN avg_sentiment_90d < avg_sentiment_prior_90d - 0.1           THEN 'worsening'
            WHEN avg_sentiment_90d > avg_sentiment_prior_90d + 0.1           THEN 'improving'
            ELSE 'stable'
        END                     AS signal_direction,
        negative_count_90d::VARCHAR || ' negative interaction(s) in last 90 days'
            || CASE WHEN worst_sentiment_90d IS NOT NULL
                    THEN ' (worst score: ' || ROUND(worst_sentiment_90d, 2)::VARCHAR || ')'
                    ELSE '' END
                                AS evidence_text
    FROM wide_signals

    UNION ALL

    -- 3. SENTIMENT_TREND
    SELECT
        customer_id,
        'sentiment_trend'       AS signal_type,
        COALESCE(avg_sentiment_90d, 0) AS signal_value,
        -- Score: large negative delta = high risk
        CASE
            WHEN avg_sentiment_90d IS NULL OR avg_sentiment_prior_90d IS NULL THEN 0.0
            WHEN avg_sentiment_90d < avg_sentiment_prior_90d - 0.3           THEN 0.9
            WHEN avg_sentiment_90d < avg_sentiment_prior_90d - 0.1           THEN 0.5
            ELSE 0.1
        END                     AS signal_score,
        0.10                    AS signal_weight,
        CASE
            WHEN avg_sentiment_90d IS NULL OR avg_sentiment_prior_90d IS NULL THEN 'stable'
            WHEN avg_sentiment_90d < avg_sentiment_prior_90d - 0.1           THEN 'worsening'
            WHEN avg_sentiment_90d > avg_sentiment_prior_90d + 0.1           THEN 'improving'
            ELSE 'stable'
        END                     AS signal_direction,
        'Sentiment trend: ' ||
            CASE
                WHEN avg_sentiment_90d IS NULL THEN 'insufficient data'
                ELSE 'avg ' || ROUND(COALESCE(avg_sentiment_90d, 0), 2)::VARCHAR ||
                     ' (prior: ' || ROUND(COALESCE(avg_sentiment_prior_90d, 0), 2)::VARCHAR || ')'
            END                 AS evidence_text
    FROM wide_signals

    UNION ALL

    -- 4. PAYMENT_RISK
    SELECT
        customer_id,
        'payment_risk'          AS signal_type,
        (payments_late + payments_missed) AS signal_value,
        -- Score: ratio of late+missed to total payments
        CASE
            WHEN total_payments = 0 THEN 0.0
            ELSE LEAST(1.0, (payments_late + payments_missed)::FLOAT / NULLIF(total_payments, 0) * 2.5)
        END                     AS signal_score,
        0.15                    AS signal_weight,
        'stable'                AS signal_direction,
        CASE
            WHEN payments_late + payments_missed = 0 THEN 'All payments on time'
            ELSE (payments_late + payments_missed)::VARCHAR ||
                 ' late/missed of ' || total_payments::VARCHAR || ' total payments'
        END                     AS evidence_text
    FROM wide_signals

    UNION ALL

    -- 5. COMPLAINT_ACTIVITY
    SELECT
        customer_id,
        'complaint_activity'    AS signal_type,
        (complaint_count_90d + escalation_count_90d) AS signal_value,
        CASE
            WHEN complaint_count_90d + escalation_count_90d = 0 THEN 0.0
            WHEN escalation_count_90d > 0                       THEN 1.0
            WHEN complaint_count_90d >= 2                       THEN 0.8
            WHEN complaint_count_90d = 1                        THEN 0.5
            ELSE 0.0
        END                     AS signal_score,
        0.10                    AS signal_weight,
        CASE
            WHEN escalation_count_90d > 0 THEN 'worsening'
            WHEN complaint_count_90d > 0  THEN 'stable'
            ELSE 'stable'
        END                     AS signal_direction,
        CASE
            WHEN complaint_count_90d + escalation_count_90d = 0
            THEN 'No complaints or escalations in 90 days'
            ELSE complaint_count_90d::VARCHAR || ' complaint(s), ' ||
                 escalation_count_90d::VARCHAR || ' escalation(s) in 90 days'
        END                     AS evidence_text
    FROM wide_signals

    UNION ALL

    -- 6. CLAIM_ACTIVITY
    SELECT
        customer_id,
        'claim_activity'        AS signal_type,
        open_claims             AS signal_value,
        CASE
            WHEN open_claims = 0 THEN 0.0
            WHEN open_claims = 1 THEN 0.4
            ELSE 0.8
        END                     AS signal_score,
        0.05                    AS signal_weight,
        'stable'                AS signal_direction,
        CASE
            WHEN open_claims = 0 THEN 'No open claims'
            ELSE open_claims::VARCHAR || ' open claim(s) — active service load'
        END                     AS evidence_text
    FROM wide_signals

    UNION ALL

    -- 7. ENGAGEMENT_DROP
    SELECT
        customer_id,
        'engagement_drop'       AS signal_type,
        interactions_current_90d AS signal_value,
        -- Score: more current interactions without resolution = risk
        CASE
            WHEN interactions_current_90d > interactions_prior_90d + 2  THEN 0.7
            WHEN interactions_current_90d > interactions_prior_90d      THEN 0.3
            ELSE 0.0
        END                     AS signal_score,
        0.05                    AS signal_weight,
        CASE
            WHEN interactions_current_90d > interactions_prior_90d + 1 THEN 'worsening'
            WHEN interactions_current_90d < interactions_prior_90d - 1 THEN 'improving'
            ELSE 'stable'
        END                     AS signal_direction,
        interactions_current_90d::VARCHAR || ' interactions in last 90d vs ' ||
        interactions_prior_90d::VARCHAR || ' in prior 90d'
                                AS evidence_text
    FROM wide_signals

    UNION ALL

    -- 8. CROSS_SELL_OPPORTUNITY (positive signal — not risk)
    SELECT
        customer_id,
        'cross_sell_opportunity' AS signal_type,
        CASE WHEN missing_home THEN 1 ELSE 0 END +
        CASE WHEN missing_umbrella THEN 1 ELSE 0 END
                                AS signal_value,
        -- Score: opportunity score (not risk). Higher = more opportunity.
        CASE
            WHEN active_policies >= 2 AND missing_home     THEN 0.7
            WHEN active_policies >= 2 AND missing_umbrella THEN 0.6
            WHEN active_policies = 1                       THEN 0.4
            ELSE 0.0
        END                     AS signal_score,
        0.00                    AS signal_weight,  -- weight=0: informational, does not affect risk
        'stable'                AS signal_direction,
        CASE
            WHEN NOT missing_home AND NOT missing_umbrella
            THEN 'Full product suite — no cross-sell gap'
            ELSE 'Missing: ' ||
                 CASE WHEN missing_home THEN 'home ' ELSE '' END ||
                 CASE WHEN missing_umbrella THEN 'umbrella ' ELSE '' END ||
                 '(' || active_policies::VARCHAR || ' active policies)'
        END                     AS evidence_text
    FROM wide_signals
)

SELECT
    s.customer_id,
    s.signal_type,
    s.signal_value,
    ROUND(s.signal_score, 3)                            AS signal_score,
    s.signal_weight,
    ROUND(s.signal_score * s.signal_weight, 4)          AS weighted_score,
    s.signal_direction,
    s.evidence_text,
    CURRENT_TIMESTAMP()                                 AS computed_at
FROM all_signals s;


-- =============================================================================
-- Composite risk score view: one row per customer with overall risk
-- =============================================================================
CREATE OR REPLACE VIEW CUSTOMER_RISK_SUMMARY AS
SELECT
    customer_id,
    -- Weighted composite risk score (0.0 = no risk, 1.0 = maximum risk)
    ROUND(SUM(weighted_score), 3)                       AS composite_risk_score,

    -- Risk tier for display
    CASE
        WHEN SUM(weighted_score) >= 0.40 THEN 'critical'
        WHEN SUM(weighted_score) >= 0.25 THEN 'high'
        WHEN SUM(weighted_score) >= 0.10 THEN 'medium'
        ELSE                                  'low'
    END                                                 AS risk_tier,

    -- Count of signals by direction
    COUNT(CASE WHEN signal_direction = 'worsening' THEN 1 END) AS worsening_signals,
    COUNT(CASE WHEN signal_direction = 'improving' THEN 1 END) AS improving_signals,

    -- Top contributing signal
    MAX(CASE WHEN signal_weight > 0
         THEN signal_type END)                          AS top_signal_type,

    -- Overall direction
    CASE
        WHEN COUNT(CASE WHEN signal_direction = 'worsening' THEN 1 END) >= 2 THEN 'worsening'
        WHEN COUNT(CASE WHEN signal_direction = 'worsening' THEN 1 END) >= 1
             AND COUNT(CASE WHEN signal_direction = 'improving' THEN 1 END) = 0 THEN 'worsening'
        WHEN COUNT(CASE WHEN signal_direction = 'improving' THEN 1 END) >= 2 THEN 'improving'
        ELSE 'stable'
    END                                                 AS overall_direction,

    COUNT(*)                                            AS signal_count,
    CURRENT_TIMESTAMP()                                 AS computed_at

FROM CUSTOMER_RISK_SIGNALS
GROUP BY customer_id;


-- =============================================================================
-- Verification queries
-- =============================================================================

-- Risk summary distribution
SELECT risk_tier, COUNT(*) AS customer_count
FROM CUSTOMER_RISK_SUMMARY
GROUP BY 1
ORDER BY
    CASE risk_tier WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END;

-- Golden demo: Maria Chen risk signals
SELECT signal_type, signal_value, signal_score, signal_weight,
       weighted_score, signal_direction, evidence_text
FROM CUSTOMER_RISK_SIGNALS
WHERE customer_id = 'CUST-001'
ORDER BY weighted_score DESC;

-- Maria Chen risk summary
SELECT * FROM CUSTOMER_RISK_SUMMARY WHERE customer_id = 'CUST-001';
