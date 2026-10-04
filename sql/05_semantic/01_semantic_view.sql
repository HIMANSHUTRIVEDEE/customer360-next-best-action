-- =============================================================================
-- sql/05_semantic/01_semantic_view.sql
-- Purpose: Create a semantic view over the Customer 360 enriched layer.
--          Enables natural-language querying via Cortex Analyst and Cortex Agent.
--          Covers: identity, policies, claims, payments, interactions,
--                  AI-derived sentiment, risk signals, and NBA recommendations.
-- Role: C360_DATA_ENGINEER (requires CREATE SEMANTIC VIEW on schema)
-- Idempotent: CREATE OR REPLACE SEMANTIC VIEW
-- Cost: Zero Cortex credits. DDL only.
-- =============================================================================

USE ROLE C360_DATA_ENGINEER;
USE DATABASE CUSTOMER360_DB;
USE SCHEMA ANALYTICS;
USE WAREHOUSE CUSTOMER360_WH;

-- =============================================================================
-- Semantic View: SV_CUSTOMER_360
--
-- Single-table semantic view over CUSTOMER_360_ENRICHED.
-- This is a wide, pre-aggregated view (one row per customer) so no
-- relationships are needed — all joins were resolved upstream.
--
-- Design decisions:
--   - ARRAY and OBJECT columns (evidence_signals, data_completeness,
--     recent_interaction_details) are excluded — semantic views cannot
--     meaningfully query semi-structured columns via natural language.
--   - System/audit columns (_loaded_at, view_refreshed_at) are excluded.
--   - Boolean flags are exposed as dimensions with LABELS = (FILTER)
--     so Cortex Analyst can use them in WHERE clauses.
--   - Synonyms are added liberally to map business language to column names.
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW SV_CUSTOMER_360

  TABLES (
    customer AS CUSTOMER360_DB.ANALYTICS.CUSTOMER_360_ENRICHED
      PRIMARY KEY (customer_id)
      WITH SYNONYMS = (
        'customer 360',
        'customer profile',
        'customer record',
        'policyholder',
        'insured'
      )
      COMMENT = 'Unified customer profile with policy, claims, payments, interactions, AI sentiment, risk signals, and NBA recommendation. One row per customer.'
  )

  -- ═══════════════════════════════════════════════════════════════════════════
  -- FACTS: raw values used to compute metrics
  -- ═══════════════════════════════════════════════════════════════════════════
  FACTS (
    -- Policy facts
    customer.total_annual_premium
      AS total_annual_premium
      COMMENT = 'Total annual premium across all policies in USD',

    customer.active_annual_premium
      AS active_annual_premium
      COMMENT = 'Annual premium for currently active policies only in USD',

    -- Claims facts
    customer.total_reserve_amount
      AS total_reserve_amount
      COMMENT = 'Total reserve amount across all claims in USD',

    customer.claims_total_paid
      AS claims_total_paid
      COMMENT = 'Total amount paid out across all settled claims in USD',

    -- Sentiment facts
    customer.avg_sentiment_90d
      AS avg_sentiment_90d
      COMMENT = 'Average AI-derived sentiment score over last 90 days. Range: -1.0 (very negative) to +1.0 (very positive).',

    customer.worst_sentiment_90d
      AS worst_sentiment_90d
      COMMENT = 'Lowest (most negative) AI-derived sentiment score in last 90 days',

    customer.avg_sentiment_prior_90d
      AS avg_sentiment_prior_90d
      COMMENT = 'Average AI-derived sentiment score from 91-180 days ago, for trend comparison',

    customer.enrichment_coverage_pct
      AS enrichment_coverage_pct
      COMMENT = 'Percentage of transcripts with completed AI enrichment. 1.0 = all transcripts enriched.',

    -- Risk facts
    customer.composite_risk_score
      AS composite_risk_score
      COMMENT = 'Weighted composite risk score from 0.0 (no risk) to 1.0 (maximum risk). Computed from 7 weighted signals.',

    -- NBA facts
    customer.nba_final_score
      AS nba_final_score
      COMMENT = 'Next Best Action recommendation score. Product of relevance and safety. Higher is stronger recommendation.',

    customer.nba_confidence_score
      AS nba_confidence_score
      COMMENT = 'Numeric confidence in the NBA recommendation from 0.0 to 1.0. Based on enrichment coverage and signal completeness.'
  )

  -- ═══════════════════════════════════════════════════════════════════════════
  -- DIMENSIONS: attributes for filtering and grouping
  -- ═══════════════════════════════════════════════════════════════════════════
  DIMENSIONS (
    -- Identity
    customer.customer_id
      AS customer_id
      WITH SYNONYMS = ('customer number', 'customer identifier', 'cust id')
      COMMENT = 'Unique customer identifier assigned by the carrier',

    customer.customer_name
      AS first_name || ' ' || last_name
      WITH SYNONYMS = ('customer name', 'name', 'policyholder name', 'full name')
      COMMENT = 'Full name of the customer (first + last)',

    customer.first_name
      AS first_name
      COMMENT = 'Customer first name',

    customer.last_name
      AS last_name
      COMMENT = 'Customer last name',

    customer.customer_since
      AS customer_since
      WITH SYNONYMS = ('relationship start date', 'tenure start', 'member since')
      COMMENT = 'Date when the customer relationship began',

    customer.customer_status
      LABELS = (FILTER)
      AS customer_status
      WITH SYNONYMS = ('status', 'account status')
      COMMENT = 'Current customer lifecycle status: active, inactive, or prospect'
      SAMPLE_VALUES ('active', 'inactive', 'prospect')
      IS_ENUM,

    customer.state
      LABELS = (FILTER)
      AS state
      WITH SYNONYMS = ('customer state', 'location', 'us state')
      COMMENT = 'US state code of customer address',

    customer.city
      LABELS = (FILTER)
      AS city
      COMMENT = 'City of customer address',

    customer.household_id
      AS household_id
      WITH SYNONYMS = ('household', 'household number')
      COMMENT = 'Household grouping identifier — customers at the same address',

    -- Policy dimensions
    customer.active_policies
      AS active_policies
      WITH SYNONYMS = ('policy count', 'number of policies', 'active policy count')
      COMMENT = 'Number of currently active insurance policies',

    customer.total_policies
      AS total_policies
      COMMENT = 'Total number of policies including lapsed, cancelled, and renewed',

    customer.distinct_product_count
      AS distinct_product_count
      WITH SYNONYMS = ('product count', 'number of products')
      COMMENT = 'Number of distinct product types held (auto, home, umbrella, renters)',

    customer.product_holdings
      AS product_holdings
      WITH SYNONYMS = ('products', 'product types', 'lines of business', 'policy types')
      COMMENT = 'Comma-separated list of product types the customer holds',

    customer.nearest_renewal_date
      AS nearest_renewal_date
      WITH SYNONYMS = ('renewal date', 'next renewal', 'expiration date')
      COMMENT = 'Earliest upcoming policy renewal or expiration date',

    customer.days_to_renewal
      AS days_to_renewal
      WITH SYNONYMS = ('days until renewal', 'days to expiration', 'renewal proximity')
      COMMENT = 'Number of days until the nearest policy renewal. Lower = more urgent.',

    -- Claims dimensions
    customer.total_claims
      AS total_claims
      WITH SYNONYMS = ('claim count', 'number of claims')
      COMMENT = 'Total number of claims ever filed by this customer',

    customer.open_claims
      AS open_claims
      WITH SYNONYMS = ('open claim count', 'pending claims', 'active claims')
      COMMENT = 'Number of claims currently open (filed or under review)',

    customer.settled_claims
      AS settled_claims
      COMMENT = 'Number of claims that have been settled',

    customer.denied_claims
      AS denied_claims
      COMMENT = 'Number of claims that were denied',

    -- Payment dimensions
    customer.total_payments
      AS total_payments
      COMMENT = 'Total number of payment obligations (billing cycles)',

    customer.payments_on_time
      AS payments_on_time
      WITH SYNONYMS = ('on time payments', 'timely payments')
      COMMENT = 'Number of payments made on time',

    customer.payments_late
      AS payments_late
      WITH SYNONYMS = ('late payments', 'overdue payments')
      COMMENT = 'Number of payments made after the due date',

    customer.payments_missed
      AS payments_missed
      WITH SYNONYMS = ('missed payments', 'unpaid payments')
      COMMENT = 'Number of payments not made at all',

    customer.latest_paid_date
      AS latest_paid_date
      WITH SYNONYMS = ('last payment date', 'most recent payment')
      COMMENT = 'Date of the most recent payment received',

    -- Interaction dimensions
    customer.total_interactions
      AS total_interactions
      WITH SYNONYMS = ('interaction count', 'contact count', 'number of interactions')
      COMMENT = 'Total number of customer contact events (calls, emails, chats)',

    customer.interactions_inbound
      AS interactions_inbound
      WITH SYNONYMS = ('inbound calls', 'inbound interactions')
      COMMENT = 'Number of customer-initiated interactions',

    customer.interactions_complaints
      AS interactions_complaints
      WITH SYNONYMS = ('complaint count', 'number of complaints')
      COMMENT = 'Number of interactions with complaint disposition',

    customer.latest_interaction_date
      AS latest_interaction_date
      WITH SYNONYMS = ('last contact', 'last interaction', 'most recent interaction')
      COMMENT = 'Timestamp of the most recent customer interaction',

    customer.latest_channel
      LABELS = (FILTER)
      AS latest_channel
      WITH SYNONYMS = ('last channel', 'contact channel')
      COMMENT = 'Channel of the most recent interaction'
      SAMPLE_VALUES ('phone', 'email', 'chat')
      IS_ENUM,

    -- AI sentiment dimensions
    customer.negative_count_90d
      AS negative_count_90d
      WITH SYNONYMS = ('negative interactions', 'negative sentiment count', 'unhappy interactions')
      COMMENT = 'Number of interactions with AI-derived negative sentiment in the last 90 days',

    customer.positive_count_90d
      AS positive_count_90d
      WITH SYNONYMS = ('positive interactions', 'positive sentiment count', 'happy interactions')
      COMMENT = 'Number of interactions with AI-derived positive sentiment in the last 90 days',

    customer.enriched_interactions_90d
      AS enriched_interactions_90d
      COMMENT = 'Number of interactions with completed AI enrichment in the last 90 days',

    customer.sentiment_direction
      LABELS = (FILTER)
      AS sentiment_direction
      WITH SYNONYMS = ('sentiment trend', 'sentiment change', 'mood trend')
      COMMENT = 'Direction of sentiment change: worsening, stable, improving, or insufficient_data'
      SAMPLE_VALUES ('worsening', 'stable', 'improving', 'insufficient_data')
      IS_ENUM,

    -- Risk dimensions
    customer.risk_tier
      LABELS = (FILTER)
      AS risk_tier
      WITH SYNONYMS = ('risk level', 'risk category', 'risk rating', 'churn risk')
      COMMENT = 'Overall risk classification: critical, high, medium, or low. Based on weighted composite of 7 risk signals.'
      SAMPLE_VALUES ('critical', 'high', 'medium', 'low')
      IS_ENUM,

    customer.risk_direction
      LABELS = (FILTER)
      AS risk_direction
      WITH SYNONYMS = ('risk trend', 'risk change')
      COMMENT = 'Direction of overall risk: worsening, stable, or improving'
      SAMPLE_VALUES ('worsening', 'stable', 'improving')
      IS_ENUM,

    customer.worsening_signals
      AS worsening_signals
      COMMENT = 'Number of risk signals with worsening direction',

    customer.improving_signals
      AS improving_signals
      COMMENT = 'Number of risk signals with improving direction',

    -- NBA dimensions
    customer.nba_action_type
      LABELS = (FILTER)
      AS nba_action_type
      WITH SYNONYMS = ('recommended action', 'next best action', 'NBA', 'action type', 'recommendation')
      COMMENT = 'Type of the primary recommended action for this customer'
      SAMPLE_VALUES ('retention_outreach', 'renewal_reminder', 'complaint_followup', 'claim_escalation', 'billing_assistance', 'cross_sell_home', 'cross_sell_umbrella', 'no_action')
      IS_ENUM,

    customer.nba_action_name
      AS nba_action_name
      WITH SYNONYMS = ('action name', 'recommendation name')
      COMMENT = 'Human-readable name of the recommended action',

    customer.nba_action_category
      LABELS = (FILTER)
      AS nba_action_category
      WITH SYNONYMS = ('action category')
      COMMENT = 'Category of the recommended action: retention, service, sales, or administrative'
      SAMPLE_VALUES ('retention', 'service', 'sales', 'administrative')
      IS_ENUM,

    customer.nba_confidence_level
      LABELS = (FILTER)
      AS nba_confidence_level
      WITH SYNONYMS = ('confidence', 'recommendation confidence')
      COMMENT = 'Confidence in the NBA recommendation: high, medium_high, medium, or low'
      SAMPLE_VALUES ('high', 'medium_high', 'medium', 'low')
      IS_ENUM,

    -- System status dimensions
    customer.system_status
      LABELS = (FILTER)
      AS system_status
      WITH SYNONYMS = ('data status', 'system health')
      COMMENT = 'Operational status: full (all data available), degraded_no_enrichment, degraded_no_recommendation, or low_confidence'
      SAMPLE_VALUES ('full', 'degraded_no_enrichment', 'degraded_no_recommendation', 'low_confidence')
      IS_ENUM,

    -- Data completeness flags
    customer.has_enrichment
      LABELS = (FILTER)
      AS has_enrichment
      COMMENT = 'TRUE if customer has at least one AI-enriched interaction in the last 90 days',

    customer.has_recommendation
      LABELS = (FILTER)
      AS has_recommendation
      COMMENT = 'TRUE if the system generated a Next Best Action recommendation for this customer',

    customer.has_policies
      LABELS = (FILTER)
      AS has_policies
      COMMENT = 'TRUE if the customer has at least one policy record',

    customer.has_claims
      LABELS = (FILTER)
      AS has_claims
      COMMENT = 'TRUE if the customer has at least one claim record',

    customer.has_interactions
      LABELS = (FILTER)
      AS has_interactions
      COMMENT = 'TRUE if the customer has at least one interaction record'
  )

  -- ═══════════════════════════════════════════════════════════════════════════
  -- METRICS: aggregations and computed measures
  -- ═══════════════════════════════════════════════════════════════════════════
  METRICS (
    -- Customer counts
    customer.customer_count
      AS COUNT(customer_id)
      WITH SYNONYMS = ('number of customers', 'how many customers', 'customer total')
      COMMENT = 'Count of customers',

    -- Policy metrics
    customer.avg_active_policies
      AS AVG(active_policies)
      COMMENT = 'Average number of active policies per customer',

    customer.total_premium_sum
      AS SUM(total_annual_premium)
      WITH SYNONYMS = ('total premium', 'premium total', 'book of business')
      COMMENT = 'Sum of annual premiums across all customers',

    customer.avg_premium
      AS AVG(total_annual_premium)
      WITH SYNONYMS = ('average premium')
      COMMENT = 'Average annual premium per customer',

    -- Claims metrics
    customer.total_open_claims
      AS SUM(open_claims)
      WITH SYNONYMS = ('open claims total')
      COMMENT = 'Total number of open claims across all customers',

    customer.total_claims_paid_sum
      AS SUM(claims_total_paid)
      WITH SYNONYMS = ('total claims paid', 'claims payout')
      COMMENT = 'Total amount paid out in claims across all customers',

    -- Payment metrics
    customer.total_late_payments
      AS SUM(payments_late)
      COMMENT = 'Total number of late payments across all customers',

    customer.total_missed_payments
      AS SUM(payments_missed)
      COMMENT = 'Total number of missed payments across all customers',

    customer.avg_payment_risk_ratio
      AS AVG(CASE WHEN total_payments > 0 THEN (payments_late + payments_missed)::FLOAT / total_payments ELSE 0 END)
      COMMENT = 'Average ratio of late+missed payments to total payments',

    -- Sentiment metrics
    customer.avg_sentiment
      AS AVG(avg_sentiment_90d)
      WITH SYNONYMS = ('average sentiment', 'mean sentiment')
      COMMENT = 'Average of the 90-day sentiment scores across customers',

    customer.total_negative_interactions
      AS SUM(negative_count_90d)
      WITH SYNONYMS = ('negative interaction total')
      COMMENT = 'Total count of negative-sentiment interactions in last 90 days across all customers',

    -- Risk metrics
    customer.avg_risk_score
      AS AVG(composite_risk_score)
      WITH SYNONYMS = ('average risk', 'mean risk score')
      COMMENT = 'Average composite risk score across customers',

    customer.high_risk_customer_count
      AS COUNT(CASE WHEN risk_tier IN ('critical', 'high') THEN customer_id END)
      WITH SYNONYMS = ('high risk customers', 'at-risk customers', 'customers at risk')
      COMMENT = 'Number of customers with critical or high risk tier',

    -- NBA metrics
    customer.customers_with_recommendation
      AS COUNT(CASE WHEN nba_action_type IS NOT NULL THEN customer_id END)
      WITH SYNONYMS = ('customers with NBA', 'recommended customers')
      COMMENT = 'Number of customers that have a Next Best Action recommendation',

    customer.avg_nba_confidence
      AS AVG(nba_confidence_score)
      COMMENT = 'Average NBA confidence score across customers with recommendations',

    -- Renewal metrics
    customer.customers_renewing_30d
      AS COUNT(CASE WHEN days_to_renewal <= 30 AND days_to_renewal > 0 THEN customer_id END)
      WITH SYNONYMS = ('renewals in 30 days', 'upcoming renewals', 'customers renewing soon')
      COMMENT = 'Number of customers with a policy renewal within the next 30 days',

    customer.customers_renewing_14d
      AS COUNT(CASE WHEN days_to_renewal <= 14 AND days_to_renewal > 0 THEN customer_id END)
      WITH SYNONYMS = ('urgent renewals', 'renewals in 2 weeks')
      COMMENT = 'Number of customers with a policy renewal within the next 14 days — urgent'
  )

  COMMENT = 'Customer 360 semantic view for insurance Next Best Action. Covers identity, policies, claims, payments, interactions, AI-derived sentiment, risk signals, and explainable recommendations. One row per customer.'

  AI_SQL_GENERATION 'This semantic view contains one row per customer. All measures are pre-aggregated per customer. When the user asks about a specific customer, filter by customer_name or customer_id. When the user asks about risk, use risk_tier or composite_risk_score. When the user asks about sentiment, use sentiment_direction or avg_sentiment_90d. When the user asks about recommendations or actions, use nba_action_type or nba_action_name. Days_to_renewal is the number of days until the next policy renewal — lower means more urgent. Negative_count_90d is the count of negative-sentiment interactions in the last 90 days.'

  AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about insurance customers, their policies, claims, payments, interaction sentiment, risk levels, and recommended actions. It does NOT answer questions about individual claim details, specific payment transactions, or individual interaction transcripts. Route questions about specific interaction content to the INTERACTIONS_ENRICHED table instead.'

  -- ═══════════════════════════════════════════════════════════════════════════
  -- VERIFIED QUERIES: golden demo questions with known-correct SQL
  -- ═══════════════════════════════════════════════════════════════════════════
  AI_VERIFIED_QUERIES (

    -- ─────────────────────────────────────────────────────────────────────
    -- VQ 4: Which customers renew within 30 days?
    -- Returns the full renewal watch-list sorted by urgency.
    -- ─────────────────────────────────────────────────────────────────────
    vq_renewals_30d AS (
      QUESTION 'Which customers renew within 30 days?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT customer_name, customer_id, days_to_renewal, nearest_renewal_date, active_policies, product_holdings, risk_tier, nba_action_name FROM SEMANTIC_VIEW(SV_CUSTOMER_360) WHERE days_to_renewal <= 30 AND days_to_renewal > 0 ORDER BY days_to_renewal ASC'
    ),

    vq_negative_sentiment AS (
      QUESTION 'Which customers have negative sentiment trend?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT customer_name, customer_id, avg_sentiment_90d, sentiment_direction, negative_count_90d FROM SEMANTIC_VIEW(SV_CUSTOMER_360) WHERE sentiment_direction = ''worsening'' ORDER BY avg_sentiment_90d ASC'
    ),

    vq_negative_and_renewal AS (
      QUESTION 'Which customers have both negative sentiment and an approaching renewal?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT customer_name, customer_id, negative_count_90d, days_to_renewal, risk_tier, nba_action_name FROM SEMANTIC_VIEW(SV_CUSTOMER_360) WHERE negative_count_90d > 0 AND days_to_renewal <= 30 AND days_to_renewal > 0 ORDER BY composite_risk_score DESC'
    ),

    vq_risk_distribution AS (
      QUESTION 'What is the risk distribution across customers?'
      SQL 'SELECT risk_tier, customer_count FROM SEMANTIC_VIEW(SV_CUSTOMER_360) GROUP BY risk_tier ORDER BY CASE risk_tier WHEN ''critical'' THEN 1 WHEN ''high'' THEN 2 WHEN ''medium'' THEN 3 ELSE 4 END'
    ),

    -- ─────────────────────────────────────────────────────────────────────
    -- VQ 5: Which customers have critical risk?
    -- Returns the critical-risk cohort with all contributing indicators
    -- so a manager can see WHY each customer is critical at a glance.
    -- ─────────────────────────────────────────────────────────────────────
    vq_critical_risk AS (
      QUESTION 'Which customers have critical risk?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT customer_name, customer_id, composite_risk_score, risk_tier, risk_direction, days_to_renewal, negative_count_90d, avg_sentiment_90d, sentiment_direction, payments_late, payments_missed, open_claims, interactions_complaints, nba_action_name, nba_confidence_level FROM SEMANTIC_VIEW(SV_CUSTOMER_360) WHERE risk_tier = ''critical'' ORDER BY composite_risk_score DESC'
    ),

    vq_nba_by_risk AS (
      QUESTION 'What actions are recommended for high-risk customers?'
      SQL 'SELECT nba_action_type, customer_count FROM SEMANTIC_VIEW(SV_CUSTOMER_360) WHERE risk_tier IN (''critical'', ''high'') GROUP BY nba_action_type ORDER BY customer_count DESC'
    ),

    vq_maria_chen AS (
      QUESTION 'Show Maria Chen profile'
      SQL 'SELECT customer_name, customer_id, active_policies, product_holdings, days_to_renewal, negative_count_90d, avg_sentiment_90d, risk_tier, composite_risk_score, nba_action_name, nba_confidence_level FROM SEMANTIC_VIEW(SV_CUSTOMER_360) WHERE customer_id = ''CUST-001'''
    ),

    vq_complaint_customers AS (
      QUESTION 'How many customers have recent complaints?'
      SQL 'SELECT customer_count FROM SEMANTIC_VIEW(SV_CUSTOMER_360) WHERE negative_count_90d > 0'
    ),

    vq_nba_distribution AS (
      QUESTION 'What is the distribution of recommended actions?'
      SQL 'SELECT nba_action_type, customer_count FROM SEMANTIC_VIEW(SV_CUSTOMER_360) GROUP BY nba_action_type ORDER BY customer_count DESC'
    ),

    vq_high_confidence_actions AS (
      QUESTION 'Which customers have high confidence recommendations?'
      SQL 'SELECT customer_name, customer_id, nba_action_name, nba_confidence_level, risk_tier FROM SEMANTIC_VIEW(SV_CUSTOMER_360) WHERE nba_confidence_level = ''high'' ORDER BY nba_final_score DESC'
    ),

    vq_premium_by_risk AS (
      QUESTION 'What is the total premium at risk for critical and high risk customers?'
      SQL 'SELECT risk_tier, customer_count, total_premium_sum FROM SEMANTIC_VIEW(SV_CUSTOMER_360) WHERE risk_tier IN (''critical'', ''high'') GROUP BY risk_tier'
    ),

    vq_system_status AS (
      QUESTION 'What is the system health status?'
      SQL 'SELECT system_status, customer_count FROM SEMANTIC_VIEW(SV_CUSTOMER_360) GROUP BY system_status ORDER BY customer_count DESC'
    ),

    -- ─────────────────────────────────────────────────────────────────────
    -- VQ 1: Why is this customer at risk?
    -- Surfaces every contributing signal dimension for a named customer.
    -- Columns are ordered from highest-weight signal to lowest so the
    -- answer reads as a natural explanation: renewal first, sentiment
    -- second, payments third, complaints fourth, etc.
    -- ─────────────────────────────────────────────────────────────────────
    vq_why_at_risk AS (
      QUESTION 'Why is this customer at risk?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT customer_name, risk_tier, composite_risk_score, risk_direction, days_to_renewal, nearest_renewal_date, negative_count_90d, avg_sentiment_90d, worst_sentiment_90d, sentiment_direction, payments_late, payments_missed, total_payments, interactions_complaints, open_claims, total_claims, worsening_signals, improving_signals, enrichment_coverage_pct, system_status FROM SEMANTIC_VIEW(SV_CUSTOMER_360) WHERE customer_id = ''CUST-001'''
    ),

    -- ─────────────────────────────────────────────────────────────────────
    -- VQ 2: What recommendation was generated?
    -- Returns the full NBA recommendation context: action details,
    -- scoring breakdown, confidence, and the risk profile that triggered it.
    -- ─────────────────────────────────────────────────────────────────────
    vq_what_recommendation AS (
      QUESTION 'What recommendation was generated for this customer?'
      SQL 'SELECT customer_name, customer_id, nba_action_name, nba_action_type, nba_action_category, nba_final_score, nba_confidence_level, nba_confidence_score, risk_tier, composite_risk_score, risk_direction, system_status FROM SEMANTIC_VIEW(SV_CUSTOMER_360) WHERE customer_id = ''CUST-001'''
    ),

    -- ─────────────────────────────────────────────────────────────────────
    -- VQ 3: What evidence supports the recommendation?
    -- Returns every signal dimension that feeds into the NBA engine,
    -- giving the rep a complete evidence trail they can verify.
    -- Columns are grouped: sentiment evidence → renewal evidence →
    -- payment evidence → complaint evidence → claim evidence.
    -- ─────────────────────────────────────────────────────────────────────
    vq_evidence_for_recommendation AS (
      QUESTION 'What evidence supports the recommendation?'
      SQL 'SELECT customer_name, nba_action_name, nba_confidence_level, negative_count_90d, avg_sentiment_90d, worst_sentiment_90d, sentiment_direction, enriched_interactions_90d, days_to_renewal, nearest_renewal_date, active_policies, product_holdings, payments_late, payments_missed, total_payments, interactions_complaints, open_claims, enrichment_coverage_pct, has_enrichment, system_status FROM SEMANTIC_VIEW(SV_CUSTOMER_360) WHERE customer_id = ''CUST-001'''
    )
  );


-- =============================================================================
-- Verification: describe the semantic view
-- =============================================================================
DESCRIBE SEMANTIC VIEW SV_CUSTOMER_360;
