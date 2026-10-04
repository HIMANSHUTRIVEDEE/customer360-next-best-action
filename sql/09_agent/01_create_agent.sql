-- =============================================================================
-- sql/09_agent/01_create_agent.sql
-- Purpose: Create the Customer 360 conversational agent.
--          Uses SV_CUSTOMER_360 semantic view for structured queries.
--          Uses SVC_CUSTOMER_DOCS Cortex Search for unstructured RAG.
-- Role: C360_DATA_ENGINEER
-- Idempotent: CREATE OR REPLACE AGENT
-- =============================================================================

USE ROLE C360_DATA_ENGINEER;
USE DATABASE CUSTOMER360_DB;
USE SCHEMA ANALYTICS;
USE WAREHOUSE CUSTOMER360_WH;

CREATE OR REPLACE AGENT CUSTOMER360_AGENT
  COMMENT = 'Conversational agent for Customer 360 Next Best Action. Answers questions about customers, policies, risk, claims, and recommendations using structured data and unstructured document search.'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  instructions:
    response: |
      You are an AI assistant for insurance service representatives using
      the Customer 360 Next Best Action platform.

      Your capabilities:
      - Answer questions about customer profiles, policies, claims, payments,
        interactions, risk signals, and NBA recommendations using structured data.
      - Search unstructured documents including policy summaries, customer emails,
        call transcripts, and internal knowledge base articles.

      Guidelines:
      - Always reference specific customer IDs (e.g. CUST-001) when discussing
        individual customers.
      - Be concise and actionable. Service reps need quick, accurate answers.
      - When presenting risk or recommendation data, include confidence scores
        and evidence where available.
      - When quoting from documents, cite the document title and type.
      - If a question cannot be answered from the available data, say so clearly.
      - Do not fabricate data or make assumptions beyond what the data shows.
    orchestration: |
      Use the Analyst tool for structured data questions: counts, aggregations,
      risk scores, customer metrics, and NBA recommendations.
      Use the Search tool for unstructured questions: policy details and coverages,
      customer emails and complaints, call transcripts, and internal procedures
      or knowledge base articles.
      If unsure which tool to use, try both and combine the results.
    sample_questions:
      - question: "How many high-risk customers do we have?"
      - question: "What is the risk profile for CUST-001?"
      - question: "What does Maria Chen's auto policy cover?"
      - question: "Show me the latest email from CUST-005"
      - question: "What is the escalation procedure for complaints?"
      - question: "What did CUST-002 say in their last call?"

  tools:
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: Analyst1
        description: >
          Query structured customer 360 data including profiles, policies,
          claims, payments, interactions, risk signals, and NBA recommendations.

    - tool_spec:
        type: cortex_search
        name: Search1
        description: >
          Search unstructured customer documents including policy summary
          documents with coverage details, customer emails and complaints,
          call transcripts, and internal knowledge base articles about
          procedures, escalation rules, discount policies, and risk signals.

  tool_resources:
    Analyst1:
      semantic_view: CUSTOMER360_DB.ANALYTICS.SV_CUSTOMER_360
      execution_environment:
        type: warehouse
        warehouse: CUSTOMER360_WH
    Search1:
      search_service: CUSTOMER360_DB.ANALYTICS.SVC_CUSTOMER_DOCS
      max_results: 5
  $$;

-- Grant usage to roles
GRANT USAGE ON AGENT CUSTOMER360_DB.ANALYTICS.CUSTOMER360_AGENT
  TO ROLE C360_SERVICE_APP;

GRANT USAGE ON AGENT CUSTOMER360_DB.ANALYTICS.CUSTOMER360_AGENT
  TO ROLE ACCOUNTADMIN;
