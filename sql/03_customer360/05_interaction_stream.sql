/*==============================================================================
  CUSTOMER360 — INTERACTION STREAM
  Schema: CUSTOMER360_DB.ANALYTICS
  Pattern: Append-only stream on FACT_INTERACTION

  Purpose:
    Captures new inserts into FACT_INTERACTION to drive downstream processes:
      1. Transcript enrichment — trigger AI sentiment/topic extraction when
         new interactions arrive that have associated transcripts.
      2. NBA refresh — feed the Next Best Action engine with recent interaction
         signals (complaints, channel shifts, escalation patterns).

  Append-only mode is chosen because:
    - FACT_INTERACTION uses MERGE with INSERT + UPDATE, but downstream
      consumers only need to process NEW rows (not re-process updates).
    - Append-only streams are cheaper and avoid duplicate processing of
      unchanged rows on UPDATE-only matches.

  Consumption:
    - A downstream task or dynamic table should SELECT from this stream
      and advance the offset on commit.
    - If the stream is not consumed before its staleness window, it will
      become stale. Set DATA_RETENTION_TIME_IN_DAYS on FACT_INTERACTION
      accordingly (default 1 day; recommend >= 3 for safety).

  Dependencies:
    - CUSTOMER360_DB.ANALYTICS.FACT_INTERACTION (must exist)
==============================================================================*/

USE ROLE C360_DATA_ENGINEER;
USE SCHEMA CUSTOMER360_DB.ANALYTICS;

CREATE OR REPLACE STREAM CUSTOMER360_DB.ANALYTICS.INTERACTION_STREAM
    ON TABLE CUSTOMER360_DB.ANALYTICS.FACT_INTERACTION
    APPEND_ONLY = TRUE
    SHOW_INITIAL_ROWS = FALSE
    COMMENT = 'Append-only stream on FACT_INTERACTION. Drives transcript enrichment and NBA refresh pipelines.';
