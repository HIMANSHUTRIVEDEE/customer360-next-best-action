# Problem Statement and Impact

## MVP Decision Statement

**This system helps one user (the customer service representative) make one decision (the safest Next Best Action) in one scenario (an inbound interaction where the customer has expressed negative sentiment and their policy renewal is approaching).**

The application is a human-in-the-loop decision-support tool. It assembles context, scores candidate actions, presents evidence, and waits for the representative to approve, modify, or reject the recommendation before any action is taken.

## Golden Demo Scenario

> **Customer:** Maria Chen, a synthetic multi-policy holder with auto and home policies.
> **Situation:** Maria calls in. Her auto renewal is in 18 days. Her last two interactions (a claim delay complaint and a billing inquiry) both carried negative sentiment. She has not yet received a renewal offer.
>
> **What happens today:** The rep answers blind, spends time pulling up systems, discovers the renewal date midway through the call, and has no visibility into prior negative interactions. Maria's frustration compounds. She does not renew.
>
> **What happens with this system:** Before the rep speaks, the application presents:
> - Maria's unified profile (policies, payment status, interaction timeline)
> - A risk summary: approaching renewal + negative interaction trend
> - A recommended action: "Acknowledge prior service issues, offer an eligible loyalty adjustment subject to policy rules and representative approval, and confirm that current coverage still meets the customer’s needs"
> - Evidence: links to the two negative transcripts, days-to-renewal count, payment history showing consistent on-time behavior
> - Confidence level and alternative actions
>
> The rep reviews the evidence, decides to follow the recommendation (or adapts it), executes the interaction, and records the outcome. The system logs the decision for future feedback.

---

## 1. Business Problem

Insurance carriers cannot act on a complete picture of their customers during live service interactions. Customer data is fragmented across policy administration, claims management, billing, CRM, and communication systems. When a service representative handles an inbound call, they must manually reconcile information from multiple systems to understand context, assess risk, and determine an appropriate response.

This matters most when the interaction combines urgency signals: a customer who has recently expressed dissatisfaction *and* whose policy renewal is approaching. In this scenario, the representative must make a retention-critical decision under time pressure, without systematic access to the relevant signals.

The core problem: **the absence of a unified customer context layer that synthesizes structured and unstructured signals into an evidence-backed recommended action, presented to a human decision-maker for approval.**

## 2. Current Fragmented Workflow

