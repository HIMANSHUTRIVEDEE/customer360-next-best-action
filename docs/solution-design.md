# Solution Design — MVP Scope

## Delivery Boundary

**Deadline:** 30 August 2026
**Scope control:** Everything below is classified as Mandatory MVP, High-Value Bonus, or Explicitly Out of Scope. The mandatory set is the minimum shippable prototype. Bonus items are pursued only after all mandatory items pass acceptance criteria.

---

## Golden Demo Scenario

The golden demo remains consistent across the application, README, submission deck, and live demonstration:

```text
Select customer
→ Understand context
→ Explain risk
→ Recommend action
→ Approve/create follow-up
```

### Synthetic Customer

**Customer:** Maria Chen, a synthetic household customer with auto and homeowners policies.

### Setup State

- Auto policy renewal is approaching.
- Two recent interactions have negative machine-derived sentiment:
  - A call transcript concerning delayed claim communication.
  - An email concerning a premium increase.
- Payment history is current.
- No claim is currently open.

### Demo Walkthrough

#### 1. Select customer

The representative searches for and selects Maria Chen by customer name or identifier.

#### 2. Understand context

The application presents a unified Customer 360 view containing:

- Customer and household details.
- Active policies and renewal dates.
- Current payment status.
- Recent interaction timeline.
- Machine-derived sentiment and topic labels.

#### 3. Explain risk

The application explains that Maria requires attention because renewal proximity and recent negative interactions coexist. It displays contributing signals, source references, data-completeness status, and confidence.

#### 4. Recommend action

The application presents one deterministic Next Best Action:

> Acknowledge the prior service issues, offer an eligible loyalty adjustment subject to policy rules and representative approval, and confirm that current coverage still meets the customer's needs.

Alternative actions and supporting evidence are also shown. The recommendation is decision support, not an automated decision.

#### 5. Approve/create follow-up

The representative may approve, modify, or reject the recommendation. When approved, the application creates an internal follow-up record and logs:

- Original recommendation.
- Representative decision or modification.
- Evidence snapshot.
- Representative identifier and timestamp.
- Follow-up status.

No customer-facing action is executed automatically.

### What the Demo Proves

- Structured and unstructured customer data are unified in one experience.
- Risk is explained using traceable evidence.
- The workflow progresses from customer selection to an actionable recommendation.
- A human approval gate controls follow-up creation.
- Decisions and evidence are auditable.
- If AI enrichment is unavailable, structured context remains available and the recommendation is withheld.

## Mandatory MVP

All items below must be complete and demonstrable by 30 August.

### 1. Synthetic Data Generation

| Deliverable | Detail |
|-------------|--------|
| Structured data | Customers, policies, coverages, claims, payments, interactions (metadata) |
| Unstructured data | Call transcripts (text), email bodies, agent notes |
| Scenario seeding | At least one customer matching the golden demo profile (negative sentiment + approaching renewal) |
| Volume | Sufficient to demonstrate pipeline behavior: ~100 customers, ~500 policies, ~200 interactions, ~50 transcripts |
| Referential integrity | Foreign keys enforced; realistic cardinality (1-4 policies per customer, 1-6 interactions per year) |
| Reproducibility | Generation scripted and idempotent; runnable from repo |

### 2. Customer 360 Assembly

| Deliverable | Detail |
|-------------|--------|
| Unified view | Single query or view that joins customer, policy, coverage, claim, payment, and interaction data |
| Incremental refresh | Dynamic table or stream-based pipeline so new interactions appear without full rebuild |
| Unstructured integration | Enriched transcript/email data (sentiment, topics) joined into the 360 context |
| Schema | Documented in `docs/data-model.md` |

### 3. Transcript Enrichment

| Deliverable | Detail |
|-------------|--------|
| Sentiment extraction | Cortex AI function applied to each transcript/email to produce a sentiment score and label |
| Topic extraction | Key topics or intent extracted per interaction |
| Incremental processing | New transcripts processed via pipeline (stream + task or dynamic table) without reprocessing historical |
| Output | Enrichment results stored in a table joinable to the interaction record |

### 4. Semantic Model

| Deliverable | Detail |
|-------------|--------|
| Semantic view | YAML-defined semantic model covering the Customer 360 domain |
| Queryable | Supports natural-language questions via Cortex Analyst (e.g., "Which customers have negative sentiment and renewal in 30 days?") |
| Coverage | Must include: customer attributes, policy status, payment status, interaction sentiment, renewal proximity |
| Validation | Passes `cortex reflect` without errors |

### 5. Explainable Churn/Risk Indicators

| Deliverable | Detail |
|-------------|--------|
| Signal computation | Rule-based risk scoring combining: renewal proximity, negative sentiment count/recency, payment behavior, open complaints |
| Transparency | Each signal contributes a named, weighted component visible in the UI |
| No black box | No ML model required; signals are deterministic and auditable |
| Output | Risk score + contributing signal breakdown per customer, stored in a table or view |

