/*==============================================================================
  CUSTOMER360 — CURATED LAYER: TRANSCRIPT CONTENT
  Schema: CUSTOMER360_DB.ANALYTICS
  Pattern: Type 1, MERGE for rerun safety
  Dependencies: CUSTOMER360_DB.RAW.RAW_TRANSCRIPTS, FACT_INTERACTION
  Note: Raw transcript text is kept separate from interaction metadata.
        No enrichment, sentiment, risk, or recommendation columns.
==============================================================================*/

USE ROLE C360_DATA_ENGINEER;
USE SCHEMA CUSTOMER360_DB.ANALYTICS;

/*------------------------------------------------------------------------------
  TRANSCRIPT_CONTENT
  Grain: One row per unique transcript_id from RAW_TRANSCRIPTS.
  Each transcript links 1:1 to an interaction via interaction_id.
  Interactions without transcripts are NOT represented here (they remain
  in FACT_INTERACTION with no join match). This table stores the raw text
  without any AI enrichment.
------------------------------------------------------------------------------*/
CREATE TABLE IF NOT EXISTS CUSTOMER360_DB.ANALYTICS.TRANSCRIPT_CONTENT (
    transcript_sk            NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    transcript_id            VARCHAR(20)        NOT NULL,   -- Source business key
    interaction_id           VARCHAR(20)        NOT NULL,   -- FK to FACT_INTERACTION (business key)
    content_type             VARCHAR(20)        NOT NULL,   -- call_transcript, email_body, agent_note
    raw_text                 VARCHAR(16777216)  NOT NULL,   -- Verbatim content
    word_count               NUMBER(10,0)       NOT NULL,
    recording_consent_flag   VARCHAR(5)         NOT NULL,   -- TRUE or FALSE
    _source_table            VARCHAR(100)       DEFAULT 'RAW.RAW_TRANSCRIPTS',
    _source_hash             VARCHAR(64),
    _batch_id                VARCHAR(100),
    _loaded_at               TIMESTAMP_NTZ      DEFAULT CURRENT_TIMESTAMP(),
    _processed_at            TIMESTAMP_NTZ      DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_transcript_content PRIMARY KEY (transcript_sk),
    CONSTRAINT ak_transcript_content UNIQUE (transcript_id)
);

MERGE INTO CUSTOMER360_DB.ANALYTICS.TRANSCRIPT_CONTENT AS tgt
USING (
    SELECT
        transcript_id,
        interaction_id,
        content_type,
        raw_text,
        word_count,
        recording_consent_flag,
        _row_hash  AS _source_hash,
        _batch_id
    FROM CUSTOMER360_DB.RAW.RAW_TRANSCRIPTS
) AS src
ON tgt.transcript_id = src.transcript_id
WHEN MATCHED THEN UPDATE SET
    tgt.interaction_id         = src.interaction_id,
    tgt.content_type           = src.content_type,
    tgt.raw_text               = src.raw_text,
    tgt.word_count             = src.word_count,
    tgt.recording_consent_flag = src.recording_consent_flag,
    tgt._source_hash           = src._source_hash,
    tgt._batch_id              = src._batch_id,
    tgt._processed_at          = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    transcript_id, interaction_id, content_type,
    raw_text, word_count, recording_consent_flag,
    _source_table, _source_hash, _batch_id, _loaded_at, _processed_at
) VALUES (
    src.transcript_id, src.interaction_id, src.content_type,
    src.raw_text, src.word_count, src.recording_consent_flag,
    'RAW.RAW_TRANSCRIPTS', src._source_hash, src._batch_id,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
);
