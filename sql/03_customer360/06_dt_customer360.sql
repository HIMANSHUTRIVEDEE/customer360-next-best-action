/*==============================================================================
  CUSTOMER360 — DYNAMIC TABLE: DT_CUSTOMER360
  Schema: CUSTOMER360_DB.ANALYTICS
  Pattern: Dynamic table over CUSTOMER_360_BASE view

  Purpose:
    Materialized, auto-refreshing serving layer for the Customer 360 profile.
    Consumers (dashboards, APIs, Cortex Agents, NBA engine) read from this
    table instead of the base view to avoid repeated joins at query time.

  Refresh Strategy:
    - TARGET_LAG = DOWNSTREAM (laziest possible refresh)
      Only refreshes when a downstream dependent object requests fresh data.
      If no downstream dynamic tables exist yet, it refreshes on explicit
      ALTER DYNAMIC TABLE ... REFRESH or when a downstream is added.
    - For hackathon cost control this avoids any background compute spend
      from periodic polling. Switch to a fixed lag (e.g. '30 minutes') once
      production SLAs are defined.

  Warehouse:
    - Uses C360_TRANSFORM_WH (XS) to keep credit burn minimal.

  Grain:
    - Exactly one row per customer_id (inherited from CUSTOMER_360_BASE).

  Dependencies:
    - CUSTOMER360_DB.ANALYTICS.CUSTOMER_360_BASE (view)
      └── DIM_CUSTOMER, DIM_HOUSEHOLD
      └── AGG_CUSTOMER_POLICY, AGG_CUSTOMER_CLAIM
      └── AGG_CUSTOMER_PAYMENT, AGG_CUSTOMER_INTERACTION
==============================================================================*/

USE ROLE C360_DATA_ENGINEER;
USE SCHEMA CUSTOMER360_DB.ANALYTICS;

CREATE OR REPLACE DYNAMIC TABLE CUSTOMER360_DB.ANALYTICS.DT_CUSTOMER360
    TARGET_LAG = DOWNSTREAM
    WAREHOUSE = CUSTOMER360_WH
    COMMENT = 'Materialized Customer 360 serving layer. Refreshes only when downstream consumers demand it. One row per customer.'
AS
SELECT
    -- Pass through all columns from the base view
    *
FROM CUSTOMER360_DB.ANALYTICS.CUSTOMER_360_BASE;
