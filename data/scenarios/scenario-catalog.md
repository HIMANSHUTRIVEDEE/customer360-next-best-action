# Scenario Catalog — Synthetic Data Generation

This catalog defines 12 synthetic scenarios that support the golden demo, pipeline testing, NBA logic testing, and fallback verification. Each scenario prescribes the data state required in RAW tables to produce expected downstream behavior.

**Important:** All values, thresholds, and distributions in this catalog are **synthetic prototype assumptions** chosen to exercise system behavior. They are not insurance-industry benchmarks or production calibration targets.

---

## Scenario Index

| # | Scenario | Category | Primary Test Purpose |
|---|----------|----------|---------------------|
| 1 | Maria Chen golden demo | Negative | End-to-end golden demo; full NBA with evidence |
| 2 | Approaching renewal + negative interactions | Negative | NBA triggers retention action |
| 3 | Approaching renewal + positive interactions | Positive | NBA produces standard renewal (no intervention needed) |
| 4 | Negative interactions outside renewal window | Edge case | Signals present but urgency absent; NBA behavior differs |
| 5 | No recent interactions | Edge case | Insufficient sentiment data; fallback triggered |
| 6 | Interaction without transcript | Edge case | Enrichment status = not_applicable; no sentiment derived |
| 7 | Transcript without recording consent | Edge case | Enrichment skipped; consent enforcement verified |
| 8 | Repeated late payments | Negative | Payment-behavior signal fires; lapse risk elevated |
| 9 | Unresolved complaint | Negative | Open complaint signal fires; acknowledgment action expected |
| 10 | Single-policy customer | Positive | Multi-policy signal absent; relationship breadth = low |
| 11 | Multi-policy customer | Positive | Multi-policy signal fires; household risk amplified |
| 12 | Contradictory risk signals | Edge case | Conflicting signals; confidence reduced; tests robustness |

---

## Scenario 1: Maria Chen Golden Demo

| Field | Value |
|-------|-------|
| **scenario_id** | `SCN-001` |
| **category** | Negative |
| **business_purpose** | Primary demonstration scenario. Exercises the full flow: Select customer → Understand context → Explain risk → Recommend action → Approve/create follow-up. |

### Customer and Household Requirements

| Requirement | Detail |
|-------------|--------|
| Customer name | Maria Chen |
| customer_id | `CUST-001` (deterministic, stable across regenerations) |
| household_id | `HH-001` |
| Household members | 1 (Maria only; simplifies demo narrative) |
| customer_since | At least 3 years prior to generation date |
| status | active |
| Contact info | Synthetic email (maria.chen@example.com), synthetic phone (555-0101) |

### Policy Requirements

| Requirement | Detail |
|-------------|--------|
| Policy count | 2 (auto + home) |
| Auto policy status | active |
| Auto policy expiration_date | 14–18 days from generation date (synthetic prototype assumption: within 30-day renewal window) |
| Home policy status | active |
| Home policy expiration_date | 6+ months from generation date (not approaching renewal) |
| Premium amounts | Synthetic values; auto ~$1,200/year, home ~$1,800/year |

### Claim and Payment Requirements

| Requirement | Detail |
|-------------|--------|
| Open claims | 0 (no current claim) |
| Historical claims | 1 settled claim on auto (6+ months ago; resolved) |
| Payment status | All payments on-time for both policies. No late, grace-period, or missed payments. |

### Interaction Requirements

| Requirement | Detail |
|-------------|--------|
| Total recent interactions | 2 within last 60 days + at least 2 older (positive) interactions |
| Interaction 1 (recent) | Channel: phone, direction: inbound, disposition: complaint, ~45 days ago |
| Interaction 2 (recent) | Channel: email, direction: inbound, disposition: inquiry, ~20 days ago |
| Older interactions | Channel: phone, direction: inbound, disposition: general, positive tone, 6+ months ago |

### Transcript Requirements

| Requirement | Detail |
|-------------|--------|
| Transcript 1 (complaint) | Content: customer frustrated about delayed communication on settled claim. ~150 words. recording_consent_flag = TRUE. |
| Transcript 2 (inquiry) | Content: customer asking why premium increased; tone frustrated but not hostile. ~100 words. recording_consent_flag = TRUE. |
| Older transcripts | Content: routine positive interactions. recording_consent_flag = TRUE. |

### Expected Downstream Signal Behavior

