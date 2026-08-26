-- =============================================================================
-- sql/01_raw/01_raw_tables.sql
-- Purpose: Create RAW landing tables matching generated CSV structure exactly
-- Administrative role required: C360_DATA_ENGINEER (schema owner)
-- Idempotent: Uses CREATE OR REPLACE (safe rerun; drops and recreates)
-- =============================================================================

USE DATABASE CUSTOMER360_DB;
USE SCHEMA RAW;

-- =============================================================================
-- RAW_SERVICE_REPRESENTATIVES
-- Grain: One row per service representative (employee)
-- Logical PK: representative_id
-- =============================================================================
CREATE OR REPLACE TABLE RAW_SERVICE_REPRESENTATIVES (
    -- Business columns (match CSV header exactly)
    representative_id   VARCHAR(20)     NOT NULL    COMMENT 'Business key — employee ID (e.g., REP-001)',
    name                VARCHAR(200)    NOT NULL    COMMENT 'Display name',
    role                VARCHAR(30)     NOT NULL    COMMENT 'Role: service_rep, retention_specialist, supervisor',
    active              VARCHAR(5)      NOT NULL    COMMENT 'Employment status: TRUE or FALSE',
    team                VARCHAR(100)                COMMENT 'Team assignment (nullable)',

    -- Audit columns
    _loaded_at          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()  COMMENT 'When this row was loaded into RAW',
    _source_file        VARCHAR(500)    COMMENT 'Source filename from stage',
    _batch_id           VARCHAR(100)    COMMENT 'Load batch identifier',
    _row_hash           VARCHAR(64)     COMMENT 'SHA-256 hash of business columns for change detection'
)
COMMENT = 'RAW landing: service representatives. Source: service_representatives.csv. Logical PK: representative_id.';

-- =============================================================================
-- RAW_CUSTOMERS
-- Grain: One row per individual customer (household attributes embedded)
-- Logical PK: customer_id
-- Logical FK: household_id (groups customers; no target table in RAW)
-- =============================================================================
CREATE OR REPLACE TABLE RAW_CUSTOMERS (
    -- Business columns
    customer_id         VARCHAR(20)     NOT NULL    COMMENT 'Business key — carrier-assigned customer ID',
    household_id        VARCHAR(20)     NOT NULL    COMMENT 'Household grouping key (shared address)',
    first_name          VARCHAR(100)    NOT NULL    COMMENT 'Given name',
    last_name           VARCHAR(100)    NOT NULL    COMMENT 'Family name',
    customer_since      DATE            NOT NULL    COMMENT 'Relationship start date',
    status              VARCHAR(20)     NOT NULL    COMMENT 'Lifecycle: active, inactive, prospect',
    date_of_birth       DATE                        COMMENT 'Date of birth (nullable)',
    email               VARCHAR(200)                COMMENT 'Synthetic email (@example.com)',
    phone               VARCHAR(20)                 COMMENT 'Synthetic phone (555-XXXX)',
    address_line_1      VARCHAR(200)    NOT NULL    COMMENT 'Household primary address (embedded)',
    city                VARCHAR(100)    NOT NULL    COMMENT 'City',
    state               VARCHAR(2)      NOT NULL    COMMENT 'US state code',
    postal_code         VARCHAR(10)     NOT NULL    COMMENT 'ZIP code',

    -- Audit columns
    _loaded_at          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()  COMMENT 'When this row was loaded into RAW',
    _source_file        VARCHAR(500)    COMMENT 'Source filename from stage',
    _batch_id           VARCHAR(100)    COMMENT 'Load batch identifier',
    _row_hash           VARCHAR(64)     COMMENT 'SHA-256 hash of business columns for change detection'
)
COMMENT = 'RAW landing: customers with embedded household attributes. Source: customers.csv. Logical PK: customer_id.';

-- =============================================================================
-- RAW_POLICIES
-- Grain: One row per policy term
-- Logical PK: policy_id
-- Logical FK: customer_id → RAW_CUSTOMERS.customer_id
-- =============================================================================
CREATE OR REPLACE TABLE RAW_POLICIES (
    -- Business columns
    policy_id           VARCHAR(20)     NOT NULL    COMMENT 'Business key — policy number',
    customer_id         VARCHAR(20)     NOT NULL    COMMENT 'FK → RAW_CUSTOMERS (not enforced)',
    product_type        VARCHAR(20)     NOT NULL    COMMENT 'Line of business: auto, home, umbrella, renters',
    status              VARCHAR(20)     NOT NULL    COMMENT 'Lifecycle: quoted, bound, active, renewed, lapsed, cancelled',
    effective_date      DATE            NOT NULL    COMMENT 'Coverage start date',
    expiration_date     DATE            NOT NULL    COMMENT 'Coverage end / renewal trigger date',
    premium_amount      NUMBER(12,2)    NOT NULL    COMMENT 'Annual premium in USD',
    payment_frequency   VARCHAR(20)     NOT NULL    COMMENT 'Billing cadence: monthly, quarterly, semi_annual, annual',
    bound_date          DATE                        COMMENT 'Binding date (null if status = quoted)',

    -- Audit columns
    _loaded_at          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()  COMMENT 'When this row was loaded into RAW',
    _source_file        VARCHAR(500)    COMMENT 'Source filename from stage',
    _batch_id           VARCHAR(100)    COMMENT 'Load batch identifier',
    _row_hash           VARCHAR(64)     COMMENT 'SHA-256 hash of business columns for change detection'
)
COMMENT = 'RAW landing: policy terms. Source: policies.csv. Logical PK: policy_id. Logical FK: customer_id.';