```
┌─────────────────────────────────────────────────────────────────────────┐
│  CURRENT STATE: Manual Multi-System Reconciliation                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Inbound call received                                                  │
│       │                                                                 │
│       ▼                                                                 │
│  Rep opens Policy Admin System → retrieves active policies              │
│       │                                                                 │
│       ▼                                                                 │
│  Rep opens Claims System → checks open/recent claims                    │
│       │                                                                 │
│       ▼                                                                 │
│  Rep opens Billing System → checks payment status                       │
│       │                                                                 │
│       ▼                                                                 │
│  Rep opens CRM → reads last interaction notes (if time permits)         │
│       │                                                                 │
│       ▼                                                                 │
│  Rep has NO access to transcript sentiment or topic extraction          │
│       │                                                                 │
│       ▼                                                                 │
│  Rep mentally synthesizes → forms subjective recommendation             │
│       │                                                                 │
│       ▼                                                                 │
│  Action taken (or missed) with no audit trail of reasoning              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Observed structural gaps (not quantified — no baseline measurement exists):**
- Context gathering consumes a material portion of interaction time
- Action quality varies by individual rep experience and tenure
- No systematic capture of the reasoning behind an action
- Renewal risk is not surfaced proactively during unrelated service calls
- Unstructured signals (sentiment, escalation language) are not available to the rep

## 3. Personas

### MVP Primary Persona

| Persona | Role | Core Decision | Scenario |
|---------|------|---------------|----------|
| **Customer Service Representative** | Handles inbound calls and service requests | Determine the safest Next Best Action when a customer with negative recent interactions is approaching renewal | Live inbound interaction |

The service representative is the sole user of the MVP. The system exists to support their decision, not to automate it.

### Future Scope Personas (not addressed in MVP)

The following personas represent valid extensions but are explicitly excluded from the initial prototype:

| Persona | Rationale for Deferral |
|---------|----------------------|
| Retention Specialist | Requires proactive outbound workflow, not inbound decision support |
| Agency Principal / Field Agent | Different system access model; requires portal integration |
| Claims Adjuster | Different decision type (claim resolution, not retention) |
| Operations Manager | Requires aggregate analytics and outcome attribution over time |

These personas will be revisited once the core decision-support pattern is validated with the primary user.

## 4. Primary Persona Pain Points

### Customer Service Representative

- Cannot see prior interaction sentiment without reading full transcript histories
- Has no systematic signal that a renewal is approaching during an unrelated service call
- Has no guidance on which action is safest when multiple risk signals coexist
- Relies on personal experience and tribal knowledge for retention-sensitive decisions
- Compliance documentation of decision reasoning is manual and inconsistent
- Cannot distinguish between a routine call and a retention-critical moment without manual investigation

## 5. Proposed Future Workflow

```
┌─────────────────────────────────────────────────────────────────────────┐
│  FUTURE STATE: Human-in-the-Loop Decision Support                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Inbound call received → customer identified                            │
│       │                                                                 │
│       ▼                                                                 │
│  System assembles Customer 360 context:                                 │
│    • Active policies, coverages, renewal dates                          │
│    • Payment behavior signals                                           │
│    • Recent interactions with extracted sentiment and topics             │
│    • Days to next renewal                                               │
│    • Risk signal summary                                                │
│       │                                                                 │
│       ▼                                                                 │
│  NBA Engine scores candidate actions:                                   │
│    • Weighs: negative sentiment recency × renewal proximity             │
│    • Filters by business rules (eligibility, compliance)                │
│    • Ranks by safety (lowest risk of escalation or churn)               │
│       │                                                                 │
│       ▼                                                                 │
│  Rep sees decision-support view:                                        │
│    • Customer context (unified, not a dashboard)                        │
│    • Recommended action with evidence trail                             │
│    • Confidence indicator                                               │
│    • Alternative actions                                                │
│       │                                                                 │
│       ▼                                                                 │
│  Rep reviews → approves / modifies / rejects recommendation             │
│       │                                                                 │
│       ▼                                                                 │
│  Action executed → outcome recorded → feedback loop closes              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Design principles:**
- This is a decision-support application, not a dashboard. It presents a recommendation and waits for human approval.
- Every recommendation is accompanied by evidence (not a black box)
- The human always decides. No action is taken without explicit rep consent.
- Graceful fallback: if AI-derived signals are unavailable, the system still presents available structured context without a recommendation
- Outcome tracking: every accepted/rejected/modified action is logged for future learning

## 6. Business Value Hypothesis

| Value Lever | Mechanism | Testability |
|-------------|-----------|-------------|
| Faster context assembly | Elimination of multi-system manual lookup | Prototype target: measure system render time vs. simulated manual baseline |
| More consistent action quality | Evidence-backed recommendation reduces variance between reps | Requires production A/B; prototype demonstrates the mechanism only |
| Reduced missed retention opportunities | Proactive surfacing of renewal proximity during unrelated calls | Prototype demonstrates signal detection; outcome requires production measurement |
| Decision audit trail | Standardized logging of evidence, recommendation, and rep decision | Structurally verifiable in prototype |
| Graceful degradation under failure | System still useful when AI components are unavailable | Testable in prototype via simulated component failure |

> **Important:** These are hypotheses. The prototype establishes technical feasibility and demonstrates the decision-support mechanism. Business value claims require production deployment, controlled measurement, and sufficient observation time. No outcome improvements are claimed.

