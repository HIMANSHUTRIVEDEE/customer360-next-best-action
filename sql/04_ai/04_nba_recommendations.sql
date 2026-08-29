-- =============================================================================
-- sql/04_ai/04_nba_recommendations.sql
-- Purpose: Deterministic Next Best Action recommendation engine.
--          Scores candidate actions against customer risk signals,
--          filters by eligibility, ranks by (relevance × safety),
--          and produces an explainable recommendation with evidence.
-- Role: C360_DATA_ENGINEER
-- Idempotent: CREATE OR REPLACE VIEW (safe rerun)
-- Cost: Zero Cortex credits. Pure SQL scoring engine.
-- Design: Every recommendation includes:
--   - Ranked action with confidence level
--   - Evidence trail (which signals triggered it)
--   - Alternative actions (top 3)
--   - Data completeness indicator
--   - Supports human approval gate (does not auto-execute)
-- =============================================================================

USE DATABASE CUSTOMER360_DB;
USE SCHEMA ANALYTICS;

-- =============================================================================
-- NBA_RECOMMENDATIONS
-- Grain: One row per customer × recommended action.
--        Returns the top recommendation plus up to 3 alternatives.
-- =============================================================================
CREATE OR REPLACE VIEW NBA_RECOMMENDATIONS AS

WITH risk AS (
    SELECT * FROM CUSTOMER_RISK_SUMMARY
),

signals AS (
    SELECT * FROM CUSTOMER_RISK_SIGNALS
),

-- Collect signals per customer as a structured evidence array
customer_signals AS (
    SELECT
        customer_id,
        ARRAY_AGG(
            OBJECT_CONSTRUCT(
                'signal_type',   signal_type,
                'signal_score',  signal_score,
                'signal_weight', signal_weight,
                'weighted_score', weighted_score,
                'direction',     signal_direction,
                'evidence',      evidence_text
            )
        ) WITHIN GROUP (ORDER BY weighted_score DESC)   AS signal_array,
        -- Bitflags: which signals are active (score > 0)
        MAX(CASE WHEN signal_type = 'renewal_proximity'   AND signal_score > 0 THEN 1 ELSE 0 END) AS has_renewal,
        MAX(CASE WHEN signal_type = 'sentiment_negative'  AND signal_score > 0 THEN 1 ELSE 0 END) AS has_negative_sentiment,
        MAX(CASE WHEN signal_type = 'sentiment_trend'     AND signal_score > 0.1 THEN 1 ELSE 0 END) AS has_sentiment_trend,
        MAX(CASE WHEN signal_type = 'payment_risk'        AND signal_score > 0 THEN 1 ELSE 0 END) AS has_payment_risk,
        MAX(CASE WHEN signal_type = 'complaint_activity'  AND signal_score > 0 THEN 1 ELSE 0 END) AS has_complaint,
        MAX(CASE WHEN signal_type = 'claim_activity'      AND signal_score > 0 THEN 1 ELSE 0 END) AS has_claim,
        MAX(CASE WHEN signal_type = 'engagement_drop'     AND signal_score > 0 THEN 1 ELSE 0 END) AS has_engagement_drop,
        MAX(CASE WHEN signal_type = 'cross_sell_opportunity' AND signal_score > 0 THEN 1 ELSE 0 END) AS has_cross_sell
    FROM signals
    GROUP BY customer_id
),

-- Customer product context for eligibility filtering
customer_products AS (
    SELECT
        customer_id,
        product_holdings,
        active_policies
    FROM AGG_CUSTOMER_POLICY
),

-- Data completeness check: how many enriched interactions exist
enrichment_coverage AS (
    SELECT
        customer_id,
        COUNT(*) AS total_interactions,
        COUNT(CASE WHEN enrichment_status = 'completed' THEN 1 END) AS enriched_count,
        COUNT(CASE WHEN enrichment_status = 'failed' THEN 1 END)    AS failed_count,
        ROUND(
            COUNT(CASE WHEN enrichment_status = 'completed' THEN 1 END)::FLOAT /
            NULLIF(COUNT(CASE WHEN transcript_id IS NOT NULL THEN 1 END), 0),
            2
        ) AS enrichment_coverage_pct
    FROM INTERACTIONS_ENRICHED
    GROUP BY customer_id
),

