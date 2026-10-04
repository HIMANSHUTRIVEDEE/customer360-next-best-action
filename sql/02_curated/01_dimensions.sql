/*==============================================================================
  CUSTOMER360 — CURATED LAYER: DIMENSION TABLES
  Schema: CUSTOMER360_DB.ANALYTICS
  Pattern: Type 1 (current-state) dimensions, MERGE for rerun safety
  Dependencies: All tables in CUSTOMER360_DB.RAW (Day 2 load)
==============================================================================*/

USE SCHEMA CUSTOMER360_DB.ANALYTICS;

/*------------------------------------------------------------------------------
  DIM_HOUSEHOLD
  Grain: One row per unique household_id from RAW_CUSTOMERS.
  Derived by aggregating customer records sharing the same household_id.
------------------------------------------------------------------------------*/
CREATE TABLE IF NOT EXISTS DIM_HOUSEHOLD (
    household_sk         NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    household_id         VARCHAR(20)    NOT NULL,       -- Source business key
    member_count         NUMBER(10,0)   NOT NULL,       -- Count of customers in household
    primary_state        VARCHAR(2),                    -- Most common state in household
    primary_city         VARCHAR(100),                  -- City of first member alphabetically
    household_status     VARCHAR(20),                   -- 'active' if any member active
    earliest_since       DATE,                          -- Earliest customer_since in household
    _source_table        VARCHAR(100)   DEFAULT 'RAW.RAW_CUSTOMERS',
    _source_hash         VARCHAR(64),
    _batch_id            VARCHAR(100),
    _loaded_at           TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    _processed_at        TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_dim_household PRIMARY KEY (household_sk),
    CONSTRAINT ak_dim_household UNIQUE (household_id)
);

MERGE INTO DIM_HOUSEHOLD AS tgt
USING (
    SELECT
        household_id,
        COUNT(*)                                                          AS member_count,
        MODE(state)                                                       AS primary_state,
        MIN(city)                                                         AS primary_city,
        CASE WHEN SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) > 0
             THEN 'active' ELSE 'inactive' END                            AS household_status,
        MIN(customer_since)                                               AS earliest_since,
        MAX(_row_hash)                                                    AS _source_hash,
        MAX(_batch_id)                                                    AS _batch_id
    FROM CUSTOMER360_DB.RAW.RAW_CUSTOMERS
    GROUP BY household_id
) AS src
ON tgt.household_id = src.household_id
WHEN MATCHED THEN UPDATE SET
    tgt.member_count     = src.member_count,
    tgt.primary_state    = src.primary_state,
    tgt.primary_city     = src.primary_city,
    tgt.household_status = src.household_status,
    tgt.earliest_since   = src.earliest_since,
    tgt._source_hash     = src._source_hash,
    tgt._batch_id        = src._batch_id,
    tgt._processed_at    = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    household_id, member_count, primary_state, primary_city,
    household_status, earliest_since,
    _source_table, _source_hash, _batch_id, _loaded_at, _processed_at
) VALUES (
    src.household_id, src.member_count, src.primary_state, src.primary_city,
    src.household_status, src.earliest_since,
    'RAW.RAW_CUSTOMERS', src._source_hash, src._batch_id,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
);

/*------------------------------------------------------------------------------
  DIM_CUSTOMER
  Grain: One row per unique customer_id from RAW_CUSTOMERS.
------------------------------------------------------------------------------*/
CREATE TABLE IF NOT EXISTS DIM_CUSTOMER (
    customer_sk          NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    customer_id          VARCHAR(20)    NOT NULL,       -- Source business key
    household_id         VARCHAR(20)    NOT NULL,       -- FK to DIM_HOUSEHOLD (business key)
    first_name           VARCHAR(100)   NOT NULL,
    last_name            VARCHAR(100)   NOT NULL,
    date_of_birth        DATE,
    email                VARCHAR(200),
    phone                VARCHAR(20),
    address_line_1       VARCHAR(200),
    city                 VARCHAR(100),
    state                VARCHAR(2),
    postal_code          VARCHAR(10),
    customer_since       DATE           NOT NULL,
    status               VARCHAR(20)    NOT NULL,
    _source_table        VARCHAR(100)   DEFAULT 'RAW.RAW_CUSTOMERS',
    _source_hash         VARCHAR(64),
    _batch_id            VARCHAR(100),
    _loaded_at           TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    _processed_at        TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_dim_customer PRIMARY KEY (customer_sk),
    CONSTRAINT ak_dim_customer UNIQUE (customer_id)
);