| Signal | Expected Value | Rationale |
|--------|---------------|-----------|
| renewal_proximity | High (14–18 days) | Within 30-day window |
| negative_sentiment_count_90d | 2 | Two negative interactions in window |
| sentiment_direction | Worsening | Current window worse than prior window |
| payment_behavior | Good (no risk) | All on-time |
| multi_policy_flag | TRUE | 2 policies |
| open_complaints | 0 | No unresolved |

### Expected Fallback Behavior

| Condition | Expected |
|-----------|----------|
| All enrichments complete | Full NBA generated: `acknowledge_retain` with High confidence |
| Enrichment disabled | Structured 360 renders; NBA withheld; banner shown |

---

## Scenario 2: Approaching Renewal + Negative Interactions

| Field | Value |
|-------|-------|
| **scenario_id** | `SCN-002` |
| **category** | Negative |
| **business_purpose** | Validates that the NBA engine produces a retention-oriented action when renewal proximity and negative sentiment coexist (non-golden-demo customer). |

### Customer and Household Requirements

- customer_id: `CUST-002`
- household_id: `HH-002`
- Different name than Maria Chen (e.g., James Rodriguez)
- status: active, customer_since: 2+ years

### Policy Requirements

- 1 auto policy, status: active, expiration_date: 20–25 days from generation (within renewal window)
- No home policy (tests single-policy path with renewal urgency)

### Claim and Payment Requirements

- 1 open claim (status: under_review, filed 30 days ago). Tests interaction of active claim + renewal.
- Payments: mostly on-time, 1 late payment 4 months ago (not recent enough to dominate)

### Interaction Requirements

- 3 interactions in last 90 days: 2 negative (claim frustration), 1 neutral (status check)
- All inbound phone calls

### Transcript Requirements

- 2 transcripts with negative content (claim handling delays)
- 1 transcript with neutral tone
- All recording_consent_flag = TRUE

### Expected Downstream Signal Behavior

| Signal | Expected |
|--------|----------|
| renewal_proximity | High |
| negative_sentiment_count_90d | 2 |
| sentiment_direction | Stable (was already negative in prior window due to claim) |
| payment_behavior | Minor risk (1 historical late) |
| open_complaints | 0 (claim ≠ complaint) |

### Expected Fallback Behavior

- Full enrichment: NBA = `acknowledge_retain` or `escalate_specialist` (open claim adds complexity)
- Enrichment failed: NBA withheld

---

## Scenario 3: Approaching Renewal + Positive Interactions

| Field | Value |
|-------|-------|
| **scenario_id** | `SCN-003` |
| **category** | Positive |
| **business_purpose** | Validates that the NBA engine produces `standard_renewal` (no intervention) when renewal is near but all interactions are positive. Demonstrates the system does not over-trigger. |

### Customer and Household Requirements

- customer_id: `CUST-003`
- household_id: `HH-003`
- status: active, customer_since: 5+ years (loyal customer)

### Policy Requirements