-- Cross join: every customer × every action
candidate_matrix AS (
    SELECT
        r.customer_id,
        r.composite_risk_score,
        r.risk_tier,
        r.overall_direction,
        cs.signal_array,
        cs.has_renewal,
        cs.has_negative_sentiment,
        cs.has_sentiment_trend,
        cs.has_payment_risk,
        cs.has_complaint,
        cs.has_claim,
        cs.has_engagement_drop,
        cs.has_cross_sell,
        cp.product_holdings,
        cp.active_policies,
        COALESCE(ec.enrichment_coverage_pct, 0) AS enrichment_coverage_pct,
        COALESCE(ec.enriched_count, 0)          AS enriched_count,
        a.action_id,
        a.action_type,
        a.action_name,
        a.action_description,
        a.action_category,
        a.safety_score,
        a.priority_rank,
        a.eligible_products,
        a.excluded_products,
        a.requires_risk_tier,
        a.requires_signal
    FROM risk r
    JOIN customer_signals cs     ON r.customer_id  = cs.customer_id
    LEFT JOIN customer_products cp ON r.customer_id = cp.customer_id
    LEFT JOIN enrichment_coverage ec ON r.customer_id = ec.customer_id
    CROSS JOIN ACTION_LIBRARY a
),

-- Filter: eligibility check
eligible_actions AS (
    SELECT
        cm.*,

        -- Eligibility gate 1: product type match
        CASE
            WHEN cm.eligible_products = 'ALL' THEN TRUE
            -- Check if any of the customer's products appear in the eligible list
            WHEN cm.product_holdings IS NOT NULL AND (
                (cm.eligible_products LIKE '%auto%'     AND cm.product_holdings LIKE '%auto%') OR
                (cm.eligible_products LIKE '%home%'     AND cm.product_holdings LIKE '%home%') OR
                (cm.eligible_products LIKE '%umbrella%' AND cm.product_holdings LIKE '%umbrella%') OR
                (cm.eligible_products LIKE '%renters%'  AND cm.product_holdings LIKE '%renters%')
            ) THEN TRUE
            ELSE FALSE
        END AS product_eligible,

        -- Eligibility gate 2: not excluded
        CASE
            WHEN cm.excluded_products IS NULL THEN TRUE
            WHEN cm.product_holdings IS NOT NULL AND (
                (cm.excluded_products LIKE '%auto%'     AND cm.product_holdings LIKE '%auto%') OR
                (cm.excluded_products LIKE '%home%'     AND cm.product_holdings LIKE '%home%') OR
                (cm.excluded_products LIKE '%umbrella%' AND cm.product_holdings LIKE '%umbrella%') OR
                (cm.excluded_products LIKE '%renters%'  AND cm.product_holdings LIKE '%renters%')
            ) THEN FALSE
            ELSE TRUE
        END AS not_excluded,

        -- Eligibility gate 3: risk tier match
        CASE
            WHEN cm.requires_risk_tier IS NULL THEN TRUE
            WHEN cm.requires_risk_tier LIKE '%' || cm.risk_tier || '%' THEN TRUE
            ELSE FALSE
        END AS risk_tier_eligible,

        -- Eligibility gate 4: required signal present
        CASE
            WHEN cm.requires_signal IS NULL                                        THEN TRUE
            WHEN cm.requires_signal = 'sentiment_negative'  AND cm.has_negative_sentiment = 1 THEN TRUE
            WHEN cm.requires_signal = 'renewal_proximity'   AND cm.has_renewal = 1            THEN TRUE
            WHEN cm.requires_signal = 'complaint_activity'  AND cm.has_complaint = 1          THEN TRUE
            WHEN cm.requires_signal = 'claim_activity'      AND cm.has_claim = 1              THEN TRUE
            WHEN cm.requires_signal = 'payment_risk'        AND cm.has_payment_risk = 1       THEN TRUE
            WHEN cm.requires_signal = 'cross_sell_opportunity' AND cm.has_cross_sell = 1      THEN TRUE
            ELSE FALSE
        END AS signal_eligible

    FROM candidate_matrix cm
),

