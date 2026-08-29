-- =============================================================================
-- sql/03_customer360/08_customer360_enriched.sql
-- Purpose: Unified enriched Customer 360 view combining:
--          1. CUSTOMER_360_BASE (identity, policy, claims, payments, interactions)
--          2. CUSTOMER_RISK_SUMMARY (composite risk + direction)
--          3. NBA_PRIMARY_RECOMMENDATION (top action + confidence)
--          4. Sentiment aggregates from INTERACTIONS_ENRICHED
--          This is the single query the Streamlit app uses for a customer lookup.
-- Role: C360_DATA_ENGINEER
-- Idempotent: CREATE OR REPLACE VIEW (safe rerun)
-- Cost: Zero Cortex credits. View over pre-computed tables/views.
-- Note: CURRENT_DATE() is used here in the view (not in a DT) so it does
--       not block incremental refresh on upstream dynamic tables.
-- =============================================================================

USE DATABASE CUSTOMER360_DB;
USE SCHEMA ANALYTICS;

-- =============================================================================
-- Sentiment aggregates per customer from INTERACTIONS_ENRICHED
-- Extracted as a standalone view for reuse by semantic model and app
-- =============================================================================
CREATE OR REPLACE VIEW CUSTOMER_SENTIMENT_SUMMARY AS
SELECT
    customer_id,

    -- 90-day window
    COUNT(CASE WHEN enrichment_status = 'completed'
               AND interaction_date >= DATEADD('day', -90, CURRENT_TIMESTAMP())
          THEN 1 END)                                               AS enriched_interactions_90d,
    COUNT(CASE WHEN sentiment_label = 'negative'
               AND interaction_date >= DATEADD('day', -90, CURRENT_TIMESTAMP())
          THEN 1 END)                                               AS negative_count_90d,
    COUNT(CASE WHEN sentiment_label = 'positive'
               AND interaction_date >= DATEADD('day', -90, CURRENT_TIMESTAMP())
          THEN 1 END)                                               AS positive_count_90d,
    ROUND(AVG(CASE WHEN enrichment_status = 'completed'
                   AND interaction_date >= DATEADD('day', -90, CURRENT_TIMESTAMP())
              THEN sentiment_score END), 3)                         AS avg_sentiment_90d,
    MIN(CASE WHEN interaction_date >= DATEADD('day', -90, CURRENT_TIMESTAMP())
        THEN sentiment_score END)                                   AS worst_sentiment_90d,

    -- Prior 90-day window (91–180 days ago)
    ROUND(AVG(CASE WHEN enrichment_status = 'completed'
                   AND interaction_date >= DATEADD('day', -180, CURRENT_TIMESTAMP())
                   AND interaction_date <  DATEADD('day', -90, CURRENT_TIMESTAMP())
              THEN sentiment_score END), 3)                         AS avg_sentiment_prior_90d,

    -- Sentiment direction
    CASE
        WHEN AVG(CASE WHEN enrichment_status = 'completed'
                      AND interaction_date >= DATEADD('day', -90, CURRENT_TIMESTAMP())
                 THEN sentiment_score END) IS NULL THEN 'insufficient_data'
        WHEN AVG(CASE WHEN enrichment_status = 'completed'
                      AND interaction_date >= DATEADD('day', -180, CURRENT_TIMESTAMP())
                      AND interaction_date <  DATEADD('day', -90, CURRENT_TIMESTAMP())
                 THEN sentiment_score END) IS NULL THEN 'insufficient_data'
        WHEN AVG(CASE WHEN enrichment_status = 'completed'
                      AND interaction_date >= DATEADD('day', -90, CURRENT_TIMESTAMP())
                 THEN sentiment_score END)
             < AVG(CASE WHEN enrichment_status = 'completed'
                        AND interaction_date >= DATEADD('day', -180, CURRENT_TIMESTAMP())
                        AND interaction_date <  DATEADD('day', -90, CURRENT_TIMESTAMP())
                   THEN sentiment_score END) - 0.1 THEN 'worsening'
        WHEN AVG(CASE WHEN enrichment_status = 'completed'
                      AND interaction_date >= DATEADD('day', -90, CURRENT_TIMESTAMP())
                 THEN sentiment_score END)
             > AVG(CASE WHEN enrichment_status = 'completed'
                        AND interaction_date >= DATEADD('day', -180, CURRENT_TIMESTAMP())
                        AND interaction_date <  DATEADD('day', -90, CURRENT_TIMESTAMP())
                   THEN sentiment_score END) + 0.1 THEN 'improving'
        ELSE 'stable'
    END                                                             AS sentiment_direction,

    -- Recent interactions with sentiment (for timeline display)
    ARRAY_AGG(
        CASE WHEN enrichment_status = 'completed'
              AND interaction_date >= DATEADD('day', -180, CURRENT_TIMESTAMP())
        THEN OBJECT_CONSTRUCT(
            'interaction_id', interaction_id,
            'date',           interaction_date::VARCHAR,
            'channel',        channel,
            'disposition',    disposition,
            'sentiment_score', ROUND(sentiment_score, 3),
            'sentiment_label', sentiment_label,
            'summary',        summary,
            'topic',          primary_topic,
            'intent',         primary_intent,
            'urgency',        urgency_level,
            'is_complaint',   is_complaint
        ) END
    ) WITHIN GROUP (ORDER BY interaction_date DESC)                 AS recent_interaction_details,

    -- Enrichment coverage
    COUNT(CASE WHEN transcript_id IS NOT NULL THEN 1 END)           AS transcripts_total,
    COUNT(CASE WHEN enrichment_status = 'completed' THEN 1 END)     AS transcripts_enriched,
    ROUND(
        COUNT(CASE WHEN enrichment_status = 'completed' THEN 1 END)::FLOAT /
        NULLIF(COUNT(CASE WHEN transcript_id IS NOT NULL THEN 1 END), 0),
        2
    )                                                               AS enrichment_coverage_pct

