-- =============================================================================
-- sql/01_raw/05_unstructured_tables.sql
-- Purpose: Create RAW table for unstructured documents (policy summaries,
--          emails, transcripts, knowledge base articles) used by Cortex Search.
-- Role: C360_DATA_ENGINEER
-- Idempotent: CREATE OR REPLACE
-- =============================================================================

USE DATABASE CUSTOMER360_DB;
USE SCHEMA RAW;

CREATE OR REPLACE TABLE RAW_DOCUMENTS (
    doc_id          VARCHAR(30)     NOT NULL    COMMENT 'Unique document identifier (DOC-POL-xxx, DOC-EMAIL-xxx, DOC-TRX-xxx, DOC-KB-xxx)',
    customer_id     VARCHAR(20)                 COMMENT 'FK to customer — NULL for knowledge base articles',
    policy_id       VARCHAR(20)                 COMMENT 'FK to policy — NULL for non-policy documents',
    interaction_id  VARCHAR(20)                 COMMENT 'FK to interaction — NULL for non-interaction documents',
    doc_type        VARCHAR(30)     NOT NULL    COMMENT 'Document type: policy_summary, email, transcript, knowledge_base',
    title           VARCHAR(500)    NOT NULL    COMMENT 'Document title or email subject line',
    content         VARCHAR         NOT NULL    COMMENT 'Full text content of the document',
    created_at      TIMESTAMP_NTZ   NOT NULL    COMMENT 'Document creation timestamp',

    _loaded_at      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()  COMMENT 'When this row was loaded into RAW',
    _source_file    VARCHAR(500)    COMMENT 'Source filename from stage',
    _batch_id       VARCHAR(100)    COMMENT 'Load batch identifier'
)
COMMENT = 'RAW landing: unstructured documents for Cortex Search. Source: unstructured_documents.csv. Logical PK: doc_id.';