-- =============================================================================
-- RAW_COVERAGES
-- Grain: One row per coverage component per policy
-- Logical PK: coverage_id
-- Logical FK: policy_id → RAW_POLICIES.policy_id
-- =============================================================================
CREATE OR REPLACE TABLE RAW_COVERAGES (
    -- Business columns
    coverage_id         VARCHAR(20)     NOT NULL    COMMENT 'Surrogate key — coverage identifier',
    policy_id           VARCHAR(20)     NOT NULL    COMMENT 'FK → RAW_POLICIES (not enforced)',
    coverage_type       VARCHAR(50)     NOT NULL    COMMENT 'Coverage category: liability, collision, comprehensive, dwelling, etc.',
    limit_amount        NUMBER(12,2)    NOT NULL    COMMENT 'Maximum coverage limit in USD',
    deductible_amount   NUMBER(12,2)    NOT NULL    COMMENT 'Customer responsibility in USD',

    -- Audit columns
    _loaded_at          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()  COMMENT 'When this row was loaded into RAW',
    _source_file        VARCHAR(500)    COMMENT 'Source filename from stage',
    _batch_id           VARCHAR(100)    COMMENT 'Load batch identifier',
    _row_hash           VARCHAR(64)     COMMENT 'SHA-256 hash of business columns for change detection'
)
COMMENT = 'RAW landing: coverage components. Source: coverages.csv. Logical PK: coverage_id. Logical FK: policy_id.';

-- =============================================================================
-- RAW_CLAIMS
-- Grain: One row per claim event
-- Logical PK: claim_id
-- Logical FK: policy_id → RAW_POLICIES, customer_id → RAW_CUSTOMERS
-- =============================================================================
CREATE OR REPLACE TABLE RAW_CLAIMS (
    -- Business columns
    claim_id            VARCHAR(20)     NOT NULL    COMMENT 'Business key — claim number',
    policy_id           VARCHAR(20)     NOT NULL    COMMENT 'FK → RAW_POLICIES (not enforced)',
    customer_id         VARCHAR(20)     NOT NULL    COMMENT 'FK → RAW_CUSTOMERS (denormalized, not enforced)',
    filed_date          DATE            NOT NULL    COMMENT 'When claim was submitted',
    status              VARCHAR(20)     NOT NULL    COMMENT 'Lifecycle: filed, under_review, settled, denied, withdrawn',
    loss_date           DATE            NOT NULL    COMMENT 'When the loss event occurred',
    loss_type           VARCHAR(50)     NOT NULL    COMMENT 'Category: collision, water_damage, theft, liability, etc.',
    reserve_amount      NUMBER(12,2)                COMMENT 'Estimated payout (null until assessed)',
    paid_amount         NUMBER(12,2)                COMMENT 'Actual payout (null until settled)',
    closed_date         DATE                        COMMENT 'Resolution date (null if open)',

    -- Audit columns
    _loaded_at          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()  COMMENT 'When this row was loaded into RAW',
    _source_file        VARCHAR(500)    COMMENT 'Source filename from stage',
    _batch_id           VARCHAR(100)    COMMENT 'Load batch identifier',
    _row_hash           VARCHAR(64)     COMMENT 'SHA-256 hash of business columns for change detection'
)
COMMENT = 'RAW landing: insurance claims. Source: claims.csv. Logical PK: claim_id. Logical FK: policy_id, customer_id.';