MERGE INTO DIM_CUSTOMER AS tgt
USING (
    SELECT
        customer_id, household_id, first_name, last_name,
        date_of_birth, email, phone,
        address_line_1, city, state, postal_code,
        customer_since, status,
        _row_hash AS _source_hash,
        _batch_id
    FROM CUSTOMER360_DB.RAW.RAW_CUSTOMERS
) AS src
ON tgt.customer_id = src.customer_id
WHEN MATCHED THEN UPDATE SET
    tgt.household_id   = src.household_id,
    tgt.first_name     = src.first_name,
    tgt.last_name      = src.last_name,
    tgt.date_of_birth  = src.date_of_birth,
    tgt.email          = src.email,
    tgt.phone          = src.phone,
    tgt.address_line_1 = src.address_line_1,
    tgt.city           = src.city,
    tgt.state          = src.state,
    tgt.postal_code    = src.postal_code,
    tgt.customer_since = src.customer_since,
    tgt.status         = src.status,
    tgt._source_hash   = src._source_hash,
    tgt._batch_id      = src._batch_id,
    tgt._processed_at  = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    customer_id, household_id, first_name, last_name,
    date_of_birth, email, phone,
    address_line_1, city, state, postal_code,
    customer_since, status,
    _source_table, _source_hash, _batch_id, _loaded_at, _processed_at
) VALUES (
    src.customer_id, src.household_id, src.first_name, src.last_name,
    src.date_of_birth, src.email, src.phone,
    src.address_line_1, src.city, src.state, src.postal_code,
    src.customer_since, src.status,
    'RAW.RAW_CUSTOMERS', src._source_hash, src._batch_id,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
);

/*------------------------------------------------------------------------------
  DIM_PRODUCT
  Grain: One row per distinct product_type from RAW_POLICIES.
  Populated from the distinct set of product types observed in policy data.
------------------------------------------------------------------------------*/
CREATE TABLE IF NOT EXISTS DIM_PRODUCT (
    product_sk           NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    product_type         VARCHAR(20)    NOT NULL,       -- Source business key (auto, home, umbrella, renters)
    product_name         VARCHAR(100)   NOT NULL,       -- Display name derived from type
    product_category     VARCHAR(50)    NOT NULL,       -- Grouping category
    _source_table        VARCHAR(100)   DEFAULT 'RAW.RAW_POLICIES',
    _source_hash         VARCHAR(64),
    _batch_id            VARCHAR(100),
    _loaded_at           TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    _processed_at        TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_dim_product PRIMARY KEY (product_sk),
    CONSTRAINT ak_dim_product UNIQUE (product_type)
);

MERGE INTO DIM_PRODUCT AS tgt
USING (
    SELECT
        product_type,
        INITCAP(REPLACE(product_type, '_', ' '))              AS product_name,
        CASE
            WHEN product_type IN ('auto')                     THEN 'Vehicle'
            WHEN product_type IN ('home', 'renters')          THEN 'Property'
            WHEN product_type IN ('umbrella')                 THEN 'Liability'
            ELSE 'Other'
        END                                                    AS product_category,
        MAX(_row_hash)                                         AS _source_hash,
        MAX(_batch_id)                                         AS _batch_id
    FROM CUSTOMER360_DB.RAW.RAW_POLICIES
    GROUP BY product_type
) AS src
ON tgt.product_type = src.product_type
WHEN MATCHED THEN UPDATE SET
    tgt.product_name     = src.product_name,
    tgt.product_category = src.product_category,
    tgt._source_hash     = src._source_hash,
    tgt._batch_id        = src._batch_id,
    tgt._processed_at    = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    product_type, product_name, product_category,
    _source_table, _source_hash, _batch_id, _loaded_at, _processed_at
) VALUES (
    src.product_type, src.product_name, src.product_category,
    'RAW.RAW_POLICIES', src._source_hash, src._batch_id,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
);

