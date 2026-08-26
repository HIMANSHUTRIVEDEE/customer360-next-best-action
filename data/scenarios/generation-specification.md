# Generation Specification — Synthetic Source Datasets

This document specifies the exact structure, rules, and validation criteria for each synthetic source dataset produced by the generator script. These datasets land in `data/generated/` as CSV files and are loaded into RAW schema tables via COPY INTO.

**Scope:** Source data only. Enrichments, risk signals, recommendations, follow-ups, and outcomes are not source datasets — they are produced by downstream pipeline stages or application logic.

**Household note:** Per the approved source-to-target design (data-model.md §12), household attributes are embedded in the customers dataset. A separate RAW_HOUSEHOLDS table is extracted during the curated-layer build (Day 3+).

---

## 1. customers

### Grain

One row per individual customer. Household membership is an attribute of the customer record.

### Primary Identifier

| Column | Format | Example |
|--------|--------|---------|
| `customer_id` | `CUST-NNN` (zero-padded 3 digits for scenarios; 4 digits for background) | `CUST-001`, `CUST-0042` |

### Foreign-Key Relationships

| FK Column | References | Constraint |
|-----------|-----------|-----------|
| (none outbound) | — | Customers are the root entity |

### Required Columns

| Column | Type | Description |
|--------|------|-------------|
| customer_id | STRING | Primary identifier |
| household_id | STRING | Household grouping key (format: `HH-NNN`) |
| first_name | STRING | Given name |
| last_name | STRING | Family name |
| customer_since | DATE | Relationship start (YYYY-MM-DD) |
| status | STRING | Lifecycle state |
| address_line_1 | STRING | Household primary address (embedded) |
| city | STRING | Household city |
| state | STRING | US state code (2 chars) |
| postal_code | STRING | 5-digit or 5+4 format |

### Nullable Columns

| Column | Type | Null Condition |
|--------|------|---------------|
| date_of_birth | DATE | Optional; null for ~20% of background customers |
| email | STRING | Null for ~5% of background customers |
| phone | STRING | Null for ~5% of background customers |

### Allowed Enumeration Values

| Column | Allowed Values |
|--------|---------------|
| status | `active`, `inactive`, `prospect` |

### Date and Timestamp Rules

| Column | Rule |
|--------|------|
| customer_since | Between 1 and 15 years before generation date. Scenario customers use specified durations. |
| date_of_birth | Between 18 and 80 years before generation date (adults only). |

### Cardinality Assumptions

| Assumption | Value | Label |
|-----------|-------|-------|
| Customers per household | 1–2 (synthetic prototype assumption) | Most households have 1; SCN-011 has 2 |
| Active vs. inactive | ~95% active, ~5% inactive (synthetic prototype assumption) | |

### Scenario Dependencies

| Scenario | Customer Requirement |
|----------|---------------------|
| SCN-001 | customer_id=CUST-001, name=Maria Chen, household_id=HH-001, status=active, customer_since ≥ 3 years |
| SCN-002 | customer_id=CUST-002, name=James Rodriguez, status=active, customer_since ≥ 2 years |
| SCN-011 | customer_id=CUST-011 + CUST-011B, same household_id=HH-011 |
| All scenarios | customer_id and household_id values per scenario-catalog.md |

### Synthetic Row-Count Target

| Target | Value |
|--------|-------|
| Scenario customers | 13 (12 scenarios; SCN-011 has 2 customers) |
| Background customers | ~87 |
| **Total** | **~100** |

### Validation Rules

| # | Rule | Severity |
|---|------|----------|
| V1 | customer_id is unique | Hard |
| V2 | household_id is not null | Hard |
| V3 | status is in allowed enum | Hard |
| V4 | customer_since ≤ generation date | Hard |
| V5 | All scenario customers exist with specified attributes | Hard |
| V6 | email uses @example.com domain (synthetic) | Hard |
| V7 | phone uses 555-XXXX pattern (synthetic) | Hard |

