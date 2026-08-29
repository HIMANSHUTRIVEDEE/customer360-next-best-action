-- =============================================================================
-- sql/04_ai/01_interactions_enriched.sql
-- Purpose: Enrich interactions with Cortex AI in a single efficient pass.
-- Role: C360_DATA_ENGINEER
-- Idempotent: CREATE TABLE IF NOT EXISTS + MERGE on interaction_id
--
-- Cortex strategy (two functions, one call each, per consented transcript):
--
--   1. SENTIMENT(text)  → sentiment_score  (classification, ~0.001 cr/call)
--      - Cheapest Cortex function. Returns float -1..+1.
--      - Immune to prompt injection (not generative).
--      - Used as the authoritative sentiment axis.
--
--   2. COMPLETE('mistral-7b', prompt)  → JSON with 4 fields  (~0.003 cr/call)
--      - Single call extracts: summary, intent, urgency, topic.
--      - mistral-7b is the cheapest generative model available.
--      - Transcripts are short (avg 51 words) → ~150 tokens in+out per call.
--      - Prompt uses strict JSON template + closed enum sets.
--      - Output post-validated; invalid values fall back to safe defaults.
--
-- Total cost for 49 consented transcripts:
--   49 × SENTIMENT  ≈ 0.05 credits
--   49 × COMPLETE   ≈ 0.15 credits
--   ─────────────────────────────
--   ~0.20 credits total (one-time; MERGE prevents re-enrichment)
--
-- SQL-derived columns (zero Cortex cost):
--   - sentiment_label   (from sentiment_score thresholds)
--   - is_complaint      (from disposition + intent + sentiment)
--   - is_escalation     (from intent + keyword matching)
--
-- =============================================================================

USE DATABASE CUSTOMER360_DB;
USE SCHEMA ANALYTICS;

-- =============================================================================
-- Step 1: Create the enrichment target table
-- Grain: One row per interaction.
--   - With transcript + consent    → enrichment_status = 'completed'
--   - With transcript, no consent  → enrichment_status = 'consent_withheld'
--   - No transcript                → enrichment_status = 'not_applicable'
-- =============================================================================
CREATE TABLE IF NOT EXISTS INTERACTIONS_ENRICHED (
    -- Interaction identity (from FACT_INTERACTION)
    interaction_id          VARCHAR(20)     NOT NULL    COMMENT 'PK — matches FACT_INTERACTION.interaction_id',
    customer_id             VARCHAR(20)     NOT NULL    COMMENT 'FK → DIM_CUSTOMER',
    channel                 VARCHAR(10)     NOT NULL    COMMENT 'phone, email, chat',
    direction               VARCHAR(20)     NOT NULL    COMMENT 'inbound, outbound, internal_note',
    disposition             VARCHAR(20)     NOT NULL    COMMENT 'inquiry, complaint, request, notification, general',
    interaction_date        TIMESTAMP_NTZ   NOT NULL    COMMENT 'When the interaction occurred',
    duration_seconds        NUMBER(10,0)                COMMENT 'Call duration (null for email/chat)',
    representative_id       VARCHAR(20)                 COMMENT 'FK → DIM_SERVICE_REPRESENTATIVE',

    -- Transcript metadata (null when no transcript exists)
    transcript_id           VARCHAR(20)                 COMMENT 'FK → TRANSCRIPT_CONTENT (null if no transcript)',
    content_type            VARCHAR(20)                 COMMENT 'call_transcript, email_body, agent_note',
    word_count              NUMBER(10,0)                COMMENT 'Transcript word count',

    -- Cortex SENTIMENT output (classification function — not generative)
    sentiment_score         FLOAT                       COMMENT 'Cortex SENTIMENT: -1.0 (negative) to +1.0 (positive)',
    sentiment_label         VARCHAR(10)                 COMMENT 'SQL-derived: negative (<-0.2), neutral, positive (>0.2)',

    -- Cortex COMPLETE output (single mistral-7b call → 4 fields)
    summary                 VARCHAR(500)                COMMENT 'LLM: one-sentence interaction summary (max ~20 words)',
    primary_topic           VARCHAR(30)                 COMMENT 'LLM: billing|claims|coverage|service|cancellation|general',
    primary_intent          VARCHAR(30)                 COMMENT 'LLM: complaint|inquiry|request|praise|escalation',
    urgency_level           VARCHAR(10)     NOT NULL    COMMENT 'LLM+SQL: critical|high|medium|low',
    llm_raw_response        VARCHAR(2000)               COMMENT 'Raw LLM JSON preserved for audit/debug',

    -- SQL-derived flags (zero Cortex cost — computed from above fields)
    is_complaint            BOOLEAN         NOT NULL    COMMENT 'TRUE if disposition=complaint OR intent=complaint OR sentiment<-0.5',
    is_escalation           BOOLEAN         NOT NULL    COMMENT 'TRUE if intent=escalation OR text contains escalation keywords',

    -- Enrichment provenance
    enrichment_status       VARCHAR(20)     NOT NULL    COMMENT 'completed|failed|not_applicable|consent_withheld',
    enrichment_model        VARCHAR(100)                COMMENT 'Models used for this row',
    enrichment_error        VARCHAR(500)                COMMENT 'Error detail if status=failed',

    -- Audit columns
    _source_table           VARCHAR(100)    DEFAULT 'ANALYTICS.FACT_INTERACTION+TRANSCRIPT_CONTENT',
    _source_event_id        VARCHAR(20)     NOT NULL    COMMENT 'Dedup key = interaction_id',
    _loaded_at              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    _processed_at           TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT pk_interactions_enriched PRIMARY KEY (interaction_id),
    CONSTRAINT uq_transcript UNIQUE (transcript_id)
)
COMMENT = 'Enriched interactions: SENTIMENT score + single COMPLETE call (summary/topic/intent/urgency) + SQL-derived flags. One row per interaction. MERGE-idempotent.';