FROM INTERACTIONS_ENRICHED
GROUP BY customer_id;


-- =============================================================================
-- CUSTOMER_360_ENRICHED
-- The master view: everything the Streamlit app needs in one SELECT.
-- Grain: One row per customer.
-- =============================================================================
CREATE OR REPLACE VIEW CUSTOMER_360_ENRICHED AS
SELECT
    -- =========================================================================
    -- Section 1: Identity and household (from CUSTOMER_360_BASE)
    -- =========================================================================
    b.customer_sk,
    b.customer_id,
    b.first_name,
    b.last_name,
    b.date_of_birth,
    b.email,
    b.phone,
    b.address_line_1,
    b.city,
    b.state,
    b.postal_code,
    b.customer_since,
    b.customer_status,
    b.household_sk,
    b.household_id,
    b.household_member_count,

    -- =========================================================================
    -- Section 2: Policy summary
    -- =========================================================================
    b.total_policies,
    b.active_policies,
    b.distinct_product_count,
    b.product_holdings,
    b.nearest_renewal_date,
    -- days_to_renewal computed here (not in a DT) to avoid CURRENT_DATE() trap
    DATEDIFF('day', CURRENT_DATE(), b.nearest_renewal_date) AS days_to_renewal,
    b.total_annual_premium,
    b.active_annual_premium,

    -- =========================================================================
    -- Section 3: Claims summary
    -- =========================================================================
    b.total_claims,
    b.open_claims,
    b.settled_claims,
    b.denied_claims,
    b.total_reserve_amount,
    b.claims_total_paid,

    -- =========================================================================
    -- Section 4: Payment summary
    -- =========================================================================
    b.total_payments,
    b.payments_on_time,
    b.payments_late,
    b.payments_missed,
    b.payments_grace_period,
    b.payments_pending,
    b.latest_paid_date,

    -- =========================================================================
    -- Section 5: Interaction summary (structured)
    -- =========================================================================
    b.total_interactions,
    b.interactions_inbound,
    b.interactions_outbound,
    b.latest_interaction_date,
    b.latest_channel,
    b.interactions_complaints,

    -- =========================================================================
    -- Section 6: AI-enriched sentiment (from CUSTOMER_SENTIMENT_SUMMARY)
    -- =========================================================================
    COALESCE(ss.enriched_interactions_90d, 0)   AS enriched_interactions_90d,
    COALESCE(ss.negative_count_90d, 0)          AS negative_count_90d,
    COALESCE(ss.positive_count_90d, 0)          AS positive_count_90d,
    ss.avg_sentiment_90d,
    ss.worst_sentiment_90d,
    ss.avg_sentiment_prior_90d,
    COALESCE(ss.sentiment_direction, 'insufficient_data') AS sentiment_direction,
    ss.recent_interaction_details,
    COALESCE(ss.enrichment_coverage_pct, 0)     AS enrichment_coverage_pct,

    -- =========================================================================
    -- Section 7: Risk signals (from CUSTOMER_RISK_SUMMARY)
    -- =========================================================================
    COALESCE(rs.composite_risk_score, 0)        AS composite_risk_score,
    COALESCE(rs.risk_tier, 'low')               AS risk_tier,
    rs.worsening_signals,
    rs.improving_signals,
    COALESCE(rs.overall_direction, 'stable')    AS risk_direction,

    -- =========================================================================
    -- Section 8: NBA recommendation (from NBA_PRIMARY_RECOMMENDATION)
    -- =========================================================================
    nba.action_id                               AS nba_action_id,
    nba.action_type                             AS nba_action_type,
    nba.action_name                             AS nba_action_name,
    nba.action_description                      AS nba_action_description,
    nba.action_category                         AS nba_action_category,
    COALESCE(nba.final_score, 0)                AS nba_final_score,
    COALESCE(nba.confidence_level, 'low')       AS nba_confidence_level,
    COALESCE(nba.confidence_score, 0)           AS nba_confidence_score,
    nba.evidence_signals                        AS nba_evidence_signals,
    nba.data_completeness                       AS nba_data_completeness,
    nba.eligibility_check                       AS nba_eligibility_check,
    nba.generated_at                            AS nba_generated_at,

    -- =========================================================================
    -- Section 9: Data completeness flags
    -- =========================================================================
    b.has_email,
    b.has_phone,
    b.has_dob,
    b.has_policies,
    b.has_claims,
    b.has_payments,
    b.has_interactions,
    CASE WHEN COALESCE(ss.enriched_interactions_90d, 0) > 0 THEN TRUE ELSE FALSE END
                                                AS has_enrichment,
    CASE WHEN rs.composite_risk_score IS NOT NULL THEN TRUE ELSE FALSE END
                                                AS has_risk_signals,
    CASE WHEN nba.action_id IS NOT NULL THEN TRUE ELSE FALSE END
                                                AS has_recommendation,

    -- =========================================================================
    -- Section 10: Fallback / degradation indicators
    -- =========================================================================
    CASE
        WHEN COALESCE(ss.enriched_interactions_90d, 0) = 0
             AND b.has_interactions THEN 'degraded_no_enrichment'
        WHEN nba.action_id IS NULL                THEN 'degraded_no_recommendation'
        WHEN nba.confidence_level = 'low'         THEN 'low_confidence'
        ELSE 'full'
    END                                         AS system_status,

    CASE
        WHEN COALESCE(ss.enriched_interactions_90d, 0) = 0
             AND b.has_interactions
        THEN 'AI enrichment unavailable — showing structured data only. Recommendation withheld.'
        WHEN nba.action_id IS NULL
        THEN 'Insufficient signals for a recommendation. Please review available context.'
        WHEN nba.confidence_level = 'low'
        THEN 'Low confidence — limited enrichment data. Review evidence carefully.'
        ELSE NULL
    END                                         AS system_message,

    -- Audit
    CURRENT_TIMESTAMP()                         AS view_refreshed_at