---

## 2. policies

### Grain

One row per policy term. A renewed policy creates a new row; the prior term transitions to status = 'renewed'.

### Primary Identifier

| Column | Format | Example |
|--------|--------|---------|
| `policy_id` | `POL-NNNNNN` (6 digits) | `POL-000101` |

### Foreign-Key Relationships

| FK Column | References | Constraint |
|-----------|-----------|-----------|
| customer_id | customers.customer_id | Must exist in customers dataset |

### Required Columns

| Column | Type | Description |
|--------|------|-------------|
| policy_id | STRING | Primary identifier |
| customer_id | STRING | FK → customers |
| product_type | STRING | Line of business |
| status | STRING | Lifecycle state |
| effective_date | DATE | Coverage start |
| expiration_date | DATE | Coverage end / renewal trigger date |
| premium_amount | NUMBER(12,2) | Annual premium |
| payment_frequency | STRING | Billing cadence |

### Nullable Columns

| Column | Type | Null Condition |
|--------|------|---------------|
| bound_date | DATE | Null if status = 'quoted' |

### Allowed Enumeration Values

| Column | Allowed Values |
|--------|---------------|
| product_type | `auto`, `home`, `umbrella`, `renters` |
| status | `quoted`, `bound`, `active`, `renewed`, `lapsed`, `cancelled` |
| payment_frequency | `monthly`, `quarterly`, `semi_annual`, `annual` |

### Date and Timestamp Rules

| Column | Rule |
|--------|------|
| effective_date | Must be ≤ generation date for active/renewed/lapsed/cancelled policies |
| expiration_date | Must be > effective_date. For active policies: ranges from near-future to 12 months out |
| bound_date | Must be ≤ effective_date when present |

### Cardinality Assumptions

| Assumption | Value | Label |
|-----------|-------|-------|
| Policies per customer | 1–4 (synthetic prototype assumption) | |
| Active policies per customer | 1–3 | Most common: 1–2 |
| Product mix | ~40% auto, ~35% home, ~15% renters, ~10% umbrella (synthetic prototype assumption) | |

### Scenario Dependencies

| Scenario | Policy Requirement |
|----------|-------------------|
| SCN-001 | 2 active (auto expiry 14–18 days, home expiry 6+ months) |
| SCN-002 | 1 active auto (expiry 20–25 days) |
| SCN-003 | 2 active (auto expiry 10–15 days, home active) |
| SCN-008 | 1 active auto (expiry 45 days, payment_frequency=monthly) |
| SCN-010 | 1 active renters (expiry 60 days) |
| SCN-011 | CUST-011: 3 active (auto+home+umbrella); CUST-011B: 1 active auto |

### Synthetic Row-Count Target

| Target | Value |
|--------|-------|
| Scenario policies | ~25 |
| Background policies | ~225 |
| **Total** | **~250** (solution-design target: ~500 including historical) |

### Validation Rules

| # | Rule | Severity |
|---|------|----------|
| V1 | policy_id is unique | Hard |
| V2 | customer_id exists in customers | Hard |
| V3 | product_type is in allowed enum | Hard |
| V4 | status is in allowed enum | Hard |
| V5 | effective_date < expiration_date | Hard |
| V6 | premium_amount > 0 | Hard |
| V7 | payment_frequency is in allowed enum | Hard |
| V8 | Scenario policies match specified expiration windows | Hard |

---

## 3. coverages

### Grain

One row per coverage component per policy.

### Primary Identifier

| Column | Format | Example |
|--------|--------|---------|
| `coverage_id` | `COV-NNNNNN` (6 digits, sequential) | `COV-000001` |

### Foreign-Key Relationships

| FK Column | References | Constraint |
|-----------|-----------|-----------|
| policy_id | policies.policy_id | Must exist in policies dataset |

### Required Columns

