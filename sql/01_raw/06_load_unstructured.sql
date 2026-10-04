-- =============================================================================
-- sql/01_raw/06_load_unstructured.sql
-- Purpose: Stage and load unstructured documents CSV into RAW_DOCUMENTS
-- Role: C360_DATA_ENGINEER
-- Prerequisites: 05_unstructured_tables.sql, 02_stage_file_format.sql
-- =============================================================================

USE DATABASE CUSTOMER360_DB;
USE SCHEMA RAW;
USE WAREHOUSE CUSTOMER360_WH;

-- Stage the file (run from SnowSQL/CLI — adjust path for your environment)
-- PUT file://data/generated/unstructured_documents.csv @RAW.C360_LOAD_STAGE/unstructured/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- Load into table
COPY INTO RAW.RAW_DOCUMENTS (
    doc_id, customer_id, policy_id, interaction_id,
    doc_type, title, content, created_at
)
FROM @RAW.C360_LOAD_STAGE/unstructured/
FILE_FORMAT = RAW.CSV_LOAD_FORMAT
ON_ERROR = 'CONTINUE'
PURGE = FALSE;