-- =============================================================================
-- Step 2: Populate via MERGE (idempotent — skips already-enriched rows)
--
-- The CTE pipeline:
--   interaction_base  → join interactions to transcripts
--   cortex_pass       → call SENTIMENT + COMPLETE (one each, only for eligible rows)
--   validated_output  → parse JSON, validate enums, derive SQL columns
-- =============================================================================
MERGE INTO INTERACTIONS_ENRICHED tgt
USING (

    WITH interaction_base AS (
        SELECT
            fi.interaction_id,
            fi.customer_id,
            fi.channel,
            fi.direction,
            fi.disposition,
            fi.interaction_date,
            fi.duration_seconds,
            fi.representative_id,
            tc.transcript_id,
            tc.content_type,
            tc.raw_text,
            tc.word_count,
            tc.recording_consent_flag,
            -- Eligibility: determines whether Cortex functions are called
            CASE
                WHEN tc.transcript_id IS NULL            THEN 'not_applicable'
                WHEN tc.recording_consent_flag = 'FALSE' THEN 'consent_withheld'
                ELSE 'eligible'
            END AS _eligibility
        FROM FACT_INTERACTION fi
        LEFT JOIN TRANSCRIPT_CONTENT tc
            ON fi.interaction_id = tc.interaction_id
    ),

    -- =================================================================
    -- Cortex pass: exactly 2 function calls per eligible transcript.
    -- SENTIMENT: classification (cheap, deterministic, injection-proof)
    -- COMPLETE:  single JSON extraction (summary + topic + intent + urgency)
    -- =================================================================
    cortex_pass AS (
        SELECT
            ib.*,

            -- Call 1: SENTIMENT (classification — ~0.001 credits)
            CASE WHEN ib._eligibility = 'eligible'
                 THEN SNOWFLAKE.CORTEX.SENTIMENT(ib.raw_text)
            END AS _sentiment_raw,

            -- Call 2: COMPLETE (mistral-7b — ~0.003 credits)
            -- Single prompt extracts all 4 fields. Strict JSON template
            -- with closed enum sets minimizes hallucination and token count.
            CASE WHEN ib._eligibility = 'eligible'
                 THEN SNOWFLAKE.CORTEX.COMPLETE(
                     'mistral-7b',
                     'You are a concise insurance call center analyst. '
                     || 'Analyze this customer interaction and return ONLY a JSON object. '
                     || 'No other text before or after the JSON.\n\n'
                     || '{"summary":"<one sentence, max 20 words, describing the customer issue>",'
                     || '"intent":"<one of: complaint|inquiry|request|praise|escalation>",'
                     || '"urgency":"<one of: critical|high|medium|low>",'
                     || '"topic":"<one of: billing|claims|coverage|service|cancellation|general>"}\n\n'
                     || 'Rules:\n'
                     || '- summary must be a single sentence under 20 words\n'
                     || '- intent, urgency, and topic must be exactly one of the listed values\n'
                     || '- critical urgency = immediate risk of cancellation or regulatory complaint\n'
                     || '- high urgency = unresolved issue with expressed frustration\n'
                     || '- medium urgency = routine request needing timely response\n'
                     || '- low urgency = informational or positive interaction\n\n'
                     || 'Text: "' || REPLACE(LEFT(ib.raw_text, 1000), '"', '''') || '"\n\nJSON:'
                 )
            END AS _llm_raw

        FROM interaction_base ib
    ),

    -- =================================================================
    -- Validation pass: parse LLM JSON, enforce enums, derive SQL columns.
    -- Every field gets a TRY_PARSE_JSON + membership check + safe default.
    -- =================================================================
    validated_output AS (
        SELECT
            cp.interaction_id,
            cp.customer_id,
            cp.channel,
            cp.direction,
            cp.disposition,
            cp.interaction_date,
            cp.duration_seconds,
            cp.representative_id,
            cp.transcript_id,
            cp.content_type,
            cp.word_count,
            cp._eligibility,
            cp._sentiment_raw,
            cp._llm_raw,

            -- Parse the LLM JSON once (reused below)
            TRY_PARSE_JSON(TRIM(cp._llm_raw)) AS _llm_json,

            -- ── Sentiment score: validate range ──
            CASE
                WHEN cp._sentiment_raw BETWEEN -1.0 AND 1.0
                THEN ROUND(cp._sentiment_raw, 4)
            END AS sentiment_score,

            -- ── Sentiment label: SQL-derived from score thresholds ──
            CASE
                WHEN cp._sentiment_raw IS NULL     THEN NULL
                WHEN cp._sentiment_raw < -0.2      THEN 'negative'
                WHEN cp._sentiment_raw >  0.2      THEN 'positive'
                ELSE                                     'neutral'
            END AS sentiment_label,

            -- ── Summary: take as-is, truncate to 500 chars ──
            CASE
                WHEN cp._llm_raw IS NOT NULL
                THEN LEFT(TRY_PARSE_JSON(TRIM(cp._llm_raw)):summary::VARCHAR, 500)
            END AS summary,

            -- ── Topic: validate against closed enum ──
            CASE
                WHEN cp._llm_raw IS NOT NULL
                THEN CASE
                    WHEN LOWER(COALESCE(TRY_PARSE_JSON(TRIM(cp._llm_raw)):topic::VARCHAR, ''))
                         IN ('billing', 'claims', 'coverage', 'service', 'cancellation', 'general')
                    THEN LOWER(TRY_PARSE_JSON(TRIM(cp._llm_raw)):topic::VARCHAR)
                    ELSE 'general'
                END
            END AS primary_topic,

            -- ── Intent: validate against closed enum ──
            CASE
                WHEN cp._llm_raw IS NOT NULL
                THEN CASE
                    WHEN LOWER(COALESCE(TRY_PARSE_JSON(TRIM(cp._llm_raw)):intent::VARCHAR, ''))
                         IN ('complaint', 'inquiry', 'request', 'praise', 'escalation')
                    THEN LOWER(TRY_PARSE_JSON(TRIM(cp._llm_raw)):intent::VARCHAR)
                    ELSE 'inquiry'
                END
            END AS primary_intent,

            -- ── Urgency: LLM value with SQL override for critical cases ──
            -- LLM classifies urgency from text context. SQL overrides to
            -- 'critical' when both structural signals agree (complaint +
            -- strong negative sentiment), even if LLM said 'high'.
            CASE
                -- Override: structural signals confirm critical urgency
                WHEN cp._eligibility = 'eligible'
                     AND cp._sentiment_raw IS NOT NULL AND cp._sentiment_raw < -0.5
                     AND (cp.disposition = 'complaint'
                          OR LOWER(COALESCE(TRY_PARSE_JSON(TRIM(cp._llm_raw)):intent::VARCHAR, '')) = 'escalation')
                THEN 'critical'
                -- LLM urgency when valid
                WHEN cp._llm_raw IS NOT NULL
                     AND LOWER(COALESCE(TRY_PARSE_JSON(TRIM(cp._llm_raw)):urgency::VARCHAR, ''))
                         IN ('critical', 'high', 'medium', 'low')
                THEN LOWER(TRY_PARSE_JSON(TRIM(cp._llm_raw)):urgency::VARCHAR)
                -- SQL fallback for non-enriched or parse failure
                WHEN cp._sentiment_raw IS NOT NULL AND cp._sentiment_raw < -0.2 THEN 'high'
                WHEN cp.disposition = 'complaint'                                THEN 'high'
                WHEN cp._sentiment_raw IS NOT NULL AND cp._sentiment_raw BETWEEN -0.2 AND 0.2 THEN 'medium'
                ELSE 'low'
            END AS urgency_level,

            -- ── SQL-derived complaint flag (zero Cortex cost) ──
            CASE
                WHEN cp.disposition = 'complaint' THEN TRUE
                WHEN LOWER(COALESCE(TRY_PARSE_JSON(TRIM(cp._llm_raw)):intent::VARCHAR, '')) = 'complaint' THEN TRUE
                WHEN cp._sentiment_raw IS NOT NULL AND cp._sentiment_raw < -0.5 THEN TRUE
                ELSE FALSE
            END AS is_complaint,

            -- ── SQL-derived escalation flag (zero Cortex cost) ──
            CASE
                WHEN LOWER(COALESCE(TRY_PARSE_JSON(TRIM(cp._llm_raw)):intent::VARCHAR, '')) = 'escalation' THEN TRUE
                WHEN cp.raw_text IS NOT NULL AND (
                    LOWER(cp.raw_text) LIKE '%escalat%'
                    OR LOWER(cp.raw_text) LIKE '%speak to a manager%'
                    OR LOWER(cp.raw_text) LIKE '%speak to a supervisor%'
                    OR LOWER(cp.raw_text) LIKE '%cancel%my%policy%'
                    OR LOWER(cp.raw_text) LIKE '%switch%provider%'
                    OR LOWER(cp.raw_text) LIKE '%consider other options%'
                    OR LOWER(cp.raw_text) LIKE '%have to consider%'
                ) THEN TRUE
                ELSE FALSE
            END AS is_escalation,

            -- ── Enrichment status ──
            CASE
                WHEN cp._eligibility != 'eligible'
                THEN cp._eligibility
                WHEN cp._sentiment_raw IS NOT NULL
                     AND cp._sentiment_raw BETWEEN -1.0 AND 1.0
                     AND cp._llm_raw IS NOT NULL
                     AND TRY_PARSE_JSON(TRIM(cp._llm_raw)) IS NOT NULL
                THEN 'completed'
                ELSE 'failed'
            END AS enrichment_status,

            -- ── Provenance ──
            CASE
                WHEN cp._eligibility = 'eligible'
                THEN 'snowflake.cortex.sentiment + snowflake.cortex.complete(mistral-7b)'
            END AS enrichment_model,

            -- ── Error detail ──
            CASE
                WHEN cp._eligibility = 'eligible' AND (
                    cp._sentiment_raw IS NULL
                    OR cp._sentiment_raw NOT BETWEEN -1.0 AND 1.0
                ) THEN 'SENTIMENT returned invalid: ' || COALESCE(cp._sentiment_raw::VARCHAR, 'NULL')
                WHEN cp._eligibility = 'eligible'
                     AND cp._llm_raw IS NOT NULL
                     AND TRY_PARSE_JSON(TRIM(cp._llm_raw)) IS NULL
                THEN 'COMPLETE returned non-JSON: ' || LEFT(cp._llm_raw, 200)
                WHEN cp._eligibility = 'eligible'
                     AND cp._llm_raw IS NULL
                THEN 'COMPLETE returned NULL'
            END AS enrichment_error

        FROM cortex_pass cp
    )

    SELECT * FROM validated_output

) src
ON tgt.interaction_id = src.interaction_id

-- Only insert rows that don't already exist (idempotent)
WHEN NOT MATCHED THEN INSERT (
    interaction_id, customer_id, channel, direction, disposition,
    interaction_date, duration_seconds, representative_id,
    transcript_id, content_type, word_count,
    sentiment_score, sentiment_label,
    summary, primary_topic, primary_intent, urgency_level, llm_raw_response,
    is_complaint, is_escalation,
    enrichment_status, enrichment_model, enrichment_error,
    _source_event_id
)
VALUES (
    src.interaction_id, src.customer_id, src.channel, src.direction, src.disposition,
    src.interaction_date, src.duration_seconds, src.representative_id,
    src.transcript_id, src.content_type, src.word_count,
    src.sentiment_score, src.sentiment_label,
    src.summary, src.primary_topic, src.primary_intent, src.urgency_level, LEFT(src._llm_raw, 2000),
    src.is_complaint, src.is_escalation,
    src.enrichment_status, src.enrichment_model, src.enrichment_error,
    src.interaction_id
);


-- =============================================================================
-- Step 3: Verification
-- =============================================================================

-- Enrichment status distribution
SELECT enrichment_status, COUNT(*) AS cnt
FROM INTERACTIONS_ENRICHED
GROUP BY 1 ORDER BY 1;

-- Sentiment distribution
SELECT sentiment_label, COUNT(*) AS cnt,
       ROUND(AVG(sentiment_score), 3) AS avg_score,
       ROUND(MIN(sentiment_score), 3) AS min_score,
       ROUND(MAX(sentiment_score), 3) AS max_score
FROM INTERACTIONS_ENRICHED
WHERE enrichment_status = 'completed'
GROUP BY 1 ORDER BY avg_score;

-- Topic × intent matrix
SELECT primary_topic, primary_intent, COUNT(*) AS cnt
FROM INTERACTIONS_ENRICHED
WHERE enrichment_status = 'completed'
GROUP BY 1, 2 ORDER BY cnt DESC;

-- Urgency distribution
SELECT urgency_level, COUNT(*) AS cnt
FROM INTERACTIONS_ENRICHED
WHERE enrichment_status = 'completed'
GROUP BY 1 ORDER BY
    CASE urgency_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END;

-- Sample summaries (spot-check LLM output quality)
SELECT interaction_id, sentiment_label, urgency_level, primary_intent, summary
FROM INTERACTIONS_ENRICHED
WHERE enrichment_status = 'completed'
ORDER BY sentiment_score ASC
LIMIT 10;

-- Golden demo: Maria Chen (CUST-001)
SELECT interaction_id, interaction_date, disposition,
       sentiment_score, sentiment_label,
       summary, primary_topic, primary_intent, urgency_level,
       is_complaint, is_escalation, enrichment_status
FROM INTERACTIONS_ENRICHED
WHERE customer_id = 'CUST-001'
ORDER BY interaction_date DESC;