| Column | Type | Description |
|--------|------|-------------|
| coverage_id | STRING | Primary identifier (surrogate) |
| policy_id | STRING | FK → policies |
| coverage_type | STRING | Coverage category |
| limit_amount | NUMBER(12,2) | Maximum payout |
| deductible_amount | NUMBER(12,2) | Customer responsibility |

### Nullable Columns

None. All columns required.

### Allowed Enumeration Values

| Column | Allowed Values |
|--------|---------------|
| coverage_type | `liability`, `collision`, `comprehensive`, `dwelling`, `personal_property`, `medical_payments`, `uninsured_motorist`, `umbrella_excess` |

### Date and Timestamp Rules

None (no date columns).

### Cardinality Assumptions

| Assumption | Value | Label |
|-----------|-------|-------|
| Coverages per auto policy | 3–5 (liability, collision, comprehensive, uninsured, medical) | Synthetic prototype assumption |
| Coverages per home policy | 2–4 (dwelling, personal_property, liability, medical) | |
| Coverages per umbrella policy | 1 (umbrella_excess) | |
| Coverages per renters policy | 2–3 (personal_property, liability, medical) | |

### Scenario Dependencies

No scenario-specific coverage requirements beyond having valid coverages for each policy.

### Synthetic Row-Count Target

| Target | Value |
|--------|-------|
| **Total** | **~500–750** (2–3 per policy average × ~250 policies) |

### Validation Rules

| # | Rule | Severity |
|---|------|----------|
| V1 | coverage_id is unique | Hard |
| V2 | policy_id exists in policies | Hard |
| V3 | coverage_type is in allowed enum | Hard |
| V4 | limit_amount > 0 | Hard |
| V5 | deductible_amount ≥ 0 | Hard |
| V6 | At least 1 coverage per active policy | Hard |

---

## 4. claims

### Grain

One row per claim event.

### Primary Identifier

| Column | Format | Example |
|--------|--------|---------|
| `claim_id` | `CLM-NNNNNN` (6 digits) | `CLM-000001` |

### Foreign-Key Relationships

| FK Column | References | Constraint |
|-----------|-----------|-----------|
| policy_id | policies.policy_id | Must exist in policies dataset |
| customer_id | customers.customer_id | Must exist in customers dataset (denormalized) |

### Required Columns

| Column | Type | Description |
|--------|------|-------------|
| claim_id | STRING | Primary identifier |
| policy_id | STRING | FK → policies |
| customer_id | STRING | FK → customers (denormalized) |
| filed_date | DATE | Submission date |
| status | STRING | Lifecycle state |
| loss_date | DATE | When loss occurred |
| loss_type | STRING | Category of loss |

### Nullable Columns

| Column | Type | Null Condition |
|--------|------|---------------|
| reserve_amount | NUMBER(12,2) | Null if status = 'filed' (not yet assessed) |
| paid_amount | NUMBER(12,2) | Null if not settled |
| closed_date | DATE | Null if status ∈ ('filed', 'under_review') |

### Allowed Enumeration Values

| Column | Allowed Values |
|--------|---------------|
| status | `filed`, `under_review`, `settled`, `denied`, `withdrawn` |
| loss_type | `collision`, `water_damage`, `theft`, `liability`, `wind_damage`, `fire`, `vandalism` |

### Date and Timestamp Rules

| Column | Rule |
|--------|------|
| loss_date | Must be ≤ filed_date |
| filed_date | Must be ≤ generation date |
| closed_date | Must be > filed_date when present |

### Cardinality Assumptions

| Assumption | Value | Label |
|-----------|-------|-------|
| Claims per customer (lifetime) | 0–2 (synthetic prototype assumption) | ~70% have 0, ~25% have 1, ~5% have 2 |
| Open claims | ~10% of all claims (status ∈ filed, under_review) | |

### Scenario Dependencies

| Scenario | Claim Requirement |
|----------|-------------------|
| SCN-001 | 1 settled claim on auto, 6+ months old |
| SCN-002 | 1 open claim (under_review), filed 30 days ago |
| SCN-003, 005, 006, 007, 008, 009, 010 | No claims |

