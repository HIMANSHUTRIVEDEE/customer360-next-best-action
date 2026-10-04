-- =============================================================================
-- sql/10_search/01_cortex_search_service.sql
-- Purpose: Create Cortex Search Service over unstructured documents
--          for RAG-based retrieval in the Customer 360 Agent.
-- Role: C360_DATA_ENGINEER
-- Prerequisites: RAW_DOCUMENTS table populated
-- =============================================================================

USE ROLE C360_DATA_ENGINEER;
USE DATABASE CUSTOMER360_DB;
USE SCHEMA ANALYTICS;
USE WAREHOUSE CUSTOMER360_WH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SVC_CUSTOMER_DOCS
  ON content
  PRIMARY KEY (doc_id)
  ATTRIBUTES customer_id, doc_type, policy_id, title
  WAREHOUSE = CUSTOMER360_WH
  TARGET_LAG = '1 hour'
  COMMENT = 'Cortex Search over unstructured customer documents: policy summaries, emails, transcripts, and knowledge base articles. Used by CUSTOMER360_AGENT for RAG retrieval.'
AS
  SELECT
    doc_id,
    customer_id,
    policy_id,
    interaction_id,
    doc_type,
    title,
    content,
    created_at
  FROM CUSTOMER360_DB.RAW.RAW_DOCUMENTS;

-- Grant usage to roles that need to query via the agent
GRANT USAGE ON CORTEX SEARCH SERVICE CUSTOMER360_DB.ANALYTICS.SVC_CUSTOMER_DOCS
  TO ROLE ACCOUNTADMIN;