/*------------------------------------------------------------------------------
  DIM_POLICY
  Grain: One row per unique policy_id from RAW_POLICIES.
------------------------------------------------------------------------------*/
CREATE TABLE IF NOT EXISTS DIM_POLICY (
    policy_sk            NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    policy_id            VARCHAR(20)    NOT NULL,       -- Source business key
    customer_id          VARCHAR(20)    NOT NULL,       -- FK to DIM_CUSTOMER (business key)
    product_type         VARCHAR(20)    NOT NULL,       -- FK to DIM_PRODUCT (business key)
    status               VARCHAR(20)    NOT NULL,
    effective_date       DATE           NOT NULL,
    expiration_date      DATE           NOT NULL,
    premium_amount       NUMBER(12,2)   NOT NULL,
    payment_frequency    VARCHAR(20)    NOT NULL,
    bound_date           DATE,
    _source_table        VARCHAR(100)   DEFAULT 'RAW.RAW_POLICIES',
    _source_hash         VARCHAR(64),
    _batch_id            VARCHAR(100),
    _loaded_at           TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    _processed_at        TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_dim_policy PRIMARY KEY (policy_sk),
    CONSTRAINT ak_dim_policy UNIQUE (policy_id)
);

MERGE INTO DIM_POLICY AS tgt
USING (
    SELECT
        policy_id, customer_id, product_type, status,
        effective_date, expiration_date, premium_amount,
        payment_frequency, bound_date,
        _row_hash AS _source_hash,
        _batch_id
    FROM CUSTOMER360_DB.RAW.RAW_POLICIES
) AS src
ON tgt.policy_id = src.policy_id
WHEN MATCHED THEN UPDATE SET
    tgt.customer_id       = src.customer_id,
    tgt.product_type      = src.product_type,
    tgt.status            = src.status,
    tgt.effective_date    = src.effective_date,
    tgt.expiration_date   = src.expiration_date,
    tgt.premium_amount    = src.premium_amount,
    tgt.payment_frequency = src.payment_frequency,
    tgt.bound_date        = src.bound_date,
    tgt._source_hash      = src._source_hash,
    tgt._batch_id         = src._batch_id,
    tgt._processed_at     = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    policy_id, customer_id, product_type, status,
    effective_date, expiration_date, premium_amount,
    payment_frequency, bound_date,
    _source_table, _source_hash, _batch_id, _loaded_at, _processed_at
) VALUES (
    src.policy_id, src.customer_id, src.product_type, src.status,
    src.effective_date, src.expiration_date, src.premium_amount,
    src.payment_frequency, src.bound_date,
    'RAW.RAW_POLICIES', src._source_hash, src._batch_id,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
);

/*------------------------------------------------------------------------------
  DIM_COVERAGE
  Grain: One row per unique coverage_id from RAW_COVERAGES.
------------------------------------------------------------------------------*/
CREATE TABLE IF NOT EXISTS DIM_COVERAGE (
    coverage_sk          NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    coverage_id          VARCHAR(20)    NOT NULL,       -- Source business key
    policy_id            VARCHAR(20)    NOT NULL,       -- FK to DIM_POLICY (business key)
    coverage_type        VARCHAR(50)    NOT NULL,
    limit_amount         NUMBER(12,2)   NOT NULL,
    deductible_amount    NUMBER(12,2)   NOT NULL,
    _source_table        VARCHAR(100)   DEFAULT 'RAW.RAW_COVERAGES',
    _source_hash         VARCHAR(64),
    _batch_id            VARCHAR(100),
    _loaded_at           TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    _processed_at        TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_dim_coverage PRIMARY KEY (coverage_sk),
    CONSTRAINT ak_dim_coverage UNIQUE (coverage_id)
);

