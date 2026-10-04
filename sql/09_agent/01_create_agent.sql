-- =============================================================================
-- sql/09_agent/01_create_agent.sql
-- Purpose: Create the Customer 360 conversational agent.
--          Uses the SV_CUSTOMER_360 semantic view for structured queries.
--          Includes placeholder for Cortex Search (RAG / unstructured).
-- Role: C360_DATA_ENGINEER
-- Idempotent: CREATE OR REPLACE AGENT
-- =============================================================================

USE ROLE C360_DATA_ENGINEER;
USE DATABASE CUSTOMER360_DB;
USE SCHEMA ANALYTICS;
USE WAREHOUSE CUSTOMER360_WH;

CREATE OR REPLACE AGENT CUSTOMER360_AGENT
  COMMENT = 'Conversational agent for Customer 360 Next Best Action. Answers questions about customers, policies, risk, claims, and recommendations.'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  instructions:
    response: |
      You are an AI assistant for insurance service representatives using
      the Customer 360 Next Best Action platform.
      Answer questions about customer profiles, policies, claims, payments,
      interactions, risk signals, and NBA recommendations.
      Always reference specific customer IDs (e.g. CUST-001) when discussing
      individual customers.
      Be concise and actionable. Service reps need quick, accurate answers.
      When presenting risk or recommendation data, include confidence scores
      and evidence where available.
      If a question cannot be answered from the available data, say so clearly.
      Do not fabricate data or make assumptions beyond what the data shows.
    orchestration: |
      Use the Analyst tool for all structured data questions about customers,
      policies, claims, payments, risk signals, and recommendations.
    sample_questions:
      - question: "How many high-risk customers do we have?"
      - question: "What is the risk profile for CUST-001?"
      - question: "Which customers are renewing in the next 30 days?"

  tools:
    # Structured data: Semantic View over CUSTOMER_360_ENRICHED
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: Analyst1
        description: >
          Query structured customer 360 data including profiles, policies,
          claims, payments, interactions, risk signals, and NBA recommendations.

    # Unstructured / RAG: Cortex Search Service (placeholder)
    # Uncomment and configure when the search service is created:
    #
    # - tool_spec:
    #     type: cortex_search
    #     name: Search1
    #     description: >
    #       Search unstructured customer documents, transcripts,
    #       and interaction notes.

  tool_resources:
    Analyst1:
      semantic_view: CUSTOMER360_DB.ANALYTICS.SV_CUSTOMER_360
      execution_environment:
        type: warehouse
        warehouse: CUSTOMER360_WH

    # Uncomment when Cortex Search Service is ready:
    # Search1:
    #   search_service: CUSTOMER360_DB.ANALYTICS.<YOUR_SEARCH_SERVICE_NAME>
    #   max_results: 5
  $$;

-- Grant usage to the service app role so the Streamlit app can invoke the agent
GRANT USAGE ON AGENT CUSTOMER360_DB.ANALYTICS.CUSTOMER360_AGENT
  TO ROLE C360_SERVICE_APP;
