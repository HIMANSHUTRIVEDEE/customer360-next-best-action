/*==============================================================================
  CUSTOMER360 — CURATED LAYER: CUSTOMER AGGREGATES
  Schema: CUSTOMER360_DB.ANALYTICS
  Pattern: Type 1, MERGE for rerun safety
  Dependencies: Fact and dimension tables in CUSTOMER360_DB.ANALYTICS

  Each aggregate produces exactly one row per applicable customer, computed
  independently per domain to prevent cross-domain join fan-out.
  Customers without activity in a domain will not appear in that aggregate;
  downstream consumers should LEFT JOIN from DIM_CUSTOMER to preserve all
  customers.
==============================================================================*/

USE ROLE C360_DATA_ENGINEER;
USE SCHEMA CUSTOMER360_DB.ANALYTICS;

/*------------------------------------------------------------------------------
  AGG_CUSTOMER_POLICY
  Grain: One row per customer_id that has at least one policy.
  Metrics: active policy count, distinct product holdings, nearest renewal
           date, total premium, total coverage limit, total deductible.
------------------------------------------------------------------------------*/
CREATE TABLE IF NOT EXISTS CUSTOMER360_DB.ANALYTICS.AGG_CUSTOMER_POLICY (
    customer_id              VARCHAR(20)    NOT NULL,
    total_policies           NUMBER(10,0)   NOT NULL,
    active_policies          NUMBER(10,0)   NOT NULL,
    distinct_product_count   NUMBER(10,0)   NOT NULL,
    product_holdings         VARCHAR(500),              -- Comma-separated product types held
    nearest_renewal_date     DATE,                      -- Earliest expiration among active policies
    total_annual_premium     NUMBER(14,2)   NOT NULL,
    active_annual_premium    NUMBER(14,2)   NOT NULL,
    total_coverage_limit     NUMBER(14,2),
    total_deductible         NUMBER(14,2),
    _source_table            VARCHAR(100)   DEFAULT 'ANALYTICS.DIM_POLICY,ANALYTICS.DIM_COVERAGE',
    _processed_at            TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_agg_customer_policy PRIMARY KEY (customer_id)
);

MERGE INTO CUSTOMER360_DB.ANALYTICS.AGG_CUSTOMER_POLICY AS tgt
USING (
    WITH policy_agg AS (
        SELECT
            p.customer_id,
            COUNT(*)                                                        AS total_policies,
            SUM(CASE WHEN p.status = 'active' THEN 1 ELSE 0 END)           AS active_policies,
            COUNT(DISTINCT p.product_type)                                  AS distinct_product_count,
            LISTAGG(DISTINCT p.product_type, ', ') WITHIN GROUP (ORDER BY p.product_type) AS product_holdings,
            MIN(CASE WHEN p.status = 'active' THEN p.expiration_date END)   AS nearest_renewal_date,
            SUM(p.premium_amount)                                           AS total_annual_premium,
            SUM(CASE WHEN p.status = 'active' THEN p.premium_amount ELSE 0 END) AS active_annual_premium
        FROM CUSTOMER360_DB.ANALYTICS.DIM_POLICY p
        GROUP BY p.customer_id
    ),
    coverage_agg AS (
        SELECT
            p.customer_id,
            SUM(c.limit_amount)      AS total_coverage_limit,
            SUM(c.deductible_amount) AS total_deductible
        FROM CUSTOMER360_DB.ANALYTICS.DIM_COVERAGE c
        JOIN CUSTOMER360_DB.ANALYTICS.DIM_POLICY p
            ON c.policy_id = p.policy_id
        GROUP BY p.customer_id
    )
    SELECT
        pa.customer_id,
        pa.total_policies,
        pa.active_policies,
        pa.distinct_product_count,
        pa.product_holdings,
        pa.nearest_renewal_date,
        pa.total_annual_premium,
        pa.active_annual_premium,
        ca.total_coverage_limit,
        ca.total_deductible
    FROM policy_agg pa
    LEFT JOIN coverage_agg ca ON pa.customer_id = ca.customer_id
) AS src
ON tgt.customer_id = src.customer_id
WHEN MATCHED THEN UPDATE SET
    tgt.total_policies         = src.total_policies,
    tgt.active_policies        = src.active_policies,
    tgt.distinct_product_count = src.distinct_product_count,
    tgt.product_holdings       = src.product_holdings,
    tgt.nearest_renewal_date   = src.nearest_renewal_date,
    tgt.total_annual_premium   = src.total_annual_premium,
    tgt.active_annual_premium  = src.active_annual_premium,
    tgt.total_coverage_limit   = src.total_coverage_limit,
    tgt.total_deductible       = src.total_deductible,
    tgt._processed_at          = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    customer_id, total_policies, active_policies, distinct_product_count,
    product_holdings, nearest_renewal_date, total_annual_premium,
    active_annual_premium, total_coverage_limit, total_deductible,
    _source_table, _processed_at
) VALUES (
    src.customer_id, src.total_policies, src.active_policies, src.distinct_product_count,
    src.product_holdings, src.nearest_renewal_date, src.total_annual_premium,
    src.active_annual_premium, src.total_coverage_limit, src.total_deductible,
    'ANALYTICS.DIM_POLICY,ANALYTICS.DIM_COVERAGE', CURRENT_TIMESTAMP()
);