MERGE INTO DIM_COVERAGE AS tgt
USING (
    SELECT
        coverage_id, policy_id, coverage_type,
        limit_amount, deductible_amount,
        _row_hash AS _source_hash,
        _batch_id
    FROM CUSTOMER360_DB.RAW.RAW_COVERAGES
) AS src
ON tgt.coverage_id = src.coverage_id
WHEN MATCHED THEN UPDATE SET
    tgt.policy_id         = src.policy_id,
    tgt.coverage_type     = src.coverage_type,
    tgt.limit_amount      = src.limit_amount,
    tgt.deductible_amount = src.deductible_amount,
    tgt._source_hash      = src._source_hash,
    tgt._batch_id         = src._batch_id,
    tgt._processed_at     = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    coverage_id, policy_id, coverage_type,
    limit_amount, deductible_amount,
    _source_table, _source_hash, _batch_id, _loaded_at, _processed_at
) VALUES (
    src.coverage_id, src.policy_id, src.coverage_type,
    src.limit_amount, src.deductible_amount,
    'RAW.RAW_COVERAGES', src._source_hash, src._batch_id,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
);

/*------------------------------------------------------------------------------
  DIM_DATE
  Grain: One row per calendar date spanning all dates referenced in RAW tables.
  Covers: customer_since, effective_date, expiration_date, bound_date,
          filed_date, loss_date, closed_date, due_date, paid_date,
          interaction_date (date portion).
------------------------------------------------------------------------------*/
CREATE TABLE IF NOT EXISTS DIM_DATE (
    date_sk              NUMBER(8,0)    NOT NULL,       -- YYYYMMDD integer key
    calendar_date        DATE           NOT NULL,       -- Source business key
    day_of_week          NUMBER(1,0)    NOT NULL,       -- 0=Mon .. 6=Sun
    day_name             VARCHAR(9)     NOT NULL,
    day_of_month         NUMBER(2,0)    NOT NULL,
    day_of_year          NUMBER(3,0)    NOT NULL,
    week_of_year         NUMBER(2,0)    NOT NULL,
    month_number         NUMBER(2,0)    NOT NULL,
    month_name           VARCHAR(9)     NOT NULL,
    quarter_number       NUMBER(1,0)    NOT NULL,
    year_number          NUMBER(4,0)    NOT NULL,
    is_weekend           BOOLEAN        NOT NULL,
    fiscal_quarter       NUMBER(1,0)    NOT NULL,       -- Assuming calendar = fiscal
    fiscal_year          NUMBER(4,0)    NOT NULL,
    _source_table        VARCHAR(100)   DEFAULT 'DERIVED',
    _source_hash         VARCHAR(64)    DEFAULT NULL,
    _batch_id            VARCHAR(100)   DEFAULT NULL,
    _loaded_at           TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    _processed_at        TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_dim_date PRIMARY KEY (date_sk),
    CONSTRAINT ak_dim_date UNIQUE (calendar_date)
);

