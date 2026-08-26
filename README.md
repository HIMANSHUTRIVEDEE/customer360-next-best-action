# Customer360 AI — Next Best Action Engine

An enterprise-ready decision-support application for insurance customer service. Built entirely on Snowflake using Cortex Code (CoCo) as the primary development interface.

---

## Problem

Insurance service representatives handle inbound calls without a complete picture of the customer. Data is fragmented across policy, claims, billing, and interaction systems. When a customer with negative recent experiences is approaching policy renewal, the rep has no systematic way to identify the risk or determine the safest response.

**Result:** Missed retention opportunities, inconsistent service quality, no audit trail of decision reasoning.

## Solution

A human-in-the-loop decision-support application that:

1. Assembles a unified Customer 360 from structured and unstructured sources
2. Enriches call transcripts with AI-derived sentiment and topics (labeled, not trusted blindly)
3. Computes deterministic risk signals (renewal proximity × negative sentiment trend)
4. Recommends an evidence-backed Next Best Action with confidence level
5. Requires explicit human approval before any action is logged
6. Records decisions with full evidence trail for audit and future learning

**Key distinction:** AI provides indicators. Deterministic rules produce recommendations. Humans decide.

## Target Persona

| Persona | Role in MVP |
|---------|------------|
| **Customer Service Representative** | The sole user. Receives recommendations during inbound interactions. Reviews evidence. Approves, modifies, or rejects. |

Other personas (retention specialist, claims adjuster, field agent, operations manager) are documented for future scope.

## Golden Demo

```
Select customer → Understand context → Explain risk → Recommend action → Approve/create follow-up
```

**Scenario:** Maria Chen — multi-policy household (auto + home). Auto renewal in 14 days. Two recent negative interactions (claim delay complaint, premium inquiry with frustrated tone). Payment history current.

**Expected outcome:** System recommends "Acknowledge prior service issues, offer eligible loyalty adjustment, confirm coverage adequacy" with evidence (2 negative transcripts, renewal countdown, multi-policy flag). Rep approves. Decision logged.

## High-Level Architecture

```
RAW Schema              ANALYTICS Schema              DECISION Schema
(synthetic data)        (enrichment + 360 view)       (immutable audit)
                              │
┌─────────────┐    ┌─────────┴──────────┐    ┌──────────────────┐
│ CUSTOMERS   │    │ INTERACTIONS       │    │ DECISION_LOG     │
│ POLICIES    │───▶│ _ENRICHED (DT)     │    │ (append-only)    │
│ CLAIMS      │    │ Cortex SENTIMENT   │    │                  │
│ PAYMENTS    │    ├────────────────────┤    │ ACTION_OUTCOME   │
│ INTERACTIONS│───▶│ CUSTOMER_360 (DT)  │───▶│ (async)          │
│ TRANSCRIPTS │    │ Pre-aggregated     │    └──────────────────┘
└─────────────┘    │ serving view       │              ▲
                   └────────────────────┘              │
                              │                        │
                   ┌──────────▼──────────┐    ┌───────┴────────┐
                   │ Streamlit App       │    │ Human Approval  │
                   │ Risk Signals (det.) │───▶│ Gate            │
                   │ NBA Engine (det.)   │    │ Accept/Modify/  │
                   │ Evidence Display    │    │ Reject          │
                   └─────────────────────┘    └────────────────┘
```

**3 schemas. 2 dynamic tables. 3 roles. Deterministic scoring. Human approval gate.**

## MVP Features

| # | Feature | Status |
|---|---------|--------|
| 1 | Synthetic structured + unstructured data (100 customers, 500 policies, 50 transcripts) | Planned |
| 2 | Customer 360 dynamic table (pre-aggregated, <5s query) | Planned |
| 3 | Transcript enrichment via Cortex AI (sentiment + topics with provenance) | Planned |
| 4 | Semantic model for natural-language querying | Planned |
| 5 | Explainable risk signals (deterministic, weighted, directional) | Planned |
| 6 | Next Best Action engine (rule-based scoring, eligibility filtering) | Planned |
| 7 | Confidence level + evidence trail per recommendation | Planned |
| 8 | Human review gate (approve/modify/reject — no auto-execution) | Planned |
| 9 | Streamlit-in-Snowflake application (5-step decision-support flow) | Planned |
| 10 | Pipeline automation (dynamic tables, incremental refresh) | Planned |
| 11 | RBAC + dynamic data masking + audit logging | Planned |
| 12 | Testing (pipeline, NBA determinism, RBAC, AI safety, fallback) | Planned |

## CoCo Lifecycle Status

- [x] **Planning** — Complete. Problem, ontology, data model, architecture, security, and scope defined.
- [ ] **Development** — Next. Synthetic data, schema, pipelines, NBA engine, Streamlit app.
- [ ] **Execution** — Pending. End-to-end pipeline, golden demo, deployment.
- [ ] **Testing** — Pending. 14 security tests, pipeline correctness, determinism, fallback.

## Repository Structure

```
customer360-next-best-action/
├── docs/
│   ├── problem-and-impact.md      ← Business problem, personas, value hypothesis
│   ├── solution-design.md         ← MVP scope, acceptance criteria, golden demo
│   ├── ontology.md                ← Business concepts, relationships, decisions
│   ├── data-model.md              ← Logical + physical model, layers, DQ rules
│   ├── architecture.md            ← Simplified architecture, trust boundaries
│   ├── security.md                ← RBAC, masking, AI safety, prompt injection
│   └── coco-lifecycle-evidence.md ← Evidence matrix (30 tracked activities)
├── sql/                           ← Schema DDL, pipelines, semantic model (planned)
├── app/                           ← Streamlit app, NBA engine (planned)
├── data/                          ← Synthetic data generator (planned)
├── tests/                         ← Pipeline, RBAC, AI safety tests (planned)
├── skills/                        ← CoCo reusable skill (bonus)
├── evidence/                      ← Screenshots, planning prompts
└── submission/                    ← Demo script, checklist
```

## Current Progress

**Day 1 — Planning: COMPLETE**

| Artifact | Content | Quality Gate |
|----------|---------|-------------|
| Problem & Impact | Single persona, single decision, no unsupported claims | Revised and verified |
| Solution Design | 12 mandatory items, 12 acceptance criteria, explicit out-of-scope | Reviewed |
| Ontology | 16 concepts, 8 gaps identified and resolved, decision log | Multi-perspective review |
| Data Model | Conceptual → logical → physical, 13 modeling decisions explained | 5-question verification passed |
| Architecture | Simplified for 6-day build, trust boundaries, fallback ladder | Critique applied |
| Security | 4 roles, masking, prompt-injection defense, 14 Day-6 tests | Controls specified |
| Evidence Matrix | 30 activities tracked across 4 phases | Planning phase populated |

## Next Milestone

**Development Phase — Synthetic Data + Schema + Enrichment Pipeline**

1. Generate synthetic data (Python script, golden demo scenario seeded)
2. Create RAW, ANALYTICS, DECISION schemas with all tables
3. Load data into RAW
4. Create INTERACTIONS_ENRICHED dynamic table (Cortex sentiment)
5. Create CUSTOMER_360 dynamic table (pre-aggregated serving view)
6. Validate pipeline end-to-end

---

*Built for the Snowflake CoCo CLI Hackathon. Deadline: 30 August 2026.*