-- Score eligible actions
scored_actions AS (
    SELECT
        ea.*,

        -- Relevance score: how well does this action address active signals
        CASE ea.action_type
            WHEN 'retention_outreach' THEN
                0.4 * ea.has_negative_sentiment +
                0.3 * ea.has_renewal +
                0.2 * ea.has_sentiment_trend +
                0.1 * ea.has_complaint
            WHEN 'renewal_reminder' THEN
                0.6 * ea.has_renewal +
                0.2 * ea.has_negative_sentiment +
                0.2 * CASE WHEN ea.risk_tier IN ('low', 'medium') THEN 1 ELSE 0 END
            WHEN 'complaint_followup' THEN
                0.5 * ea.has_complaint +
                0.3 * ea.has_negative_sentiment +
                0.2 * ea.has_engagement_drop
            WHEN 'claim_escalation' THEN
                0.6 * ea.has_claim +
                0.2 * ea.has_complaint +
                0.2 * ea.has_negative_sentiment
            WHEN 'billing_assistance' THEN
                0.7 * ea.has_payment_risk +
                0.2 * ea.has_negative_sentiment +
                0.1 * ea.has_complaint
            WHEN 'cross_sell_home' THEN
                0.5 * ea.has_cross_sell +
                0.3 * CASE WHEN ea.risk_tier = 'low' THEN 1 ELSE 0 END +
                0.2 * ea.has_renewal
            WHEN 'cross_sell_umbrella' THEN
                0.5 * ea.has_cross_sell +
                0.3 * CASE WHEN ea.risk_tier = 'low' THEN 1 ELSE 0 END +
                0.2 * CASE WHEN ea.active_policies >= 2 THEN 1 ELSE 0 END
            WHEN 'no_action' THEN
                CASE WHEN ea.risk_tier = 'low' THEN 0.8 ELSE 0.1 END
            ELSE 0.1
        END AS relevance_score,

        -- Final score = relevance × safety (both 0–1, so product is 0–1)
        CASE ea.action_type
            WHEN 'retention_outreach' THEN
                (0.4 * ea.has_negative_sentiment + 0.3 * ea.has_renewal +
                 0.2 * ea.has_sentiment_trend + 0.1 * ea.has_complaint) * ea.safety_score
            WHEN 'renewal_reminder' THEN
                (0.6 * ea.has_renewal + 0.2 * ea.has_negative_sentiment +
                 0.2 * CASE WHEN ea.risk_tier IN ('low', 'medium') THEN 1 ELSE 0 END) * ea.safety_score
            WHEN 'complaint_followup' THEN
                (0.5 * ea.has_complaint + 0.3 * ea.has_negative_sentiment +
                 0.2 * ea.has_engagement_drop) * ea.safety_score
            WHEN 'claim_escalation' THEN
                (0.6 * ea.has_claim + 0.2 * ea.has_complaint +
                 0.2 * ea.has_negative_sentiment) * ea.safety_score
            WHEN 'billing_assistance' THEN
                (0.7 * ea.has_payment_risk + 0.2 * ea.has_negative_sentiment +
                 0.1 * ea.has_complaint) * ea.safety_score
            WHEN 'cross_sell_home' THEN
                (0.5 * ea.has_cross_sell +
                 0.3 * CASE WHEN ea.risk_tier = 'low' THEN 1 ELSE 0 END +
                 0.2 * ea.has_renewal) * ea.safety_score
            WHEN 'cross_sell_umbrella' THEN
                (0.5 * ea.has_cross_sell +
                 0.3 * CASE WHEN ea.risk_tier = 'low' THEN 1 ELSE 0 END +
                 0.2 * CASE WHEN ea.active_policies >= 2 THEN 1 ELSE 0 END) * ea.safety_score
            WHEN 'no_action' THEN
                CASE WHEN ea.risk_tier = 'low' THEN 0.8 ELSE 0.1 END * ea.safety_score
            ELSE 0.1 * ea.safety_score
        END AS final_score

    FROM eligible_actions ea
    WHERE ea.product_eligible = TRUE
      AND ea.not_excluded = TRUE
      AND ea.risk_tier_eligible = TRUE
      AND ea.signal_eligible = TRUE
),

-- Rank actions per customer
ranked_actions AS (
    SELECT
        sa.*,
        ROW_NUMBER() OVER (PARTITION BY sa.customer_id ORDER BY sa.final_score DESC, sa.priority_rank ASC) AS action_rank
    FROM scored_actions sa
)