## 7. Metrics Framework

### Prototype Targets (measurable within the hackathon deliverable)

| Metric | Target | Label | Measurement Method |
|--------|--------|-------|-------------------|
| Time to render Customer 360 context | < 5 seconds | Prototype target | Application latency instrumentation |
| Data source completeness | All synthetic sources included in 360 assembly | Prototype target | Field population check against synthetic schema |
| Evidence attachment rate | Every NBA recommendation includes at least one contributing signal | Prototype target | Audit log inspection |
| Pipeline freshness | New synthetic interaction reflected in 360 within pipeline cycle | Prototype target | End-to-end latency test with inserted record |
| Fallback behavior | System renders structured context when AI extraction is disabled | Prototype target | Simulated Cortex unavailability test |

### Synthetic Scenario Assumptions (parameters used in demo data)

| Parameter | Value Used | Label | Rationale |
|-----------|-----------|-------|-----------|
| Renewal window threshold | 30 days | Synthetic scenario assumption | Chosen as a configurable prototype parameter for testing renewal-proximity logic; not presented as an industry benchmark |
| Negative sentiment threshold | 2+ negative interactions in 90 days | Synthetic scenario assumption | Chosen to create a meaningful signal without over-triggering; tunable |
| Policies per household | 1-4 | Synthetic scenario assumption | Chosen to test both single-policy and multi-policy customer scenarios |
| Interaction frequency | 1-6 per year per customer | Synthetic scenario assumption | Chosen to test customers with different synthetic interaction volumes |

### Production Measurement Placeholders (not measured in prototype)

| Metric | Validation Approach | Label |
|--------|-------------------|-------|
| Retention rate delta (NBA-guided vs. control) | A/B test with statistical significance | Measurement placeholder |
| Handle time impact | Pre/post measurement with regression control | Measurement placeholder |
| Rep adoption rate | Usage telemetry over observation period | Measurement placeholder |
| Action outcome correlation | Logistic regression on action-type vs. renewal outcome | Measurement placeholder |

> **No industry benchmarks are cited.** Baseline values do not exist for this prototype, and published insurance benchmarks vary too widely by line, geography, and carrier size to be meaningfully referenced without specific citation. Production deployment would establish its own baseline before measuring improvement.

## 8. Insurance-Specific Relevance

### Why Insurance (not generic CRM)

1. **Multi-product relationships are the norm.** A household commonly holds multiple policies across lines (auto, home, umbrella). Each product may be administered separately, creating structural fragmentation.

2. **Long-duration contracts with periodic decision points.** Insurance relationships span years. Renewal dates create natural intervention windows where the right action has disproportionate impact on relationship continuity.

3. **Regulated action requirements.** Insurance communications (non-renewal notices, coverage recommendations) have compliance constraints that an NBA system must encode as hard filters.

4. **Unstructured data carries decision-critical signal.** Call transcripts reveal intent to cancel, dissatisfaction with service, or confusion about coverage — signals that do not exist in structured transaction data.

5. **Asymmetric consequence of inaction.** Losing a multi-policy relationship has compounding revenue impact across lines. The value of correct, timely intervention during a retention-critical moment is structurally high relative to the cost of the intervention.

### Insurance-Specific Signals Used in MVP

| Signal Category | Examples | Decision Relevance |
|----------------|----------|-------------------|
| Renewal proximity | Days to next renewal date | Determines urgency of retention-oriented action |
| Interaction sentiment | Transcript-extracted negative sentiment, escalation language | Indicates relationship risk requiring acknowledgment |
| Payment behavior | Late payment patterns, grace period usage | Lapse risk signal; affects action tone |
| Policy relationship | Number of policies, bundling status | Determines relationship breadth and switching cost |
| Service history | Open complaints, unresolved issues | Indicates whether prior problems need acknowledgment |

## 9. Extension Path to Lending