### Synthetic Row-Count Target

| Target | Value |
|--------|-------|
| **Total** | **~30** |

### Validation Rules

| # | Rule | Severity |
|---|------|----------|
| V1 | claim_id is unique | Hard |
| V2 | policy_id exists in policies | Hard |
| V3 | customer_id exists in customers | Hard |
| V4 | customer_id matches the customer who owns policy_id | Hard |
| V5 | status is in allowed enum | Hard |
| V6 | loss_type is in allowed enum | Hard |
| V7 | loss_date ≤ filed_date | Hard |
| V8 | closed_date > filed_date when not null | Hard |
| V9 | reserve_amount > 0 when not null | Hard |
| V10 | paid_amount ≥ 0 when not null | Hard |

---

## 5. payments

### Grain

One row per payment obligation (one per billing cycle per policy).

### Primary Identifier

| Column | Format | Example |
|--------|--------|---------|
| `payment_id` | `PAY-NNNNNNNN` (8 digits, sequential) | `PAY-00000001` |

### Foreign-Key Relationships

| FK Column | References | Constraint |
|-----------|-----------|-----------|
| customer_id | customers.customer_id | Must exist |
| policy_id | policies.policy_id | Must exist |

### Required Columns

| Column | Type | Description |
|--------|------|-------------|
| payment_id | STRING | Primary identifier (surrogate) |
| customer_id | STRING | FK → customers |
| policy_id | STRING | FK → policies |
| due_date | DATE | When payment is due |
| amount | NUMBER(12,2) | Amount owed |
| status | STRING | Payment outcome |

### Nullable Columns

| Column | Type | Null Condition |
|--------|------|---------------|
| paid_date | DATE | Null if status = 'missed' or 'pending' |
| amount_paid | NUMBER(12,2) | Null if not yet paid |

### Allowed Enumeration Values

| Column | Allowed Values |
|--------|---------------|
| status | `on_time`, `late`, `grace_period`, `missed`, `pending` |

### Date and Timestamp Rules

| Column | Rule |
|--------|------|
| due_date | Generated at payment_frequency intervals from policy effective_date |
| paid_date | When present: within 0–30 days of due_date. On-time: ≤ due_date. Late: due_date < paid_date ≤ due_date + 30. Grace: due_date < paid_date ≤ due_date + 15 (product-specific). |

### Cardinality Assumptions

| Assumption | Value | Label |
|-----------|-------|-------|
| Payment rows per monthly policy | 6 (last 6 months of history) | Synthetic prototype assumption |
| Payment rows per quarterly policy | 2–3 | |
| Payment rows per annual policy | 1 | |
| Late payment rate (background) | ~8% of all payments (synthetic prototype assumption) | |

### Scenario Dependencies

| Scenario | Payment Requirement |
|----------|---------------------|
| SCN-001 | All on_time for both policies |
| SCN-002 | Mostly on_time; 1 late payment 4 months ago |
| SCN-008 | 3 late in last 6 months + 1 grace_period (current) |
| SCN-012 | 2 late in last 6 months |
| All others | All on_time unless specified |

### Synthetic Row-Count Target

| Target | Value |
|--------|-------|
| **Total** | **~600** |

### Validation Rules

| # | Rule | Severity |
|---|------|----------|
| V1 | payment_id is unique | Hard |
| V2 | customer_id exists in customers | Hard |
| V3 | policy_id exists in policies | Hard |
| V4 | amount > 0 | Hard |
| V5 | status is in allowed enum | Hard |
| V6 | paid_date ≥ due_date when status = 'late' | Hard |
| V7 | paid_date ≤ due_date when status = 'on_time' | Hard |
| V8 | paid_date is null when status = 'missed' or 'pending' | Hard |
| V9 | amount_paid is null when paid_date is null | Hard |
| V10 | Scenario payments match specified patterns | Hard |