### 6. Next Best Action Engine

| Deliverable | Detail |
|-------------|--------|
| Action library | Predefined set of candidate actions (retain/acknowledge, escalate, standard renewal, coverage review) |
| Scoring logic | Rule-based ranking: signal weights × action relevance, filtered by eligibility rules |
| Top recommendation | Single recommended action with confidence level |
| Alternatives | At least two alternative actions shown with trade-off context |
| Evidence attachment | Each recommendation links to the specific signals that produced it |
| Determinism | Same inputs produce same recommendation (no stochastic behavior in scoring) |

### 7. Confidence and Evidence

| Deliverable | Detail |
|-------------|--------|
| Confidence indicator | Displayed per recommendation (e.g., High / Medium-High / Medium / Low) based on signal count, recency, and data completeness |
| Evidence trail | Each recommendation shows: which signals contributed, their values, and source references (transcript ID, interaction date) |
| Data completeness flag | If any data source is missing or stale, the confidence is downgraded and the gap is surfaced |

### 8. Human Review Gate

| Deliverable | Detail |
|-------------|--------|
| Approval workflow | Rep must explicitly Accept, Modify, or Reject the recommendation |
| No auto-execution | The system never takes action without human consent |
| Modification capture | If rep modifies the action, the modification is logged alongside the original recommendation |
| Rejection logging | Rejected recommendations are logged with optional reason |

### 9. Streamlit Application

| Deliverable | Detail |
|-------------|--------|
| Deployment | Streamlit-in-Snowflake (SiS) |
| Customer search | Search/select a customer by name or ID |
| 360 context view | Unified display: policies, payments, interactions (with sentiment), risk signals |
| NBA panel | Recommendation + evidence + confidence + alternatives |
| Action buttons | Accept / Modify / Reject |
| Outcome recording | After action, log the decision |
| Fallback state | If AI enrichment is unavailable, the app still renders structured data with a "Recommendations unavailable" notice |

### 10. Automation and Near-Real-Time Incremental Flow

| Deliverable | Detail |
|-------------|--------|
| Pipeline orchestration | Incremental dynamic tables keep the 360 view and enrichments current |
| Incremental processing | Only new or changed records are processed; no full recomputation on each refresh cycle |
| TARGET_LAG configuration | Intermediate DTs (INTERACTIONS_ENRICHED) use TARGET_LAG = DOWNSTREAM. Terminal DT (CUSTOMER_360) uses TARGET_LAG = '1 minute'. TARGET_LAG is a freshness objective, not a guaranteed refresh interval. |
| Deduplication | Source-event identifiers (`interaction_id`, `transcript_id`) and row hashes prevent duplicate processing when the same record is encountered more than once |
| Idempotency | Re-running the pipeline with the same source data produces identical results without creating duplicate rows |
| Monitoring | Dynamic table refresh status and freshness visible via SHOW DYNAMIC TABLES and INFORMATION_SCHEMA. Refresh failures and freshness breaches are queryable. |
| Observed latency | Actual end-to-end latency (RAW insert → CUSTOMER_360 refresh) is measured and recorded during testing — not assumed from TARGET_LAG |
| Reproducible setup | All automation created via SQL scripts in the repo |

#### Required Near-Real-Time Flow (demonstrable)

```
New interaction or transcript inserted into RAW
  → INTERACTIONS_ENRICHED refreshes (TARGET_LAG = DOWNSTREAM)
    → Cortex SENTIMENT + topic extraction applied to new record only
  → CUSTOMER_360 refreshes (TARGET_LAG = '1 minute')
    → Affected customer's aggregates recalculated
  → Next application query returns updated risk signals and NBA
```

#### Incremental Demo Scenario

Insert one new interaction for the golden demo customer (Maria Chen) and demonstrate:
1. INTERACTIONS_ENRICHED gains one new enriched row (sentiment + topics)
2. CUSTOMER_360 reflects updated `negative_interaction_count_90d` and `sentiment_direction`
3. Risk signals recalculate with the new data point
4. NBA recommendation may change (or confidence level adjusts) based on the additional signal

### 11. RBAC and Auditability

| Deliverable | Detail |
|-------------|--------|
| Role separation | At minimum: `DATA_ENGINEER` (pipeline), `SERVICE_REP` (app user), `AUDITOR` (read-only decision log) |
| Least privilege | Service rep cannot modify pipeline objects or raw data |
| Decision audit log | Table recording: customer_id, rep_id, timestamp, recommendation_shown, action_taken, evidence_snapshot, outcome (if recorded) |
| Queryable | Auditor role can query all decisions without modifying them |

### 12. Testing