/*------------------------------------------------------------------------------
  AGG_CUSTOMER_CLAIM
  Grain: One row per customer_id that has at least one claim.
  Metrics: total claims, open claims, settled claims, denied claims,
           total reserve, total paid.
------------------------------------------------------------------------------*/
CREATE TABLE IF NOT EXISTS CUSTOMER360_DB.ANALYTICS.AGG_CUSTOMER_CLAIM (
    customer_id              VARCHAR(20)    NOT NULL,
    total_claims             NUMBER(10,0)   NOT NULL,
    open_claims              NUMBER(10,0)   NOT NULL,
    settled_claims           NUMBER(10,0)   NOT NULL,
    denied_claims            NUMBER(10,0)   NOT NULL,
    total_reserve_amount     NUMBER(14,2),
    total_paid_amount        NUMBER(14,2),
    earliest_filed_date      DATE,
    latest_filed_date        DATE,
    _source_table            VARCHAR(100)   DEFAULT 'ANALYTICS.FACT_CLAIM',
    _processed_at            TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_agg_customer_claim PRIMARY KEY (customer_id)
);

MERGE INTO CUSTOMER360_DB.ANALYTICS.AGG_CUSTOMER_CLAIM AS tgt
USING (
    SELECT
        customer_id,
        COUNT(*)                                                             AS total_claims,
        SUM(CASE WHEN status IN ('filed', 'under_review') THEN 1 ELSE 0 END) AS open_claims,
        SUM(CASE WHEN status = 'settled' THEN 1 ELSE 0 END)                 AS settled_claims,
        SUM(CASE WHEN status = 'denied' THEN 1 ELSE 0 END)                  AS denied_claims,
        SUM(reserve_amount)                                                  AS total_reserve_amount,
        SUM(paid_amount)                                                     AS total_paid_amount,
        MIN(filed_date)                                                      AS earliest_filed_date,
        MAX(filed_date)                                                      AS latest_filed_date
    FROM CUSTOMER360_DB.ANALYTICS.FACT_CLAIM
    GROUP BY customer_id
) AS src
ON tgt.customer_id = src.customer_id
WHEN MATCHED THEN UPDATE SET
    tgt.total_claims         = src.total_claims,
    tgt.open_claims          = src.open_claims,
    tgt.settled_claims       = src.settled_claims,
    tgt.denied_claims        = src.denied_claims,
    tgt.total_reserve_amount = src.total_reserve_amount,
    tgt.total_paid_amount    = src.total_paid_amount,
    tgt.earliest_filed_date  = src.earliest_filed_date,
    tgt.latest_filed_date    = src.latest_filed_date,
    tgt._processed_at        = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    customer_id, total_claims, open_claims, settled_claims, denied_claims,
    total_reserve_amount, total_paid_amount,
    earliest_filed_date, latest_filed_date,
    _source_table, _processed_at
) VALUES (
    src.customer_id, src.total_claims, src.open_claims, src.settled_claims, src.denied_claims,
    src.total_reserve_amount, src.total_paid_amount,
    src.earliest_filed_date, src.latest_filed_date,
    'ANALYTICS.FACT_CLAIM', CURRENT_TIMESTAMP()
);

/*------------------------------------------------------------------------------
  AGG_CUSTOMER_PAYMENT
  Grain: One row per customer_id that has at least one payment record.
  Metrics: total payments, latest payment date, late/missed/grace counts,
           total amount due, total amount paid.
------------------------------------------------------------------------------*/
CREATE TABLE IF NOT EXISTS CUSTOMER360_DB.ANALYTICS.AGG_CUSTOMER_PAYMENT (
    customer_id              VARCHAR(20)    NOT NULL,
    total_payments           NUMBER(10,0)   NOT NULL,
    on_time_count            NUMBER(10,0)   NOT NULL,
    late_count               NUMBER(10,0)   NOT NULL,
    missed_count             NUMBER(10,0)   NOT NULL,
    grace_period_count       NUMBER(10,0)   NOT NULL,
    pending_count            NUMBER(10,0)   NOT NULL,
    latest_paid_date         DATE,
    total_amount_due         NUMBER(14,2)   NOT NULL,
    total_amount_paid        NUMBER(14,2),
    _source_table            VARCHAR(100)   DEFAULT 'ANALYTICS.FACT_PAYMENT',
    _processed_at            TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_agg_customer_payment PRIMARY KEY (customer_id)
);