---

## 6. interactions

### Grain

One row per contact event between customer and carrier.

### Primary Identifier

| Column | Format | Example |
|--------|--------|---------|
| `interaction_id` | `INT-NNNNNN` (6 digits, sequential) | `INT-000001` |

### Foreign-Key Relationships

| FK Column | References | Constraint |
|-----------|-----------|-----------|
| customer_id | customers.customer_id | Must exist |
| representative_id | service_representatives.representative_id | Must exist when not null |

### Required Columns

| Column | Type | Description |
|--------|------|-------------|
| interaction_id | STRING | Primary identifier (surrogate, dedup key) |
| customer_id | STRING | FK → customers |
| channel | STRING | Communication medium |
| direction | STRING | Who initiated |
| disposition | STRING | Interaction type |
| interaction_date | TIMESTAMP | When occurred (ISO 8601: YYYY-MM-DDTHH:MM:SS) |

### Nullable Columns

| Column | Type | Null Condition |
|--------|------|---------------|
| duration_seconds | INTEGER | Null for email and chat (only populated for phone) |
| representative_id | STRING | Null for automated interactions (~5%) |

### Allowed Enumeration Values

| Column | Allowed Values |
|--------|---------------|
| channel | `phone`, `email`, `chat` |
| direction | `inbound`, `outbound`, `internal_note` |
| disposition | `inquiry`, `complaint`, `request`, `notification`, `general` |

### Date and Timestamp Rules

| Column | Rule |
|--------|------|
| interaction_date | Within last 12 months for background; scenario-specific dates per catalog. Timestamps include time component (business hours: 08:00–18:00 local). |

### Cardinality Assumptions

| Assumption | Value | Label |
|-----------|-------|-------|
| Interactions per customer per year | 1–6 (synthetic prototype assumption) | |
| Channel mix | ~50% phone, ~35% email, ~15% chat (synthetic prototype assumption) | |
| Direction mix | ~80% inbound, ~15% outbound, ~5% internal_note | |
| Phone duration | 120–900 seconds (synthetic prototype assumption) | |

### Scenario Dependencies

| Scenario | Interaction Requirement |
|----------|-------------------------|
| SCN-001 | 4 interactions (2 recent negative, 2 older positive) with specific dates and dispositions |
| SCN-002 | 3 interactions in 90 days (2 negative, 1 neutral) |
| SCN-005 | 0 interactions in 90 days; 1 interaction 8+ months ago |
| SCN-006 | 2 recent (one with transcript, one without) |
| All others | Per scenario-catalog.md specifications |

### Synthetic Row-Count Target

| Target | Value |
|--------|-------|
| Scenario interactions | ~30 |
| Background interactions | ~170 |
| **Total** | **~200** |

### Validation Rules

| # | Rule | Severity |
|---|------|----------|
| V1 | interaction_id is unique | Hard |
| V2 | customer_id exists in customers | Hard |
| V3 | representative_id exists in service_representatives when not null | Hard |
| V4 | channel is in allowed enum | Hard |
| V5 | direction is in allowed enum | Hard |
| V6 | disposition is in allowed enum | Hard |
| V7 | interaction_date ≤ generation timestamp | Hard |
| V8 | duration_seconds > 0 when channel = 'phone' and value is not null | Hard |
| V9 | duration_seconds is null when channel ≠ 'phone' | Hard |
| V10 | Scenario interactions match specified dates and attributes | Hard |

---

## 7. transcripts

### Grain

One row per interaction that has textual content. Not every interaction has a transcript.

### Primary Identifier

| Column | Format | Example |
|--------|--------|---------|
| `transcript_id` | `TRX-NNNNNN` (6 digits, sequential) | `TRX-000001` |

### Foreign-Key Relationships

| FK Column | References | Constraint |
|-----------|-----------|-----------|
| interaction_id | interactions.interaction_id | Must exist; 1:1 relationship (unique) |

### Required Columns

