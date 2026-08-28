/*==============================================================================
  CUSTOMER360 — CURATED LAYER: FACT TABLES
  Schema: CUSTOMER360_DB.ANALYTICS
  Pattern: Type 1 facts, MERGE for rerun safety
  Dependencies: CUSTOMER360_DB.RAW (source), dimension tables in ANALYTICS
==============================================================================*/

USE ROLE C360_DATA_ENGINEER;
USE SCHEMA CUSTOMER360_DB.ANALYTICS;

/*------------------------------------------------------------------------------
  FACT_CLAIM
  Grain: One row per unique claim_id from RAW_CLAIMS.
  Each claim links to a policy, customer, and relevant dates.
------------------------------------------------------------------------------*/
CREATE TABLE IF NOT EXISTS CUSTOMER360_DB.ANALYTICS.FACT_CLAIM (
    claim_sk             NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    claim_id             VARCHAR(20)    NOT NULL,       -- Source business key
    policy_id            VARCHAR(20)    NOT NULL,       -- FK to DIM_POLICY (business key)
    customer_id          VARCHAR(20)    NOT NULL,       -- FK to DIM_CUSTOMER (business key)
    filed_date           DATE           NOT NULL,       -- FK to DIM_DATE (calendar_date)
    loss_date            DATE           NOT NULL,       -- FK to DIM_DATE (calendar_date)
    closed_date          DATE,                          -- FK to DIM_DATE (calendar_date), nullable
    status               VARCHAR(20)    NOT NULL,
    loss_type            VARCHAR(50)    NOT NULL,
    reserve_amount       NUMBER(12,2),
    paid_amount          NUMBER(12,2),
    _source_table        VARCHAR(100)   DEFAULT 'RAW.RAW_CLAIMS',
    _source_hash         VARCHAR(64),
    _batch_id            VARCHAR(100),
    _loaded_at           TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    _processed_at        TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_fact_claim PRIMARY KEY (claim_sk),
    CONSTRAINT ak_fact_claim UNIQUE (claim_id)
);

MERGE INTO CUSTOMER360_DB.ANALYTICS.FACT_CLAIM AS tgt
USING (
    SELECT
        claim_id,
        policy_id,
        customer_id,
        filed_date,
        loss_date,
        closed_date,
        status,
        loss_type,
        reserve_amount,
        paid_amount,
        _row_hash  AS _source_hash,
        _batch_id
    FROM CUSTOMER360_DB.RAW.RAW_CLAIMS
) AS src
ON tgt.claim_id = src.claim_id
WHEN MATCHED THEN UPDATE SET
    tgt.policy_id      = src.policy_id,
    tgt.customer_id    = src.customer_id,
    tgt.filed_date     = src.filed_date,
    tgt.loss_date      = src.loss_date,
    tgt.closed_date    = src.closed_date,
    tgt.status         = src.status,
    tgt.loss_type      = src.loss_type,
    tgt.reserve_amount = src.reserve_amount,
    tgt.paid_amount    = src.paid_amount,
    tgt._source_hash   = src._source_hash,
    tgt._batch_id      = src._batch_id,
    tgt._processed_at  = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    claim_id, policy_id, customer_id,
    filed_date, loss_date, closed_date,
    status, loss_type, reserve_amount, paid_amount,
    _source_table, _source_hash, _batch_id, _loaded_at, _processed_at
) VALUES (
    src.claim_id, src.policy_id, src.customer_id,
    src.filed_date, src.loss_date, src.closed_date,
    src.status, src.loss_type, src.reserve_amount, src.paid_amount,
    'RAW.RAW_CLAIMS', src._source_hash, src._batch_id,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
);

/*------------------------------------------------------------------------------
  FACT_PAYMENT
  Grain: One row per unique payment_id from RAW_PAYMENTS.
  Each payment links to a customer, policy, and due/paid dates.
------------------------------------------------------------------------------*/
CREATE TABLE IF NOT EXISTS CUSTOMER360_DB.ANALYTICS.FACT_PAYMENT (
    payment_sk           NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    payment_id           VARCHAR(20)    NOT NULL,       -- Source business key
    customer_id          VARCHAR(20)    NOT NULL,       -- FK to DIM_CUSTOMER (business key)
    policy_id            VARCHAR(20)    NOT NULL,       -- FK to DIM_POLICY (business key)
    due_date             DATE           NOT NULL,       -- FK to DIM_DATE (calendar_date)
    paid_date            DATE,                          -- FK to DIM_DATE (calendar_date), nullable
    amount               NUMBER(12,2)   NOT NULL,       -- Amount owed
    amount_paid          NUMBER(12,2),                  -- Amount remitted
    status               VARCHAR(20)    NOT NULL,
    _source_table        VARCHAR(100)   DEFAULT 'RAW.RAW_PAYMENTS',
    _source_hash         VARCHAR(64),
    _batch_id            VARCHAR(100),
    _loaded_at           TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    _processed_at        TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_fact_payment PRIMARY KEY (payment_sk),
    CONSTRAINT ak_fact_payment UNIQUE (payment_id)
);