MERGE INTO DIM_DATE AS tgt
USING (
    WITH all_dates AS (
        SELECT customer_since AS dt FROM CUSTOMER360_DB.RAW.RAW_CUSTOMERS WHERE customer_since IS NOT NULL
        UNION
        SELECT effective_date FROM CUSTOMER360_DB.RAW.RAW_POLICIES
        UNION
        SELECT expiration_date FROM CUSTOMER360_DB.RAW.RAW_POLICIES
        UNION
        SELECT bound_date FROM CUSTOMER360_DB.RAW.RAW_POLICIES WHERE bound_date IS NOT NULL
        UNION
        SELECT filed_date FROM CUSTOMER360_DB.RAW.RAW_CLAIMS
        UNION
        SELECT loss_date FROM CUSTOMER360_DB.RAW.RAW_CLAIMS
        UNION
        SELECT closed_date FROM CUSTOMER360_DB.RAW.RAW_CLAIMS WHERE closed_date IS NOT NULL
        UNION
        SELECT due_date FROM CUSTOMER360_DB.RAW.RAW_PAYMENTS
        UNION
        SELECT paid_date FROM CUSTOMER360_DB.RAW.RAW_PAYMENTS WHERE paid_date IS NOT NULL
        UNION
        SELECT interaction_date::DATE FROM CUSTOMER360_DB.RAW.RAW_INTERACTIONS
    ),
    date_range AS (
        SELECT MIN(dt) AS min_dt, MAX(dt) AS max_dt FROM all_dates
    ),
    date_spine AS (
        SELECT DATEADD(DAY, seq4(), dr.min_dt) AS calendar_date
        FROM TABLE(GENERATOR(ROWCOUNT => 10000)) g, date_range dr
        WHERE DATEADD(DAY, seq4(), dr.min_dt) <= dr.max_dt
    )
    SELECT
        TO_NUMBER(TO_CHAR(calendar_date, 'YYYYMMDD'))        AS date_sk,
        calendar_date,
        DAYOFWEEKISO(calendar_date) - 1                       AS day_of_week,
        DAYNAME(calendar_date)                                AS day_name,
        DAY(calendar_date)                                    AS day_of_month,
        DAYOFYEAR(calendar_date)                              AS day_of_year,
        WEEKOFYEAR(calendar_date)                             AS week_of_year,
        MONTH(calendar_date)                                  AS month_number,
        MONTHNAME(calendar_date)                              AS month_name,
        QUARTER(calendar_date)                                AS quarter_number,
        YEAR(calendar_date)                                   AS year_number,
        CASE WHEN DAYOFWEEKISO(calendar_date) IN (6,7) THEN TRUE ELSE FALSE END AS is_weekend,
        QUARTER(calendar_date)                                AS fiscal_quarter,
        YEAR(calendar_date)                                   AS fiscal_year
    FROM date_spine
) AS src
ON tgt.date_sk = src.date_sk
WHEN MATCHED THEN UPDATE SET
    tgt.day_of_week    = src.day_of_week,
    tgt.day_name       = src.day_name,
    tgt.day_of_month   = src.day_of_month,
    tgt.day_of_year    = src.day_of_year,
    tgt.week_of_year   = src.week_of_year,
    tgt.month_number   = src.month_number,
    tgt.month_name     = src.month_name,
    tgt.quarter_number = src.quarter_number,
    tgt.year_number    = src.year_number,
    tgt.is_weekend     = src.is_weekend,
    tgt.fiscal_quarter = src.fiscal_quarter,
    tgt.fiscal_year    = src.fiscal_year,
    tgt._processed_at  = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    date_sk, calendar_date, day_of_week, day_name,
    day_of_month, day_of_year, week_of_year,
    month_number, month_name, quarter_number, year_number,
    is_weekend, fiscal_quarter, fiscal_year,
    _source_table, _source_hash, _batch_id, _loaded_at, _processed_at
) VALUES (
    src.date_sk, src.calendar_date, src.day_of_week, src.day_name,
    src.day_of_month, src.day_of_year, src.week_of_year,
    src.month_number, src.month_name, src.quarter_number, src.year_number,
    src.is_weekend, src.fiscal_quarter, src.fiscal_year,
    'DERIVED', NULL, NULL, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
);