FROM CUSTOMER_360_BASE b
LEFT JOIN CUSTOMER_SENTIMENT_SUMMARY ss  ON b.customer_id = ss.customer_id
LEFT JOIN CUSTOMER_RISK_SUMMARY rs       ON b.customer_id = rs.customer_id
LEFT JOIN NBA_PRIMARY_RECOMMENDATION nba ON b.customer_id = nba.customer_id;


-- =============================================================================
-- Verification queries
-- =============================================================================

-- Golden demo: Maria Chen full enriched profile
SELECT
    customer_id, first_name, last_name,
    days_to_renewal, active_policies, product_holdings,
    negative_count_90d, avg_sentiment_90d, sentiment_direction,
    composite_risk_score, risk_tier, risk_direction,
    nba_action_type, nba_action_name, nba_confidence_level,
    nba_final_score, system_status
FROM CUSTOMER_360_ENRICHED
WHERE customer_id = 'CUST-001';

-- System status distribution
SELECT system_status, COUNT(*) AS customer_count
FROM CUSTOMER_360_ENRICHED
GROUP BY 1
ORDER BY customer_count DESC;

-- Risk tier × NBA action distribution
SELECT risk_tier, nba_action_type, COUNT(*) AS cnt
FROM CUSTOMER_360_ENRICHED
GROUP BY 1, 2
ORDER BY risk_tier, cnt DESC;

-- Enrichment coverage
SELECT
    COUNT(*) AS total_customers,
    COUNT(CASE WHEN has_enrichment THEN 1 END) AS with_enrichment,
    COUNT(CASE WHEN has_recommendation THEN 1 END) AS with_recommendation,
    COUNT(CASE WHEN system_status = 'full' THEN 1 END) AS fully_operational
FROM CUSTOMER_360_ENRICHED;

-- Maria Chen: evidence trail for primary recommendation
SELECT
    nba_action_name,
    nba_confidence_level,
    nba_evidence_signals,
    nba_data_completeness,
    recent_interaction_details
FROM CUSTOMER_360_ENRICHED
WHERE customer_id = 'CUST-001';