-- =============================================================================
-- RAW_PAYMENTS
-- Grain: One row per payment obligation (one per billing cycle per policy)
-- Logical PK: payment_id
-- Logical FK: customer_id → RAW_CUSTOMERS, policy_id → RAW_POLICIES
-- =============================================================================
CREATE OR REPLACE TABLE RAW_PAYMENTS (
    -- Business columns
    payment_id          VARCHAR(20)     NOT NULL    COMMENT 'Surrogate key — payment identifier',
    customer_id         VARCHAR(20)     NOT NULL    COMMENT 'FK → RAW_CUSTOMERS (not enforced)',
    policy_id           VARCHAR(20)     NOT NULL    COMMENT 'FK → RAW_POLICIES (not enforced)',
    due_date            DATE            NOT NULL    COMMENT 'When payment is due',
    amount              NUMBER(12,2)    NOT NULL    COMMENT 'Amount owed in USD',
    status              VARCHAR(20)     NOT NULL    COMMENT 'Outcome: on_time, late, grace_period, missed, pending',
    paid_date           DATE                        COMMENT 'When paid (null if missed or pending)',
    amount_paid         NUMBER(12,2)                COMMENT 'Amount remitted (null if not yet paid)',

    -- Audit columns
    _loaded_at          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()  COMMENT 'When this row was loaded into RAW',
    _source_file        VARCHAR(500)    COMMENT 'Source filename from stage',
    _batch_id           VARCHAR(100)    COMMENT 'Load batch identifier',
    _row_hash           VARCHAR(64)     COMMENT 'SHA-256 hash of business columns for change detection'
)
COMMENT = 'RAW landing: premium payments. Source: payments.csv. Logical PK: payment_id. Logical FK: customer_id, policy_id.';

-- =============================================================================
-- RAW_INTERACTIONS
-- Grain: One row per contact event
-- Logical PK: interaction_id (also serves as dedup key for incremental pipeline)
-- Logical FK: customer_id → RAW_CUSTOMERS, representative_id → RAW_SERVICE_REPRESENTATIVES
-- =============================================================================
CREATE OR REPLACE TABLE RAW_INTERACTIONS (
    -- Business columns
    interaction_id      VARCHAR(20)     NOT NULL    COMMENT 'Surrogate key — interaction identifier (dedup key)',
    customer_id         VARCHAR(20)     NOT NULL    COMMENT 'FK → RAW_CUSTOMERS (not enforced)',
    channel             VARCHAR(10)     NOT NULL    COMMENT 'Medium: phone, email, chat',
    direction           VARCHAR(20)     NOT NULL    COMMENT 'Initiator: inbound, outbound, internal_note',
    disposition         VARCHAR(20)     NOT NULL    COMMENT 'Type: inquiry, complaint, request, notification, general',
    interaction_date    TIMESTAMP_NTZ   NOT NULL    COMMENT 'When the interaction occurred (ISO 8601)',
    duration_seconds    NUMBER(10,0)                COMMENT 'Call duration in seconds (null for email/chat)',
    representative_id   VARCHAR(20)                 COMMENT 'FK → RAW_SERVICE_REPRESENTATIVES (null for automated)',

    -- Audit columns
    _loaded_at          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()  COMMENT 'When this row was loaded into RAW',
    _source_file        VARCHAR(500)    COMMENT 'Source filename from stage',
    _batch_id           VARCHAR(100)    COMMENT 'Load batch identifier',
    _row_hash           VARCHAR(64)     COMMENT 'SHA-256 hash of business columns for change detection'
)
COMMENT = 'RAW landing: customer interactions. Source: interactions.csv. Logical PK: interaction_id. Logical FK: customer_id, representative_id.';

-- =============================================================================
-- RAW_TRANSCRIPTS
-- Grain: One row per interaction with textual content (not every interaction has one)
-- Logical PK: transcript_id
-- Logical FK: interaction_id → RAW_INTERACTIONS (1:1 unique constraint documented)
-- =============================================================================
CREATE OR REPLACE TABLE RAW_TRANSCRIPTS (
    -- Business columns
    transcript_id       VARCHAR(20)     NOT NULL    COMMENT 'Surrogate key — transcript identifier',
    interaction_id      VARCHAR(20)     NOT NULL    COMMENT 'FK → RAW_INTERACTIONS (1:1; not enforced)',
    content_type        VARCHAR(20)     NOT NULL    COMMENT 'Source: call_transcript, email_body, agent_note',
    raw_text            VARCHAR(16777216) NOT NULL  COMMENT 'Verbatim unstructured content (up to 16MB)',
    word_count          NUMBER(10,0)    NOT NULL    COMMENT 'Word count of raw_text',
    recording_consent_flag VARCHAR(5)   NOT NULL    COMMENT 'Recording consent: TRUE or FALSE',

    -- Audit columns
    _loaded_at          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()  COMMENT 'When this row was loaded into RAW',
    _source_file        VARCHAR(500)    COMMENT 'Source filename from stage',
    _batch_id           VARCHAR(100)    COMMENT 'Load batch identifier',
    _row_hash           VARCHAR(64)     COMMENT 'SHA-256 hash of business columns for change detection'
)
COMMENT = 'RAW landing: interaction transcripts. Source: transcripts.csv. Logical PK: transcript_id. Logical FK: interaction_id (1:1). Contains raw text for Cortex enrichment.';