MERGE INTO CUSTOMER360_DB.ANALYTICS.FACT_PAYMENT AS tgt
USING (
    SELECT
        payment_id,
        customer_id,
        policy_id,
        due_date,
        paid_date,
        amount,
        amount_paid,
        status,
        _row_hash  AS _source_hash,
        _batch_id
    FROM CUSTOMER360_DB.RAW.RAW_PAYMENTS
) AS src
ON tgt.payment_id = src.payment_id
WHEN MATCHED THEN UPDATE SET
    tgt.customer_id  = src.customer_id,
    tgt.policy_id    = src.policy_id,
    tgt.due_date     = src.due_date,
    tgt.paid_date    = src.paid_date,
    tgt.amount       = src.amount,
    tgt.amount_paid  = src.amount_paid,
    tgt.status       = src.status,
    tgt._source_hash = src._source_hash,
    tgt._batch_id    = src._batch_id,
    tgt._processed_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    payment_id, customer_id, policy_id,
    due_date, paid_date, amount, amount_paid, status,
    _source_table, _source_hash, _batch_id, _loaded_at, _processed_at
) VALUES (
    src.payment_id, src.customer_id, src.policy_id,
    src.due_date, src.paid_date, src.amount, src.amount_paid, src.status,
    'RAW.RAW_PAYMENTS', src._source_hash, src._batch_id,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
);

/*------------------------------------------------------------------------------
  FACT_INTERACTION
  Grain: One row per unique interaction_id from RAW_INTERACTIONS.
  Each interaction links to a customer, channel, date, and optionally a
  service representative. Null representative_id is preserved as-is.
  Transcript content is stored separately in TRANSCRIPT_CONTENT.
------------------------------------------------------------------------------*/
CREATE TABLE IF NOT EXISTS CUSTOMER360_DB.ANALYTICS.FACT_INTERACTION (
    interaction_sk       NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    interaction_id       VARCHAR(20)    NOT NULL,       -- Source business key
    customer_id          VARCHAR(20)    NOT NULL,       -- FK to DIM_CUSTOMER (business key)
    channel              VARCHAR(10)    NOT NULL,       -- FK to DIM_CHANNEL (channel_code)
    representative_id    VARCHAR(20),                   -- FK to DIM_SERVICE_REPRESENTATIVE (nullable)
    interaction_date     TIMESTAMP_NTZ  NOT NULL,       -- Full timestamp of interaction
    interaction_date_key DATE           NOT NULL,       -- FK to DIM_DATE (calendar_date)
    direction            VARCHAR(20)    NOT NULL,
    disposition          VARCHAR(20)    NOT NULL,
    duration_seconds     NUMBER(10,0),
    _source_table        VARCHAR(100)   DEFAULT 'RAW.RAW_INTERACTIONS',
    _source_hash         VARCHAR(64),
    _batch_id            VARCHAR(100),
    _loaded_at           TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    _processed_at        TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_fact_interaction PRIMARY KEY (interaction_sk),
    CONSTRAINT ak_fact_interaction UNIQUE (interaction_id)
);

MERGE INTO CUSTOMER360_DB.ANALYTICS.FACT_INTERACTION AS tgt
USING (
    SELECT
        interaction_id,
        customer_id,
        channel,
        representative_id,
        interaction_date,
        interaction_date::DATE             AS interaction_date_key,
        direction,
        disposition,
        duration_seconds,
        _row_hash  AS _source_hash,
        _batch_id
    FROM CUSTOMER360_DB.RAW.RAW_INTERACTIONS
) AS src
ON tgt.interaction_id = src.interaction_id
WHEN MATCHED THEN UPDATE SET
    tgt.customer_id        = src.customer_id,
    tgt.channel            = src.channel,
    tgt.representative_id  = src.representative_id,
    tgt.interaction_date   = src.interaction_date,
    tgt.interaction_date_key = src.interaction_date_key,
    tgt.direction          = src.direction,
    tgt.disposition        = src.disposition,
    tgt.duration_seconds   = src.duration_seconds,
    tgt._source_hash       = src._source_hash,
    tgt._batch_id          = src._batch_id,
    tgt._processed_at      = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    interaction_id, customer_id, channel, representative_id,
    interaction_date, interaction_date_key, direction, disposition,
    duration_seconds,
    _source_table, _source_hash, _batch_id, _loaded_at, _processed_at
) VALUES (
    src.interaction_id, src.customer_id, src.channel, src.representative_id,
    src.interaction_date, src.interaction_date_key, src.direction, src.disposition,
    src.duration_seconds,
    'RAW.RAW_INTERACTIONS', src._source_hash, src._batch_id,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
);
