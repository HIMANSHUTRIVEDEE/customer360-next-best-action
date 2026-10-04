/*==============================================================================
  CUSTOMER360 — INCREMENTAL PIPELINE DEMONSTRATION
  Schema: CUSTOMER360_DB.ANALYTICS
  Purpose: End-to-end proof that the incremental pipeline works:
           Insert → Stream captures → Aggregates refresh → DT reflects change

  Execution Order:
    Step 1: Record baseline state
    Step 2: Insert a synthetic interaction into FACT_INTERACTION
    Step 3: Verify INTERACTION_STREAM captured the new row
    Step 4: Refresh aggregates (simulate pipeline run)
    Step 5: Refresh DT_CUSTOMER360
    Step 6: Verify DT_CUSTOMER360 reflects the updated interaction count

  Notes:
    - Uses customer_id = 'CUST-001' (assumes this customer exists in DIM_CUSTOMER)
    - The inserted interaction is clearly marked as synthetic for easy cleanup
    - Run steps sequentially; each depends on the prior step's commit
==============================================================================*/

USE ROLE C360_DATA_ENGINEER;
USE SCHEMA CUSTOMER360_DB.ANALYTICS;

-- =============================================================================
-- STEP 1: Record baseline interaction count for CUST-001
-- =============================================================================
SELECT
    customer_id,
    total_interactions AS baseline_interactions
FROM CUSTOMER360_DB.ANALYTICS.DT_CUSTOMER360
WHERE customer_id = 'CUST-001';


-- =============================================================================
-- STEP 2: Insert one synthetic interaction into FACT_INTERACTION
-- =============================================================================
INSERT INTO CUSTOMER360_DB.ANALYTICS.FACT_INTERACTION (
    interaction_id,
    customer_id,
    channel,
    representative_id,
    interaction_date,
    interaction_date_key,
    direction,
    disposition,
    duration_seconds,
    _source_table,
    _source_hash,
    _batch_id,
    _loaded_at,
    _processed_at
) VALUES (
    'INT-DEMO-99999',                   -- Unique synthetic ID
    'CUST-001',                         -- Target customer
    'phone',                            -- Channel
    NULL,                               -- No representative
    CURRENT_TIMESTAMP(),                -- Interaction timestamp
    CURRENT_DATE(),                     -- Date key
    'inbound',                          -- Direction
    'inquiry',                          -- Disposition
    120,                                -- 2-minute call
    'DEMO',                             -- Marked as demo data
    MD5('DEMO-INCREMENTAL-TEST'),       -- Deterministic hash
    'DEMO-BATCH-001',                   -- Demo batch
    CURRENT_TIMESTAMP(),
    CURRENT_TIMESTAMP()
);


-- =============================================================================
-- STEP 3: Verify INTERACTION_STREAM captured the insert
--         Expected: 1 row with interaction_id = 'INT-DEMO-99999'
-- =============================================================================
SELECT
    interaction_id,
    customer_id,
    channel,
    direction,
    disposition,
    METADATA$ACTION,
    METADATA$ISUPDATE
FROM CUSTOMER360_DB.ANALYTICS.INTERACTION_STREAM
WHERE interaction_id = 'INT-DEMO-99999';


-- =============================================================================
-- STEP 4: Refresh AGG_CUSTOMER_INTERACTION for the affected customer
--         (In production, a task or dynamic table handles this automatically)
-- =============================================================================
MERGE INTO CUSTOMER360_DB.ANALYTICS.AGG_CUSTOMER_INTERACTION AS tgt
USING (
    SELECT
        customer_id,
        COUNT(*)                                                         AS total_interactions,
        SUM(CASE WHEN direction = 'inbound' THEN 1 ELSE 0 END)          AS inbound_count,
        SUM(CASE WHEN direction = 'outbound' THEN 1 ELSE 0 END)         AS outbound_count,
        MAX(interaction_date)                                            AS latest_interaction_date,
        MAX_BY(channel, interaction_date)                                AS latest_channel,
        SUM(CASE WHEN disposition = 'complaint' THEN 1 ELSE 0 END)      AS complaint_count,
        SUM(CASE WHEN disposition = 'inquiry' THEN 1 ELSE 0 END)        AS inquiry_count,
        SUM(CASE WHEN disposition = 'request' THEN 1 ELSE 0 END)        AS request_count
    FROM CUSTOMER360_DB.ANALYTICS.FACT_INTERACTION
    WHERE customer_id = 'CUST-001'
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


-- =============================================================================
-- STEP 5: Refresh DT_CUSTOMER360
-- =============================================================================
ALTER DYNAMIC TABLE CUSTOMER360_DB.ANALYTICS.DT_CUSTOMER360 REFRESH;


-- =============================================================================
-- STEP 6: Verify DT_CUSTOMER360 now shows incremented interaction count
--         Expected: total_interactions = baseline + 1
-- =============================================================================
SELECT
    customer_id,
    total_interactions,
    latest_interaction_date,
    latest_channel,
    interactions_inquiries,
    view_refreshed_at
FROM CUSTOMER360_DB.ANALYTICS.DT_CUSTOMER360
WHERE customer_id = 'CUST-001';


-- =============================================================================
-- CLEANUP (optional): Remove synthetic demo row after demonstration
-- =============================================================================
-- DELETE FROM CUSTOMER360_DB.ANALYTICS.FACT_INTERACTION
-- WHERE interaction_id = 'INT-DEMO-99999';