- 2 policies (auto + home), both active
- Auto expiration_date: 10–15 days from generation (closer than Maria's, but positive signals)

### Claim and Payment Requirements

- No open claims, no claims in 2+ years
- All payments on-time, no exceptions

### Interaction Requirements

- 2 interactions in last 90 days: both positive (routine inquiry, coverage question answered)
- All inbound

### Transcript Requirements

- 2 transcripts with positive/neutral content
- recording_consent_flag = TRUE

### Expected Downstream Signal Behavior

| Signal | Expected |
|--------|----------|
| renewal_proximity | High |
| negative_sentiment_count_90d | 0 |
| sentiment_direction | Stable (positive both windows) |
| payment_behavior | Good |
| multi_policy_flag | TRUE |

### Expected Fallback Behavior

- Full enrichment: NBA = `standard_renewal` with High confidence
- Enrichment failed: NBA withheld (required sentiment missing, even though it would have been positive)

---

## Scenario 4: Negative Interactions Outside Renewal Window

| Field | Value |
|-------|-------|
| **scenario_id** | `SCN-004` |
| **category** | Edge case |
| **business_purpose** | Tests that negative sentiment alone does not trigger high-urgency retention action when renewal is distant. Validates that renewal_proximity weight correctly attenuates overall risk. |

### Customer and Household Requirements

- customer_id: `CUST-004`
- household_id: `HH-004`
- status: active

### Policy Requirements

- 1 auto policy, expiration_date: 120+ days from generation (well outside 30-day window)

### Claim and Payment Requirements

- No open claims
- Payments on-time

### Interaction Requirements

- 3 interactions in last 60 days: all negative (billing dispute, service complaint, follow-up complaint)

### Transcript Requirements

- 3 transcripts with negative content
- recording_consent_flag = TRUE

### Expected Downstream Signal Behavior

| Signal | Expected |
|--------|----------|
| renewal_proximity | Low (120+ days) |
| negative_sentiment_count_90d | 3 (high) |
| sentiment_direction | Worsening |
| payment_behavior | Good |

### Expected Fallback Behavior

- Full enrichment: NBA generated but action may be `escalate_specialist` or `acknowledge_retain` with reduced urgency. Renewal proximity weight keeps overall score moderate.
- Enrichment failed: NBA withheld

---

## Scenario 5: No Recent Interactions

| Field | Value |
|-------|-------|
| **scenario_id** | `SCN-005` |
| **category** | Edge case |
| **business_purpose** | Tests fallback behavior when no interactions exist in the observation window (90 days). No sentiment signal is computable. Per BR4: NBA is withheld. |

### Customer and Household Requirements

- customer_id: `CUST-005`
- household_id: `HH-005`
- status: active, customer_since: 4+ years

### Policy Requirements

- 1 home policy, expiration_date: 20 days from generation (approaching renewal)

### Claim and Payment Requirements

- No claims
- Payments on-time

### Interaction Requirements

- 0 interactions in last 90 days
- 1 interaction 8 months ago (positive)

### Transcript Requirements

- 1 transcript on the old interaction (positive)
- No recent transcripts to enrich

### Expected Downstream Signal Behavior

| Signal | Expected |
|--------|----------|
| renewal_proximity | High |
| negative_sentiment_count_90d | 0 (no data, not "positive") |
| sentiment_direction | Not computable (no current-window data) |
| enrichment_coverage_pct | 0% for observation window |

### Expected Fallback Behavior

- Required recent sentiment is missing (no interactions to enrich in window): **NBA withheld**
- 360 view still shows: policy approaching renewal, payment status, historical interaction
- Banner: "Insufficient evidence for automated recommendation"

---

## Scenario 6: Interaction Without Transcript

| Field | Value |
|-------|-------|
| **scenario_id** | `SCN-006` |
| **category** | Edge case |
| **business_purpose** | Tests that an interaction with no transcript (e.g., brief administrative call) produces enrichment_status = not_applicable and does not break the pipeline. |

### Customer and Household Requirements

- customer_id: `CUST-006`
- household_id: `HH-006`
- status: active

### Policy Requirements

- 1 auto policy, active, expiration_date: 25 days from generation

### Claim and Payment Requirements

- No claims, payments on-time

### Interaction Requirements

- 2 interactions in last 60 days:
  - Interaction A: has transcript (negative sentiment)
  - Interaction B: no transcript (brief call, no recording)
- 1 older interaction (positive, with transcript)

### Transcript Requirements

- Transcript for Interaction A: negative content, recording_consent_flag = TRUE
- No transcript row for Interaction B
- Transcript for older interaction: positive

### Expected Downstream Signal Behavior

| Signal | Expected |
|--------|----------|
| negative_sentiment_count_90d | 1 (only Interaction A has enrichable transcript) |
| Interaction B enrichment_status | not_applicable (no transcript exists) |
| Data completeness | < 100% (one interaction has no transcript) |

### Expected Fallback Behavior

- Enrichment exists for at least one recent interaction: NBA generated with Medium confidence (gap disclosed)
- If the one enrichment fails: NBA withheld

---

## Scenario 7: Transcript Without Recording Consent

| Field | Value |
|-------|-------|
| **scenario_id** | `SCN-007` |
| **category** | Edge case |
| **business_purpose** | Tests consent enforcement: transcript with recording_consent_flag = FALSE must not be sent to Cortex. Enrichment_status = not_applicable. Signal cannot be derived from non-consented content. |

### Customer and Household Requirements

- customer_id: `CUST-007`
- household_id: `HH-007`
- status: active

### Policy Requirements

- 1 home policy, active, expiration_date: 15 days from generation

### Claim and Payment Requirements

- No claims, payments on-time

### Interaction Requirements

- 2 interactions in last 30 days, both inbound phone calls

### Transcript Requirements

- Transcript 1: negative content, recording_consent_flag = **FALSE**
- Transcript 2: negative content, recording_consent_flag = TRUE

### Expected Downstream Signal Behavior

| Signal | Expected |
|--------|----------|
| Transcript 1 enrichment_status | not_applicable (consent absent) |
| Transcript 2 enrichment_status | completed (consent present) |
| negative_sentiment_count_90d | 1 (only transcript 2 contributes) |

### Expected Fallback Behavior

- One valid enrichment exists: NBA generated (at least one sentiment signal available)
- Note: the non-consented transcript is invisible to the risk engine — as designed

---

## Scenario 8: Repeated Late Payments

| Field | Value |
|-------|-------|
| **scenario_id** | `SCN-008` |
| **category** | Negative |
| **business_purpose** | Tests that the payment_behavior signal fires when a customer has multiple late payments. Tests `payment_arrangement` action eligibility. |

### Customer and Household Requirements

- customer_id: `CUST-008`
- household_id: `HH-008`
- status: active

### Policy Requirements

- 1 auto policy, active, expiration_date: 45 days from generation (outside renewal window)
- payment_frequency: monthly

### Claim and Payment Requirements

- No claims
- 3 late payments in last 6 months (paid, but 10-15 days past due each time)
- 1 payment currently in grace period

### Interaction Requirements

- 1 interaction 30 days ago (inbound call about payment question)
- Disposition: inquiry

### Transcript Requirements

- 1 transcript, neutral tone (asking about payment options)
- recording_consent_flag = TRUE

### Expected Downstream Signal Behavior

| Signal | Expected |
|--------|----------|
| renewal_proximity | Low (45 days out) |
| negative_sentiment_count_90d | 0 (neutral tone) |
| payment_behavior | Poor (3 late + 1 grace period) |
| late_payment_count_12m | 3 |

### Expected Fallback Behavior

- Full enrichment: NBA may suggest `payment_arrangement` if eligible for product type
- Sentiment is neutral so it's available; NBA generated with payment as primary signal

---

## Scenario 9: Unresolved Complaint

| Field | Value |
|-------|-------|
| **scenario_id** | `SCN-009` |
| **category** | Negative |
| **business_purpose** | Tests that an interaction with disposition = complaint and no subsequent resolution interaction produces an open-complaint signal. Validates acknowledgment action. |

### Customer and Household Requirements

- customer_id: `CUST-009`
- household_id: `HH-009`
- status: active

### Policy Requirements

- 1 home policy, active, expiration_date: 22 days from generation (renewal window)

### Claim and Payment Requirements

- No claims
- Payments on-time

### Interaction Requirements

- 1 interaction 15 days ago: channel phone, direction inbound, disposition: **complaint**
- No subsequent interaction (complaint unresolved)

### Transcript Requirements

- 1 transcript: customer complaining about coverage denial for a minor issue; frustrated tone
- recording_consent_flag = TRUE

### Expected Downstream Signal Behavior

| Signal | Expected |
|--------|----------|
| renewal_proximity | High |
| negative_sentiment_count_90d | 1 |
| open_complaints | 1 (disposition = complaint, no follow-up resolution) |
| sentiment_direction | Worsening (prior window was clean) |

### Expected Fallback Behavior

- Full enrichment: NBA = `acknowledge_retain` (open complaint + approaching renewal)
- Enrichment failed: NBA withheld

---

## Scenario 10: Single-Policy Customer

| Field | Value |
|-------|-------|
| **scenario_id** | `SCN-010` |
| **category** | Positive |
| **business_purpose** | Tests that multi_policy_flag = FALSE. Validates that relationship-breadth signal is absent. Baseline customer with no complexity. |

### Customer and Household Requirements

- customer_id: `CUST-010`
- household_id: `HH-010`
- status: active, customer_since: 1 year

### Policy Requirements

- 1 renters policy, active, expiration_date: 60 days from generation

### Claim and Payment Requirements

- No claims
- Payments on-time

### Interaction Requirements

- 1 interaction 2 months ago (positive inquiry)

### Transcript Requirements

- 1 transcript, positive tone
- recording_consent_flag = TRUE

### Expected Downstream Signal Behavior

| Signal | Expected |
|--------|----------|
| renewal_proximity | Low (60 days) |
| negative_sentiment_count_90d | 0 |
| multi_policy_flag | FALSE |
| payment_behavior | Good |

### Expected Fallback Behavior

- Full enrichment: NBA = `standard_renewal` with High confidence (no risk signals)
- Note: `loyalty_adjustment` is ineligible for renters product (eligibility rule)

---

## Scenario 11: Multi-Policy Customer

| Field | Value |
|-------|-------|
| **scenario_id** | `SCN-011` |
| **category** | Positive |
| **business_purpose** | Tests that multi_policy_flag = TRUE and household_policy_count is correctly computed. Validates that relationship breadth increases the retention signal weight. |

### Customer and Household Requirements

- customer_id: `CUST-011`
- household_id: `HH-011`
- Household contains 2 customers (CUST-011 + spouse CUST-011B)
- Both active

### Policy Requirements

- CUST-011: auto + home + umbrella (3 policies), all active
- CUST-011B: auto (1 policy), active
- Total household policies: 4
- CUST-011 auto expiration_date: 28 days from generation (renewal window)

### Claim and Payment Requirements

- No open claims
- All payments on-time across all policies

### Interaction Requirements

- 1 interaction for CUST-011, 40 days ago, positive

### Transcript Requirements

- 1 transcript, positive tone
- recording_consent_flag = TRUE

### Expected Downstream Signal Behavior

| Signal | Expected |
|--------|----------|
| multi_policy_flag | TRUE |
| household_policy_count | 4 |
| renewal_proximity | High (28 days for auto) |
| negative_sentiment_count_90d | 0 |

### Expected Fallback Behavior

- Full enrichment: NBA = `standard_renewal` (positive signals despite renewal proximity)
- Demonstrates that renewal proximity alone doesn't trigger retention action

---

## Scenario 12: Contradictory Risk Signals

| Field | Value |
|-------|-------|
| **scenario_id** | `SCN-012` |
| **category** | Edge case |
| **business_purpose** | Tests NBA behavior when signals conflict: approaching renewal (risk) + positive recent sentiment (safety) + late payments (risk) + long tenure (safety). Confidence should be reduced due to signal disagreement. |

### Customer and Household Requirements

- customer_id: `CUST-012`
- household_id: `HH-012`
- status: active, customer_since: 8+ years (long tenure)

### Policy Requirements

- 2 policies (auto + home), both active
- Auto expiration_date: 12 days from generation (very close renewal)

### Claim and Payment Requirements

- No open claims
- 2 late payments in last 6 months (conflicting with positive interactions)

### Interaction Requirements

- 2 interactions in last 60 days: both positive (general inquiry, coverage review request)
- 1 interaction 4 months ago: negative (billing dispute — now resolved)

### Transcript Requirements

- 2 recent transcripts: positive tone
- 1 older transcript: negative tone (but outside 90-day current window)
- All recording_consent_flag = TRUE

### Expected Downstream Signal Behavior

| Signal | Expected |
|--------|----------|
| renewal_proximity | Very high (12 days) |
| negative_sentiment_count_90d | 0 (recent interactions are positive) |
| sentiment_direction | Improving (prior window had negative; current is positive) |
| payment_behavior | Poor (2 late payments) |
| multi_policy_flag | TRUE |
| Signal agreement | Low (renewal urgency + payment risk vs. positive sentiment + long tenure) |

### Expected Fallback Behavior

- Full enrichment: NBA generated but with **Medium** confidence (signal disagreement reduces confidence)
- Action likely `standard_renewal` or `coverage_review` (positive sentiment means retention urgency is low despite payment issues)
- Evidence panel should disclose conflicting signals explicitly

---

## Volume Summary

| Entity | Minimum Rows (across all scenarios) | Synthetic Prototype Assumption |
|--------|-------------------------------------|-------------------------------|
| Households | ~50 (12 scenario households + ~38 background) | Chosen to demonstrate pipeline at modest scale |
| Customers | ~100 (12 scenario + ~88 background) | Per solution-design.md §1 |
| Policies | ~250 (scenario policies + background 1-4 per customer) | Per solution-design.md: ~500 target (includes background) |
| Coverages | ~500 (2-3 per policy average) | Realistic cardinality |
| Claims | ~30 (sparse; most customers have 0-1) | |
| Payments | ~600 (monthly billing × active policies × 6 months) | |
| Interactions | ~200 (scenario interactions + background) | Per solution-design.md §1 |
| Transcripts | ~50 (not every interaction has text) | Per solution-design.md §1 |
| Service Representatives | ~5 | Minimum to demonstrate rep-level audit |

Background customers (non-scenario) are generated with randomized but referentially-valid data to provide realistic query context without individually specified scenarios.

---

## Generator Requirements

1. **Deterministic:** Same random seed → same output on every run.
2. **Idempotent:** Re-running produces identical files (overwrite, not append).
3. **Scenario-first:** The 12 scenarios above are generated explicitly with fixed values. Background data is generated randomly around them.
4. **Golden demo stable:** Maria Chen's customer_id, policy_ids, interaction_ids, and transcript_ids are hardcoded constants that never change between regenerations.
5. **Date-relative:** Dates are computed relative to generation date so the demo stays valid regardless of when setup runs.
6. **FK integrity:** Every FK reference is valid. No orphan records.
7. **Enum compliance:** All enum fields use only approved values from data-model.md.

---

*Document version: v1. All values are synthetic prototype assumptions. Expected signals and recommendations are test expectations only — not production calibration.*