-- Final output: one row per customer × rank (top 4 actions)
SELECT
    ra.customer_id,
    ra.action_rank,

    -- Action details
    ra.action_id,
    ra.action_type,
    ra.action_name,
    ra.action_description,
    ra.action_category,

    -- Scoring
    ROUND(ra.relevance_score, 3)    AS relevance_score,
    ROUND(ra.safety_score, 3)       AS safety_score,
    ROUND(ra.final_score, 3)        AS final_score,

    -- Risk context
    ra.risk_tier,
    ROUND(ra.composite_risk_score, 3) AS composite_risk_score,
    ra.overall_direction,

    -- Confidence level: based on enrichment coverage + signal count
    CASE
        WHEN ra.enrichment_coverage_pct >= 0.8 AND ra.enriched_count >= 2 THEN 'high'
        WHEN ra.enrichment_coverage_pct >= 0.5 AND ra.enriched_count >= 1 THEN 'medium_high'
        WHEN ra.enriched_count >= 1                                       THEN 'medium'
        ELSE 'low'
    END                             AS confidence_level,

    -- Numeric confidence for sorting/display
    ROUND(
        LEAST(1.0,
            0.4 * COALESCE(ra.enrichment_coverage_pct, 0) +
            0.3 * LEAST(1.0, ra.enriched_count / 3.0) +
            0.3 * CASE WHEN ra.composite_risk_score > 0 THEN 1 ELSE 0.5 END
        ), 2
    )                               AS confidence_score,

    -- Evidence payload (structured for Streamlit display)
    ra.signal_array                 AS evidence_signals,

    -- Data completeness
    OBJECT_CONSTRUCT(
        'enrichment_coverage_pct', ra.enrichment_coverage_pct,
        'enriched_interactions',   ra.enriched_count,
        'risk_signals_computed',   ARRAY_SIZE(ra.signal_array),
        'has_sentiment_data',      ra.has_negative_sentiment = 1 OR ra.enriched_count > 0
    )                               AS data_completeness,

    -- Product context
    ra.product_holdings,
    ra.active_policies,

    -- Eligibility audit trail
    OBJECT_CONSTRUCT(
        'product_eligible',    ra.product_eligible,
        'not_excluded',        ra.not_excluded,
        'risk_tier_eligible',  ra.risk_tier_eligible,
        'signal_eligible',     ra.signal_eligible
    )                               AS eligibility_check,

    -- Metadata for human approval gate
    FALSE                           AS is_approved,
    NULL                            AS approved_by,
    NULL                            AS approved_at,
    NULL                            AS approval_notes,

    CURRENT_TIMESTAMP()             AS generated_at

FROM ranked_actions ra
WHERE ra.action_rank <= 4;


-- =============================================================================
-- Convenience view: primary recommendation only (rank = 1)
-- =============================================================================
CREATE OR REPLACE VIEW NBA_PRIMARY_RECOMMENDATION AS
SELECT *
FROM NBA_RECOMMENDATIONS
WHERE action_rank = 1;


-- =============================================================================
-- Convenience view: alternatives (rank 2–4)
-- =============================================================================
CREATE OR REPLACE VIEW NBA_ALTERNATIVES AS
SELECT *
FROM NBA_RECOMMENDATIONS
WHERE action_rank BETWEEN 2 AND 4;


-- =============================================================================
-- Verification queries
-- =============================================================================

-- Distribution of primary recommendations
SELECT action_type, COUNT(*) AS customer_count
FROM NBA_PRIMARY_RECOMMENDATION
GROUP BY 1
ORDER BY customer_count DESC;

-- Golden demo: Maria Chen full recommendation
SELECT action_rank, action_type, action_name, final_score,
       confidence_level, confidence_score, risk_tier, composite_risk_score,
       overall_direction
FROM NBA_RECOMMENDATIONS
WHERE customer_id = 'CUST-001'
ORDER BY action_rank;

-- Maria Chen evidence
SELECT evidence_signals, data_completeness, eligibility_check
FROM NBA_PRIMARY_RECOMMENDATION
WHERE customer_id = 'CUST-001';

-- Confidence distribution
SELECT confidence_level, COUNT(*) AS cnt
FROM NBA_PRIMARY_RECOMMENDATION
GROUP BY 1
ORDER BY
    CASE confidence_level
        WHEN 'high' THEN 1 WHEN 'medium_high' THEN 2
        WHEN 'medium' THEN 3 ELSE 4 END;