| Deliverable | Detail |
|-------------|--------|
| Pipeline tests | Verify: synthetic data loads, enrichment produces expected output, 360 view populates correctly |
| NBA logic tests | Verify: golden demo scenario produces expected recommendation; edge cases (no interactions, all positive, missing data) produce sensible output |
| Fallback test | Verify: disabling AI enrichment results in graceful degradation, not application failure |
| RBAC test | Verify: service rep role cannot access pipeline objects; auditor role cannot modify decision log |
| Reproducibility | Tests runnable from repo via scripted commands |

---

## High-Value Bonus

Pursued only after all mandatory items pass acceptance criteria. Each is independent.

| Item | Value | Dependency |
|------|-------|------------|
| **CoCo reusable skill** | Demonstrates hackathon criterion; enables `$customer360` invocation for quick lookups | Mandatory MVP complete |
| **Multi-agent orchestration** | Demonstrates hackathon criterion; agents for data assembly, enrichment, and NBA generation coordinate | Mandatory MVP complete |
| **Action execution tool** | One-click action (e.g., generate renewal letter draft via Cortex AI) triggered after human approval | NBA engine + human review gate |
| **Cortex Agent integration** | Natural-language Q&A over the Customer 360 semantic model | Semantic model validated |
| **Outcome feedback loop** | Closed-loop: recorded outcomes adjust signal weights over time (still rule-based, not ML) | Decision audit log populated |
| **Additional demo scenarios** | Multi-policy lapse, coverage gap detection, post-claim service recovery | Core golden demo passing |
| **HTML summary report** | Publishable executive summary of prototype capabilities | Application functional |

---

## Explicitly Out of Scope

These are not attempted regardless of available time. They are noted to prevent scope creep.

| Item | Reason for Exclusion |
|------|---------------------|
| MCP server integration | Not an MVP dependency; adds integration complexity without core value |
| Slack / Teams notifications | External service dependency; out of Snowflake-native constraint |
| Jira ticket creation | External service dependency |
| Predictive ML model (churn propensity) | Requires historical outcome data that does not exist for a prototype; rule-based scoring is sufficient |
| Real PII or production data | Hackathon constraint C1; synthetic only |
| Mobile or embedded deployment | Constraint C4; Streamlit-in-Snowflake is the delivery channel |
| Multi-tenant / multi-carrier | Single-tenant prototype only |
| Automated outbound actions (email send, SMS) | Violates human-in-the-loop principle for MVP |
| Custom fine-tuned models | Cortex built-in functions are the processing layer |
| Real-time streaming ingestion (Snowpipe Streaming) | Batch/incremental via tasks is sufficient for demo |

---

## Acceptance Criteria

The prototype is considered complete when all of the following are true:

| # | Criterion | Verification |
|---|-----------|-------------|
| AC1 | Golden demo scenario executes end-to-end without manual intervention beyond rep approval | Live walkthrough |
| AC2 | Customer 360 view renders in < 5 seconds for any customer in the synthetic dataset | Latency observation |
| AC3 | Transcript enrichment produces sentiment and topic for all seeded transcripts | Query: zero NULL sentiment in enriched table |
| AC4 | NBA recommendation for golden demo customer matches expected action type | Deterministic test assertion |
| AC5 | Evidence trail shows at least two contributing signals with source references | UI inspection |
| AC6 | Human review gate prevents action logging without explicit approval | Attempt to log without approval → blocked |
| AC7 | Fallback: disabling enrichment results in structured 360 display + "Recommendations unavailable" | Simulated failure test |
| AC8 | Semantic model passes `cortex reflect` validation | CLI output |
| AC9 | Auditor role can query decision log; service rep role cannot modify pipeline tables | RBAC test queries |
| AC10 | All setup scripts run idempotently from a clean Snowflake account | Fresh-account deployment test |
| AC11 | Pipeline processes a newly inserted interaction through enrichment and into CUSTOMER_360 within the TARGET_LAG freshness objective | Insert into RAW → verify row in INTERACTIONS_ENRICHED → verify CUSTOMER_360 aggregates updated |
| AC12 | Repository README documents setup steps sufficient for a reviewer to deploy independently | Reviewer walkthrough |
| AC13 | Observed end-to-end latency (RAW insert to CUSTOMER_360 refresh) is recorded; TARGET_LAG = '1 minute' is stated as a freshness objective, not a guaranteed interval | Timestamp comparison logged in test output |
| AC14 | Duplicate interaction insert does not produce duplicate enrichment or inflate 360 aggregates | Insert same interaction_id twice → assert row count unchanged in INTERACTIONS_ENRICHED |
| AC15 | Dynamic table refresh failures are visible via SHOW DYNAMIC TABLES or INFORMATION_SCHEMA query | Simulate failure (e.g., invalid Cortex input) → verify error status queryable |

---

_Document version: v1.2. Added near-real-time incremental flow section, TARGET_LAG design decisions, deduplication requirements, and AC13-AC15 for latency/idempotency/monitoring._