MERGE INTO CUSTOMER360_DB.ANALYTICS.AGG_CUSTOMER_PAYMENT AS tgt
USING (
    SELECT
        customer_id,
        COUNT(*)                                                         AS total_payments,
        SUM(CASE WHEN status = 'on_time' THEN 1 ELSE 0 END)             AS on_time_count,
        SUM(CASE WHEN status = 'late' THEN 1 ELSE 0 END)                AS late_count,
        SUM(CASE WHEN status = 'missed' THEN 1 ELSE 0 END)              AS missed_count,
        SUM(CASE WHEN status = 'grace_period' THEN 1 ELSE 0 END)        AS grace_period_count,
        SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END)             AS pending_count,
        MAX(paid_date)                                                   AS latest_paid_date,
        SUM(amount)                                                      AS total_amount_due,
        SUM(amount_paid)                                                 AS total_amount_paid
    FROM CUSTOMER360_DB.ANALYTICS.FACT_PAYMENT
    GROUP BY customer_id
) AS src
ON tgt.customer_id = src.customer_id
WHEN MATCHED THEN UPDATE SET
    tgt.total_payments     = src.total_payments,
    tgt.on_time_count      = src.on_time_count,
    tgt.late_count         = src.late_count,
    tgt.missed_count       = src.missed_count,
    tgt.grace_period_count = src.grace_period_count,
    tgt.pending_count      = src.pending_count,
    tgt.latest_paid_date   = src.latest_paid_date,
    tgt.total_amount_due   = src.total_amount_due,
    tgt.total_amount_paid  = src.total_amount_paid,
    tgt._processed_at      = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    customer_id, total_payments, on_time_count, late_count, missed_count,
    grace_period_count, pending_count, latest_paid_date,
    total_amount_due, total_amount_paid,
    _source_table, _processed_at
) VALUES (
    src.customer_id, src.total_payments, src.on_time_count, src.late_count, src.missed_count,
    src.grace_period_count, src.pending_count, src.latest_paid_date,
    src.total_amount_due, src.total_amount_paid,
    'ANALYTICS.FACT_PAYMENT', CURRENT_TIMESTAMP()
);

/*------------------------------------------------------------------------------
  AGG_CUSTOMER_INTERACTION
  Grain: One row per customer_id that has at least one interaction.
  Metrics: total interactions, latest interaction date, latest channel,
           counts by direction, counts by disposition.
------------------------------------------------------------------------------*/
CREATE TABLE IF NOT EXISTS CUSTOMER360_DB.ANALYTICS.AGG_CUSTOMER_INTERACTION (
    customer_id              VARCHAR(20)    NOT NULL,
    total_interactions       NUMBER(10,0)   NOT NULL,
    inbound_count            NUMBER(10,0)   NOT NULL,
    outbound_count           NUMBER(10,0)   NOT NULL,
    latest_interaction_date  TIMESTAMP_NTZ,
    latest_channel           VARCHAR(10),
    complaint_count          NUMBER(10,0)   NOT NULL,
    inquiry_count            NUMBER(10,0)   NOT NULL,
    request_count            NUMBER(10,0)   NOT NULL,
    _source_table            VARCHAR(100)   DEFAULT 'ANALYTICS.FACT_INTERACTION',
    _processed_at            TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_agg_customer_interaction PRIMARY KEY (customer_id)
);

MERGE INTO CUSTOMER360_DB.ANALYTICS.AGG_CUSTOMER_INTERACTION AS tgt
USING (
    SELECT
        customer_id,
        COUNT(*)                                                         AS total_interactions,
        SUM(CASE WHEN direction = 'inbound' THEN 1 ELSE 0 END)          AS inbound_count,
        SUM(CASE WHEN direction = 'outbound' THEN 1 ELSE 0 END)         AS outbound_count,
        MAX(interaction_date)                                            AS latest_interaction_date,
        -- Latest channel: channel from the row with the max interaction_date
        MAX_BY(channel, interaction_date)                                AS latest_channel,
        SUM(CASE WHEN disposition = 'complaint' THEN 1 ELSE 0 END)      AS complaint_count,
        SUM(CASE WHEN disposition = 'inquiry' THEN 1 ELSE 0 END)        AS inquiry_count,
        SUM(CASE WHEN disposition = 'request' THEN 1 ELSE 0 END)        AS request_count
    FROM CUSTOMER360_DB.ANALYTICS.FACT_INTERACTION
    GROUP BY customer_id
) AS src
ON tgt.customer_id = src.customer_id
WHEN MATCHED THEN UPDATE SET
    tgt.total_interactions      = src.total_interactions,
    tgt.inbound_count           = src.inbound_count,
    tgt.outbound_count          = src.outbound_count,
    tgt.latest_interaction_date = src.latest_interaction_date,
    tgt.latest_channel          = src.latest_channel,
    tgt.complaint_count         = src.complaint_count,
    tgt.inquiry_count           = src.inquiry_count,
    tgt.request_count           = src.request_count,
    tgt._processed_at           = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    customer_id, total_interactions, inbound_count, outbound_count,
    latest_interaction_date, latest_channel,
    complaint_count, inquiry_count, request_count,
    _source_table, _processed_at
) VALUES (
    src.customer_id, src.total_interactions, src.inbound_count, src.outbound_count,
    src.latest_interaction_date, src.latest_channel,
    src.complaint_count, src.inquiry_count, src.request_count,
    'ANALYTICS.FACT_INTERACTION', CURRENT_TIMESTAMP()
);
