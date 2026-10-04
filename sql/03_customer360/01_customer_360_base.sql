/*==============================================================================
  CUSTOMER360 — CUSTOMER 360 BASE VIEW
  Schema: CUSTOMER360_DB.ANALYTICS
  Pattern: CREATE OR REPLACE VIEW for idempotent reruns
  Dependencies:
    - ANALYTICS.DIM_CUSTOMER
    - ANALYTICS.DIM_HOUSEHOLD
    - ANALYTICS.AGG_CUSTOMER_POLICY
    - ANALYTICS.AGG_CUSTOMER_CLAIM
    - ANALYTICS.AGG_CUSTOMER_PAYMENT
    - ANALYTICS.AGG_CUSTOMER_INTERACTION

  Grain: Exactly one row per customer_id.
  All joins are LEFT to preserve customers lacking related records.
  Each aggregate already has PK = customer_id (one row per customer),
  so no fan-out is possible.

  Does NOT include: transcript text, sentiment, risk scores, or NBA fields.
==============================================================================*/

USE ROLE C360_DATA_ENGINEER;
USE SCHEMA CUSTOMER360_DB.ANALYTICS;

CREATE OR REPLACE VIEW CUSTOMER360_DB.ANALYTICS.CUSTOMER_360_BASE
COMMENT = 'Customer 360 base: one row per customer with identity, household, policy, claim, payment, and interaction summaries. No AI-derived fields.'
AS
SELECT
    -- =========================================================================
    -- IDENTITY
    -- =========================================================================
    c.customer_sk,
    c.customer_id,
    c.first_name,
    c.last_name,
    c.date_of_birth,
    c.email,
    c.phone,
    c.address_line_1,
    c.city,
    c.state,
    c.postal_code,
    c.customer_since,
    c.status                                    AS customer_status,

    -- =========================================================================
    -- HOUSEHOLD CONTEXT
    -- =========================================================================
    h.household_sk,
    c.household_id,
    h.member_count                              AS household_member_count,
    h.primary_state                             AS household_primary_state,
    h.household_status,
    h.earliest_since                            AS household_earliest_since,

    -- =========================================================================
    -- POLICY SUMMARY
    -- =========================================================================
    COALESCE(ap.total_policies, 0)              AS total_policies,
    COALESCE(ap.active_policies, 0)             AS active_policies,
    COALESCE(ap.distinct_product_count, 0)      AS distinct_product_count,
    ap.product_holdings,
    ap.nearest_renewal_date,
    DATEDIFF('day', CURRENT_DATE(), ap.nearest_renewal_date) AS days_to_renewal,
    COALESCE(ap.total_annual_premium, 0)        AS total_annual_premium,
    COALESCE(ap.active_annual_premium, 0)       AS active_annual_premium,
    ap.total_coverage_limit,
    ap.total_deductible,

    -- =========================================================================
    -- CLAIM SUMMARY
    -- =========================================================================
    COALESCE(ac.total_claims, 0)                AS total_claims,
    COALESCE(ac.open_claims, 0)                 AS open_claims,
    COALESCE(ac.settled_claims, 0)              AS settled_claims,
    COALESCE(ac.denied_claims, 0)               AS denied_claims,
    ac.total_reserve_amount,
    ac.total_paid_amount                        AS claims_total_paid,
    ac.earliest_filed_date,
    ac.latest_filed_date,

    -- =========================================================================
    -- PAYMENT BEHAVIOUR
    -- =========================================================================
    COALESCE(py.total_payments, 0)              AS total_payments,
    COALESCE(py.on_time_count, 0)              AS payments_on_time,
    COALESCE(py.late_count, 0)                 AS payments_late,
    COALESCE(py.missed_count, 0)               AS payments_missed,
    COALESCE(py.grace_period_count, 0)         AS payments_grace_period,
    COALESCE(py.pending_count, 0)              AS payments_pending,
    py.latest_paid_date,
    COALESCE(py.total_amount_due, 0)           AS total_amount_due,
    py.total_amount_paid                        AS payments_total_paid,

    -- =========================================================================
    -- INTERACTION SUMMARY
    -- =========================================================================
    COALESCE(ai.total_interactions, 0)          AS total_interactions,
    COALESCE(ai.inbound_count, 0)              AS interactions_inbound,
    COALESCE(ai.outbound_count, 0)             AS interactions_outbound,
    ai.latest_interaction_date,
    ai.latest_channel,
    COALESCE(ai.complaint_count, 0)            AS interactions_complaints,
    COALESCE(ai.inquiry_count, 0)              AS interactions_inquiries,
    COALESCE(ai.request_count, 0)              AS interactions_requests,

    -- =========================================================================
    -- DATA-COMPLETENESS FLAGS
    -- =========================================================================
    CASE WHEN c.email IS NOT NULL THEN TRUE ELSE FALSE END          AS has_email,
    CASE WHEN c.phone IS NOT NULL THEN TRUE ELSE FALSE END          AS has_phone,
    CASE WHEN c.date_of_birth IS NOT NULL THEN TRUE ELSE FALSE END  AS has_dob,
    CASE WHEN ap.customer_id IS NOT NULL THEN TRUE ELSE FALSE END   AS has_policies,
    CASE WHEN ac.customer_id IS NOT NULL THEN TRUE ELSE FALSE END   AS has_claims,
    CASE WHEN py.customer_id IS NOT NULL THEN TRUE ELSE FALSE END   AS has_payments,
    CASE WHEN ai.customer_id IS NOT NULL THEN TRUE ELSE FALSE END   AS has_interactions,

    -- =========================================================================
    -- LINEAGE & REFRESH METADATA
    -- =========================================================================
    c._source_table                             AS customer_source_table,
    c._source_hash                              AS customer_source_hash,
    c._batch_id                                 AS customer_batch_id,
    c._loaded_at                                AS customer_loaded_at,
    c._processed_at                             AS customer_processed_at,
    CURRENT_TIMESTAMP()                         AS view_refreshed_at

FROM CUSTOMER360_DB.ANALYTICS.DIM_CUSTOMER c

LEFT JOIN CUSTOMER360_DB.ANALYTICS.DIM_HOUSEHOLD h
    ON c.household_id = h.household_id

LEFT JOIN CUSTOMER360_DB.ANALYTICS.AGG_CUSTOMER_POLICY ap
    ON c.customer_id = ap.customer_id

LEFT JOIN CUSTOMER360_DB.ANALYTICS.AGG_CUSTOMER_CLAIM ac
    ON c.customer_id = ac.customer_id

LEFT JOIN CUSTOMER360_DB.ANALYTICS.AGG_CUSTOMER_PAYMENT py
    ON c.customer_id = py.customer_id

LEFT JOIN CUSTOMER360_DB.ANALYTICS.AGG_CUSTOMER_INTERACTION ai
    ON c.customer_id = ai.customer_id;