| Column | Type | Description |
|--------|------|-------------|
| transcript_id | STRING | Primary identifier (surrogate) |
| interaction_id | STRING | FK → interactions (unique constraint — one transcript per interaction) |
| content_type | STRING | Source type |
| raw_text | STRING | Verbatim unstructured content |
| word_count | INTEGER | Word count of raw_text |
| recording_consent_flag | BOOLEAN | Whether consent was captured |

### Nullable Columns

None. All columns required when a transcript row exists.

### Allowed Enumeration Values

| Column | Allowed Values |
|--------|---------------|
| content_type | `call_transcript`, `email_body`, `agent_note` |
| recording_consent_flag | `TRUE`, `FALSE` |

### Date and Timestamp Rules

No date columns on transcripts. Temporal context comes from the parent interaction's interaction_date.

### Cardinality Assumptions

| Assumption | Value | Label |
|-----------|-------|-------|
| Transcripts per interaction | 0 or 1 | ~25% of interactions have no transcript (brief calls, no recording) |
| Word count (call transcripts) | 80–300 words (synthetic prototype assumption) | |
| Word count (email bodies) | 50–200 words | |
| Word count (agent notes) | 20–80 words | |
| Consent flag = FALSE | ~5% of transcripts (synthetic prototype assumption) | Used for consent testing (SCN-007) |

### Scenario Dependencies

| Scenario | Transcript Requirement |
|----------|------------------------|
| SCN-001 | 4 transcripts (2 recent negative, 2 older positive), all consent=TRUE |
| SCN-006 | 1 transcript for Interaction A (negative); NO transcript for Interaction B |
| SCN-007 | Transcript 1: consent=FALSE; Transcript 2: consent=TRUE |
| All others | Per scenario-catalog.md (consent=TRUE unless specified) |

### Content Generation Rules

| Tone | Content Pattern | Used In |
|------|-----------------|---------|
| Negative (frustrated) | References to delays, premium increases, lack of communication, unresolved issues. Uses phrases like "frustrated", "still waiting", "no one called back". | SCN-001, 002, 004, 007, 009 |
| Negative (hostile) | Stronger language: "unacceptable", "cancel my policy", "speak to a manager". | Not used in MVP (over-triggering risk) |
| Neutral | Factual questions about status, coverage details, payment options. No emotional language. | SCN-002 (1 of 3), SCN-008 |
| Positive | Expresses satisfaction, thanks, or routine confirmation. "Everything looks good", "thank you for the quick response". | SCN-001 (older), 003, 010, 011, 012 (recent) |

### Synthetic Row-Count Target

| Target | Value |
|--------|-------|
| Scenario transcripts | ~25 |
| Background transcripts | ~25 |
| **Total** | **~50** |

### Validation Rules

| # | Rule | Severity |
|---|------|----------|
| V1 | transcript_id is unique | Hard |
| V2 | interaction_id exists in interactions | Hard |
| V3 | interaction_id is unique within transcripts (1:1) | Hard |
| V4 | content_type is in allowed enum | Hard |
| V5 | raw_text is not empty | Hard |
| V6 | word_count = actual word count of raw_text | Hard |
| V7 | word_count > 0 | Hard |
| V8 | recording_consent_flag is TRUE or FALSE (not null) | Hard |
| V9 | content_type aligns with parent interaction channel (call_transcript↔phone, email_body↔email, agent_note↔any) | Hard |
| V10 | Scenario transcripts match specified tone and consent flags | Hard |

---

## 8. service_representatives

### Grain

One row per service representative (employee).

### Primary Identifier

| Column | Format | Example |
|--------|--------|---------|
| `representative_id` | `REP-NNN` (3 digits) | `REP-001` |

### Foreign-Key Relationships

None outbound. Referenced by interactions.representative_id.

### Required Columns

| Column | Type | Description |
|--------|------|-------------|
| representative_id | STRING | Primary identifier (business key — employee ID) |
| name | STRING | Display name |
| role | STRING | Role classification |
| active | BOOLEAN | Employment status |

