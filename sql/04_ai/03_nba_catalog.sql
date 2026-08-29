-- =============================================================================
-- sql/04_ai/03_nba_catalog.sql
-- Purpose: Reference tables for the Next Best Action engine.
--          ACTION_LIBRARY defines candidate actions with eligibility rules.
--          SIGNAL_WEIGHTS defines scoring configuration.
--          Both are config tables — no Cortex calls.
-- Role: C360_DATA_ENGINEER
-- Idempotent: CREATE OR REPLACE + MERGE (safe rerun)
-- Cost: Zero. Pure DDL and config data.
-- =============================================================================

USE DATABASE CUSTOMER360_DB;
USE SCHEMA ANALYTICS;

-- =============================================================================
-- ACTION_LIBRARY
-- Grain: One row per action_type × product_type eligibility rule.
-- The NBA engine filters this catalog by product type and risk signals.
-- =============================================================================
CREATE TABLE IF NOT EXISTS ACTION_LIBRARY (
    action_id               VARCHAR(30)     NOT NULL    COMMENT 'PK — action identifier',
    action_type             VARCHAR(30)     NOT NULL    COMMENT 'Action category code',
    action_name             VARCHAR(100)    NOT NULL    COMMENT 'Human-readable action name',
    action_description      VARCHAR(2000)   NOT NULL    COMMENT 'Full action text shown to representative',
    action_category         VARCHAR(30)     NOT NULL    COMMENT 'Category: retention, service, sales, administrative',
    safety_score            FLOAT           NOT NULL    COMMENT 'Baseline safety: 1.0 = safest, 0.0 = riskiest',
    priority_rank           NUMBER(3,0)     NOT NULL    COMMENT 'Default priority (lower = higher priority)',
    eligible_products       VARCHAR(200)    NOT NULL    COMMENT 'Comma-separated product types or ALL',
    excluded_products       VARCHAR(200)                COMMENT 'Products where this action is ineligible',
    requires_risk_tier      VARCHAR(100)                COMMENT 'Only offered when risk_tier IN this list (null = any)',
    requires_signal         VARCHAR(100)                COMMENT 'Only offered when this signal_type is present with score > 0',
    _loaded_at              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_action_library PRIMARY KEY (action_id)
)
COMMENT = 'NBA action catalog. Defines candidate actions, eligibility, and safety profiles.';

-- Idempotent load via MERGE
MERGE INTO ACTION_LIBRARY tgt
USING (
    SELECT * FROM VALUES
    -- =================================================================
    -- RETENTION actions — offered when negative signals exist
    -- =================================================================
    (
        'ACT-001', 'retention_outreach', 'Retention Outreach',
        'Acknowledge prior service issues, offer an eligible loyalty adjustment subject to policy rules and representative approval, and confirm that current coverage still meets the customer''s needs.',
        'retention', 0.95, 1,
        'ALL', NULL,
        'critical,high',           -- only when risk is elevated
        'sentiment_negative'       -- requires negative sentiment signal
    ),
    (
        'ACT-002', 'renewal_reminder', 'Proactive Renewal Reminder',
        'Proactively discuss the upcoming renewal, review current coverage, confirm pricing, and address any concerns before the renewal date.',
        'retention', 0.90, 2,
        'ALL', NULL,
        NULL,                       -- any risk tier (also useful for low-risk)
        'renewal_proximity'         -- requires renewal proximity signal
    ),

    -- =================================================================
    -- SERVICE actions — offered when complaints/claims are active
    -- =================================================================
    (
        'ACT-003', 'complaint_followup', 'Complaint Follow-Up',
        'Acknowledge the specific complaint, provide a status update, outline next steps with a clear timeline, and confirm a named point of contact for resolution.',
        'service', 0.85, 3,
        'ALL', NULL,
        'critical,high,medium',
        'complaint_activity'
    ),
    (
        'ACT-004', 'claim_escalation', 'Claim Process Escalation',
        'Escalate the open claim to a senior adjuster, provide the customer with a direct reference number, and set expectations for the next update within 2 business days.',
        'service', 0.70, 4,
        'ALL', NULL,
        'critical,high',
        'claim_activity'
    ),
    (
        'ACT-005', 'billing_assistance', 'Billing Assistance',
        'Review current payment status, explain any outstanding balance or recent changes, and offer available payment arrangement options if the customer is experiencing difficulty.',
        'service', 0.80, 5,
        'ALL', NULL,
        NULL,
        'payment_risk'
    ),

    -- =================================================================
    -- SALES actions — offered when cross-sell opportunity exists
    -- =================================================================
    (
        'ACT-006', 'cross_sell_home', 'Cross-Sell: Home Insurance',
        'Based on the customer''s existing auto policy and property ownership indicators, discuss available homeowners insurance options and potential multi-policy discount.',
        'sales', 0.60, 6,
        'auto', NULL,               -- only for auto policyholders
        'low,medium',               -- not during active complaints
        'cross_sell_opportunity'
    ),
    (
        'ACT-007', 'cross_sell_umbrella', 'Cross-Sell: Umbrella Policy',
        'Given the customer''s multi-policy relationship, discuss umbrella liability coverage that extends protection across existing auto and home policies.',
        'sales', 0.55, 7,
        'auto,home', NULL,           -- requires 2+ policies
        'low,medium',
        'cross_sell_opportunity'
    ),

    -- =================================================================
    -- ADMINISTRATIVE — default when no signals warrant intervention
    -- =================================================================
    (
        'ACT-008', 'no_action', 'No Proactive Action Required',
        'Customer profile shows no elevated risk signals. Handle the current inquiry normally. No proactive retention or sales action recommended at this time.',
        'administrative', 1.00, 8,
        'ALL', NULL,
        'low',
        NULL                        -- no signal required — this is the fallback
    )

    AS src (
        action_id, action_type, action_name, action_description,
        action_category, safety_score, priority_rank,
        eligible_products, excluded_products,
        requires_risk_tier, requires_signal
    )
) src
ON tgt.action_id = src.action_id
WHEN MATCHED THEN UPDATE SET
    action_type       = src.action_type,
    action_name       = src.action_name,
    action_description = src.action_description,
    action_category   = src.action_category,
    safety_score      = src.safety_score,
    priority_rank     = src.priority_rank,
    eligible_products = src.eligible_products,
    excluded_products = src.excluded_products,
    requires_risk_tier = src.requires_risk_tier,
    requires_signal   = src.requires_signal,
    _loaded_at        = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    action_id, action_type, action_name, action_description,
    action_category, safety_score, priority_rank,
    eligible_products, excluded_products,
    requires_risk_tier, requires_signal
)
VALUES (
    src.action_id, src.action_type, src.action_name, src.action_description,
    src.action_category, src.safety_score, src.priority_rank,
    src.eligible_products, src.excluded_products,
    src.requires_risk_tier, src.requires_signal
);