The architecture uses domain-agnostic patterns that translate to lending (mortgage, auto, personal) with schema extension, not redesign.

| Architecture Layer | Insurance Implementation | Lending Adaptation |
|-------------------|------------------------|-------------------|
| Entity model | Customer → Policies → Coverages | Customer → Loans → Collateral |
| Risk signals | Lapse risk, negative sentiment, renewal proximity | Default risk, DTI changes, rate reset proximity |
| Unstructured processing | Call transcripts, agent notes | Loan officer notes, hardship letters |
| NBA candidates | Acknowledge + retain, adjust terms, escalate to specialist | Refinance offer, forbearance, rate lock |
| Compliance filters | State-specific rules, disclosure requirements | TILA/RESPA timing rules, fair lending constraints |
| Semantic model | Insurance ontology (policy, peril, premium) | Lending ontology (principal, rate, term, LTV) |
| Decision pattern | Human-in-the-loop approval before action | Identical: loan officer approves before execution |

**What stays the same:**
- Customer 360 assembly pattern (structured + unstructured fusion)
- NBA scoring framework (signal weights, evidence trail, confidence)
- Incremental pipeline architecture (streams, dynamic tables, tasks)
- Decision-support application shell and UX pattern
- Human-in-the-loop consent model
- Guardrails and fallback patterns

**What changes:**
- Domain-specific schema tables and seed data
- Signal extraction logic (different features, different thresholds)
- Business rule filters (different regulatory constraints)
- Action library (different intervention types)

## 10. Assumptions and Constraints

### Assumptions

| # | Assumption | Risk if Invalid |
|---|-----------|-----------------|
| A1 | Source systems can be represented by synthetic data with realistic cardinality and referential integrity | Prototype may not surface edge cases present in production data |
| A2 | Snowflake Cortex AI functions (sentiment extraction, summarization) are sufficient for transcript processing without external model hosting | May need external model integration if extraction quality is insufficient |
| A3 | A rule-based NBA scoring engine with configurable signal weights is adequate for the MVP decision | ML-based scoring would require historical outcome data that does not exist for a prototype |
| A4 | The inbound-call scenario (rep responding to a customer-initiated interaction) is the highest-value starting point | Proactive outbound scenarios may have equal or higher value but require different UX |
| A5 | A single Snowflake account with Cortex features enabled is available for development and demonstration | Feature availability varies by region and account tier |

### Constraints

| # | Constraint | Implication |
|---|-----------|-------------|
| C1 | Hackathon scope: prototype, not production system | No real PII, no production integrations, synthetic data only |
| C2 | CoCo CLI is the primary development interface | All artifacts (SQL, Python, YAML, Streamlit) authored and deployed via CoCo |
| C3 | No external compute or services outside Snowflake | All processing uses Snowflake-native capabilities (Cortex, Snowpark, Streamlit-in-Snowflake) |
| C4 | Demonstration must be reproducible from the GitHub repository | All setup must be scriptable; no manual console steps |
| C5 | No real customer data available | Synthetic data must be structurally realistic without representing actual individuals |
| C6 | Single primary persona, single decision scenario | Breadth is explicitly deferred; depth on the core scenario is prioritized |

### Ethical Guardrails

- The system recommends; the human decides. No action is executed without explicit representative approval.
- NBA recommendations exclude discriminatory signals (protected classes are never scoring inputs)
- All AI-generated content (sentiment scores, extracted topics) is labeled as machine-derived with confidence
- Graceful degradation: if AI components fail, the application still renders structured context without a recommendation rather than presenting a low-confidence action
- Decision audit: every recommendation shown, accepted, modified, or rejected is logged with timestamp and evidence snapshot
- Outcome tracking is designed for future learning but does not auto-modify scoring weights without human review

---

_Document version: v2.1. Revised for MVP focus, single-persona scope, removal of unsupported claims, and clarification of synthetic assumptions. Subject to architecture review._