/*------------------------------------------------------------------------------
  DIM_CHANNEL
  Grain: One row per distinct interaction channel from RAW_INTERACTIONS.
------------------------------------------------------------------------------*/
CREATE TABLE IF NOT EXISTS DIM_CHANNEL (
    channel_sk           NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    channel_code         VARCHAR(10)    NOT NULL,       -- Source business key (phone, email, chat)
    channel_name         VARCHAR(50)    NOT NULL,       -- Display name
    channel_category     VARCHAR(50)    NOT NULL,       -- Digital vs. Traditional
    _source_table        VARCHAR(100)   DEFAULT 'RAW.RAW_INTERACTIONS',
    _source_hash         VARCHAR(64),
    _batch_id            VARCHAR(100),
    _loaded_at           TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    _processed_at        TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_dim_channel PRIMARY KEY (channel_sk),
    CONSTRAINT ak_dim_channel UNIQUE (channel_code)
);

MERGE INTO DIM_CHANNEL AS tgt
USING (
    SELECT
        channel                                                AS channel_code,
        INITCAP(channel)                                       AS channel_name,
        CASE
            WHEN channel IN ('email', 'chat') THEN 'Digital'
            WHEN channel IN ('phone')         THEN 'Traditional'
            ELSE 'Other'
        END                                                    AS channel_category,
        MAX(_row_hash)                                         AS _source_hash,
        MAX(_batch_id)                                         AS _batch_id
    FROM CUSTOMER360_DB.RAW.RAW_INTERACTIONS
    GROUP BY channel
) AS src
ON tgt.channel_code = src.channel_code
WHEN MATCHED THEN UPDATE SET
    tgt.channel_name     = src.channel_name,
    tgt.channel_category = src.channel_category,
    tgt._source_hash     = src._source_hash,
    tgt._batch_id        = src._batch_id,
    tgt._processed_at    = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    channel_code, channel_name, channel_category,
    _source_table, _source_hash, _batch_id, _loaded_at, _processed_at
) VALUES (
    src.channel_code, src.channel_name, src.channel_category,
    'RAW.RAW_INTERACTIONS', src._source_hash, src._batch_id,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
);

/*------------------------------------------------------------------------------
  DIM_SERVICE_REPRESENTATIVE
  Grain: One row per unique representative_id from RAW_SERVICE_REPRESENTATIVES.
------------------------------------------------------------------------------*/
CREATE TABLE IF NOT EXISTS DIM_SERVICE_REPRESENTATIVE (
    representative_sk    NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    representative_id    VARCHAR(20)    NOT NULL,       -- Source business key
    name                 VARCHAR(200)   NOT NULL,
    role                 VARCHAR(30)    NOT NULL,
    active               BOOLEAN        NOT NULL,
    team                 VARCHAR(100),
    _source_table        VARCHAR(100)   DEFAULT 'RAW.RAW_SERVICE_REPRESENTATIVES',
    _source_hash         VARCHAR(64),
    _batch_id            VARCHAR(100),
    _loaded_at           TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    _processed_at        TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_dim_service_rep PRIMARY KEY (representative_sk),
    CONSTRAINT ak_dim_service_rep UNIQUE (representative_id)
);

MERGE INTO DIM_SERVICE_REPRESENTATIVE AS tgt
USING (
    SELECT
        representative_id,
        name,
        role,
        CASE WHEN UPPER(active) = 'TRUE' THEN TRUE ELSE FALSE END AS active,
        team,
        _row_hash AS _source_hash,
        _batch_id
    FROM CUSTOMER360_DB.RAW.RAW_SERVICE_REPRESENTATIVES
) AS src
ON tgt.representative_id = src.representative_id
WHEN MATCHED THEN UPDATE SET
    tgt.name           = src.name,
    tgt.role           = src.role,
    tgt.active         = src.active,
    tgt.team           = src.team,
    tgt._source_hash   = src._source_hash,
    tgt._batch_id      = src._batch_id,
    tgt._processed_at  = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    representative_id, name, role, active, team,
    _source_table, _source_hash, _batch_id, _loaded_at, _processed_at
) VALUES (
    src.representative_id, src.name, src.role, src.active, src.team,
    'RAW.RAW_SERVICE_REPRESENTATIVES', src._source_hash, src._batch_id,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
);