### Nullable Columns

| Column | Type | Null Condition |
|--------|------|---------------|
| team | STRING | Null for ~10% (unassigned/floating) |

### Allowed Enumeration Values

| Column | Allowed Values |
|--------|---------------|
| role | `service_rep`, `retention_specialist`, `supervisor` |
| active | `TRUE`, `FALSE` |

### Date and Timestamp Rules

None (no date columns in source dataset).

### Cardinality Assumptions

| Assumption | Value | Label |
|-----------|-------|-------|
| Total representatives | 5 | Minimum to demonstrate rep-level audit diversity |
| Role distribution | 3 service_rep, 1 retention_specialist, 1 supervisor | MVP exercises service_rep only |
| Active status | 4 active, 1 inactive | Tests filtering |

### Scenario Dependencies

No scenario-specific representative requirements. All scenario interactions reference one of the active service_rep representatives.

### Synthetic Row-Count Target

| Target | Value |
|--------|-------|
| **Total** | **5** |

### Validation Rules

| # | Rule | Severity |
|---|------|----------|
| V1 | representative_id is unique | Hard |
| V2 | role is in allowed enum | Hard |
| V3 | active is TRUE or FALSE | Hard |
| V4 | At least 1 representative with role = 'service_rep' and active = TRUE | Hard |
| V5 | All representative_ids referenced by interactions exist here | Hard |

---

## Cross-Dataset Referential Integrity

These rules are validated across all generated datasets before output:

| # | Rule | Datasets Involved |
|---|------|-------------------|
| X1 | Every policies.customer_id exists in customers.customer_id | policies → customers |
| X2 | Every coverages.policy_id exists in policies.policy_id | coverages → policies |
| X3 | Every claims.policy_id exists in policies.policy_id | claims → policies |
| X4 | Every claims.customer_id exists in customers.customer_id | claims → customers |
| X5 | Every claims.customer_id matches the customer who owns claims.policy_id | claims → policies → customers |
| X6 | Every payments.customer_id exists in customers.customer_id | payments → customers |
| X7 | Every payments.policy_id exists in policies.policy_id | payments → policies |
| X8 | Every interactions.customer_id exists in customers.customer_id | interactions → customers |
| X9 | Every interactions.representative_id (when not null) exists in service_representatives.representative_id | interactions → service_representatives |
| X10 | Every transcripts.interaction_id exists in interactions.interaction_id | transcripts → interactions |
| X11 | No transcripts.interaction_id is duplicated (1:1 constraint) | transcripts internal |
| X12 | Every active policy has at least 1 coverage row | policies → coverages |

---

## Output File Format

All datasets are written as CSV with:

| Property | Value |
|----------|-------|
| Encoding | UTF-8 |
| Delimiter | Comma (`,`) |
| Quote character | Double quote (`"`) — applied to all string fields containing commas or newlines |
| Header row | Yes (first row = column names) |
| Null representation | Empty field (no quotes, no literal "NULL") |
| Boolean representation | `TRUE` / `FALSE` (uppercase) |
| Date format | `YYYY-MM-DD` |
| Timestamp format | `YYYY-MM-DDTHH:MM:SS` (ISO 8601, no timezone — interpreted as UTC) |
| Line ending | LF (`\n`) |
| File naming | `{dataset_name}.csv` (e.g., `customers.csv`, `policies.csv`) |

---

## Generation Order (dependency chain)

```
1. service_representatives  (no dependencies)
2. customers                (no dependencies)
3. policies                 (depends on customers)
4. coverages                (depends on policies)
5. claims                   (depends on policies, customers)
6. payments                 (depends on policies, customers)
7. interactions             (depends on customers, service_representatives)
8. transcripts              (depends on interactions)
```

---

*Document version: v1. All cardinalities, distributions, and thresholds are synthetic prototype assumptions.*