-- =============================================================================
-- SIGNAL_WEIGHTS
-- One row per signal_type. Mirrors the weights in CUSTOMER_RISK_SIGNALS view.
-- Externalized here so the Streamlit app can read them for display and
-- so they can be adjusted without modifying the view.
-- =============================================================================
CREATE TABLE IF NOT EXISTS SIGNAL_WEIGHTS (
    signal_type             VARCHAR(30)     NOT NULL    COMMENT 'Matches signal_type in CUSTOMER_RISK_SIGNALS',
    signal_name             VARCHAR(100)    NOT NULL    COMMENT 'Human-readable name',
    signal_weight           FLOAT           NOT NULL    COMMENT 'Weight in composite score (sum should = 1.0)',
    signal_description      VARCHAR(500)    NOT NULL    COMMENT 'What this signal measures',
    is_risk_signal          BOOLEAN         NOT NULL    COMMENT 'TRUE = contributes to risk. FALSE = informational.',
    _loaded_at              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_signal_weights PRIMARY KEY (signal_type)
)
COMMENT = 'NBA signal weight configuration. Externalized for auditability and tuning.';

MERGE INTO SIGNAL_WEIGHTS tgt
USING (
    SELECT * FROM VALUES
    ('renewal_proximity',   'Renewal Proximity',     0.30, 'Days until nearest policy renewal date',               TRUE),
    ('sentiment_negative',  'Negative Sentiment',    0.25, 'Count and severity of negative interactions in 90 days', TRUE),
    ('sentiment_trend',     'Sentiment Trend',       0.10, 'Direction of sentiment change (current vs prior 90d)',  TRUE),
    ('payment_risk',        'Payment Risk',          0.15, 'Ratio of late/missed payments to total',                TRUE),
    ('complaint_activity',  'Complaint Activity',    0.10, 'Recent complaints and escalation requests',             TRUE),
    ('claim_activity',      'Claim Activity',        0.05, 'Open and recent claims indicating service load',        TRUE),
    ('engagement_drop',     'Engagement Change',     0.05, 'Change in interaction frequency',                       TRUE),
    ('cross_sell_opportunity', 'Cross-Sell Gap',     0.00, 'Missing product types relative to household profile',   FALSE)
    AS src (signal_type, signal_name, signal_weight, signal_description, is_risk_signal)
) src
ON tgt.signal_type = src.signal_type
WHEN MATCHED THEN UPDATE SET
    signal_name = src.signal_name,
    signal_weight = src.signal_weight,
    signal_description = src.signal_description,
    is_risk_signal = src.is_risk_signal,
    _loaded_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (signal_type, signal_name, signal_weight, signal_description, is_risk_signal)
VALUES (src.signal_type, src.signal_name, src.signal_weight, src.signal_description, src.is_risk_signal);


-- =============================================================================
-- Verification
-- =============================================================================
SELECT 'ACTION_LIBRARY' AS table_name, COUNT(*) AS row_count FROM ACTION_LIBRARY
UNION ALL
SELECT 'SIGNAL_WEIGHTS', COUNT(*) FROM SIGNAL_WEIGHTS;

SELECT action_id, action_type, action_category, safety_score,
       eligible_products, requires_risk_tier, requires_signal
FROM ACTION_LIBRARY
ORDER BY priority_rank;

SELECT signal_type, signal_weight, is_risk_signal
FROM SIGNAL_WEIGHTS
ORDER BY signal_weight DESC;
