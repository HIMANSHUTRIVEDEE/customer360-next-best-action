# CoCo Lifecycle Evidence Matrix

This document tracks every phase of the project lifecycle, demonstrating that Cortex Code (CoCo) was the primary development interface throughout planning, development, execution, and testing.

---

## Evidence Legend

| Column | Description |
|--------|-------------|
| **Phase** | Lifecycle stage: Planning, Development, Execution, Testing |
| **Activity** | What was done |
| **CoCo Prompt** | Summarized prompt that initiated the activity |
| **Generated Artifact** | File or object produced |
| **Execution Evidence** | How the output was validated |
| **Screenshot** | Reference to screenshot in `evidence/` directory |
| **Git Commit** | Commit hash or "pending" |
| **Status** | Done, In Progress, Planned |

---

## Planning Phase

| Phase | Activity | CoCo Prompt | Generated Artifact | Execution Evidence | Screenshot | Git Commit | Status |
|-------|----------|-------------|-------------------|-------------------|------------|------------|--------|
| Planning | Project initialization and charter | "We are building an enterprise-ready Customer 360 and Next Best Action Engine..." | Repository structure, README.md | Repo created with docs/, app/, sql/, tests/, evidence/ directories | `evidence/planning/01-coco-status.png` | `e8686d8` | Done |
| Planning | Problem statement and impact definition | "Create docs/problem-and-impact.md..." | `docs/problem-and-impact.md` | Peer-reviewed for unsupported claims; revised to single-persona MVP scope with explicit metric labeling | `evidence/planning/03-project-charter.png` | pending | Done |
| Planning | MVP scope and acceptance criteria | "Create the MVP scope section in docs/solution-design.md..." | `docs/solution-design.md` | 12 acceptance criteria defined; golden demo scenario specified; scope boundaries verified | — | pending | Done |
| Planning | Business ontology | "Create docs/ontology.md for the Customer 360 and Next Best Action solution..." | `docs/ontology.md` | Gap analysis (8 gaps identified and resolved); multi-perspective review (servicing, retention, underwriting, privacy, explainability, outcome measurement) | — | pending | Done |
| Planning | Data model design | "Using docs/ontology.md, create docs/data-model.md..." | `docs/data-model.md` | Verified: interaction history preserved, recommendation traceable to evidence, outcomes usable for evaluation, AI values cannot overwrite source, incremental processing supported | — | pending | Done |
| Planning | Architecture design and critique | "Create docs/architecture.md... Critique this architecture for excessive complexity..." | `docs/architecture.md` | Simplified from 6 schemas to 3, 4 pipeline stages to 2, SCD2 deferred; demo risks mitigated; trust boundaries explicit | — | pending | Done |
| Planning | Security controls | "Create docs/security.md containing least-privilege roles, masking, prompt-injection defenses..." | `docs/security.md` | 14 security tests specified for Day 6; RBAC, masking, AI validation, consent, fallback controls defined | — | pending | Done |
| Planning | Lifecycle evidence matrix | "Update docs/coco-lifecycle-evidence.md..." | `docs/coco-lifecycle-evidence.md` (this file) | Matrix structure established; planning phase populated | — | pending | Done |

---

## Development Phase

| Phase | Activity | CoCo Prompt | Generated Artifact | Execution Evidence | Screenshot | Git Commit | Status |
|-------|----------|-------------|-------------------|-------------------|------------|------------|--------|
| Development | Synthetic data generation | Generate Python script producing realistic insurance data for golden demo scenarios | `data/generate_synthetic.py` | Script executes idempotently; output matches schema in data-model.md; Maria Chen scenario seeded | — | — | Planned |
| Development | Schema DDL creation | Create all tables in RAW, ANALYTICS, DECISION schemas per architecture.md | `sql/01_schema.sql` | DDL executes without error; tables visible in SHOW TABLES | — | — | Planned |
| Development | Data loading | Load synthetic CSV data into RAW tables via COPY INTO | `sql/02_load_data.sql` | Row counts match generator output; referential integrity passes DQ checks | — | — | Planned |
| Development | Transcript enrichment pipeline | Create dynamic table INTERACTIONS_ENRICHED with Cortex SENTIMENT and topic extraction | `sql/03_enrichment.sql` | All transcripts with consent=TRUE have sentiment scores; failed enrichments have error_message | — | — | Planned |
| Development | Customer 360 dynamic table | Create CUSTOMER_360 dynamic table joining all sources with pre-aggregation | `sql/04_customer_360.sql` | Every customer in RAW has a row in 360 view; golden demo customer has correct aggregates | — | — | Planned |
| Development | RBAC and masking setup | Create roles, grants, and masking policies per security.md | `sql/05_rbac.sql` | Security tests T1-T7 pass | — | — | Planned |
| Development | Semantic model | Author Cortex Analyst YAML for Customer 360 domain | `sql/06_semantic_model.yaml` | `cortex reflect` passes without errors; verified questions return expected results | — | — | Planned |
| Development | NBA engine logic | Implement deterministic risk scoring + action ranking in Python | `app/nba_engine.py` | Unit tests: golden demo input → expected action; edge cases produce sensible output | — | — | Planned |
| Development | Streamlit application | Build 5-step decision-support UI | `app/streamlit_app.py` | App deploys via `snow streamlit deploy`; golden demo flow completes end-to-end | — | — | Planned |
| Development | Decision logging | Implement DECISION_LOG writes on approval/modify/reject | `app/decision_logger.py` | Decision appears in DECISION_LOG with correct fields after rep action | — | — | Planned |

---

## Execution Phase

| Phase | Activity | CoCo Prompt | Generated Artifact | Execution Evidence | Screenshot | Git Commit | Status |
|-------|----------|-------------|-------------------|-------------------|------------|------------|--------|
| Execution | End-to-end pipeline run | Execute full pipeline: load → enrich → 360 → verify | Pipeline execution log | All dynamic tables healthy; 360 view populated; enrichment complete | — | — | Planned |
| Execution | Golden demo walkthrough | Run the 5-step flow for Maria Chen | Demo recording / screenshots | All 5 steps complete; recommendation matches expected action; evidence displayed | — | — | Planned |
| Execution | Incremental processing demo | Insert new interaction → verify 360 updates within 1 DT cycle | SQL insert + query verification | New interaction appears in 360 view after refresh | — | — | Planned |
| Execution | Fallback demonstration | Disable enrichment → verify graceful degradation | UI screenshot showing fallback state | Structured 360 renders; "AI unavailable" banner shown; no recommendation panel | — | — | Planned |
| Execution | Streamlit deployment | Deploy to Snowflake via CoCo | Deployed Streamlit app object | `SHOW STREAMLITS` returns app; accessible via URL | — | — | Planned |

---

## Testing Phase

| Phase | Activity | CoCo Prompt | Generated Artifact | Execution Evidence | Screenshot | Git Commit | Status |
|-------|----------|-------------|-------------------|-------------------|------------|------------|--------|
| Testing | Pipeline correctness tests | Verify enrichment produces non-null sentiment; 360 aggregates are correct | `tests/test_pipeline.sql` | All assertions pass | — | — | Planned |
| Testing | NBA determinism tests | Verify golden demo → expected action; edge cases handled | `tests/test_nba_logic.py` | All unit tests pass | — | — | Planned |
| Testing | RBAC boundary tests | Verify role restrictions per security.md T1-T7 | `tests/test_rbac.sql` | All access-denied assertions pass | — | — | Planned |
| Testing | AI safety tests | Verify prompt injection defense, output validation, consent enforcement | `tests/test_ai_safety.sql` | Tests T8-T11 pass | — | — | Planned |
| Testing | Fallback behavior test | Verify app degrades gracefully when enrichment unavailable | `tests/test_fallback.sql` | Structured 360 renders; no recommendation when confidence = Low | — | — | Planned |
| Testing | Secrets hygiene test | Verify no credentials in repository | `tests/test_secrets.sh` | `git grep` returns no matches for secret patterns | — | — | Planned |
| Testing | Reproducibility test | Run full setup from clean account | Setup script execution log | All scripts execute idempotently; app accessible after fresh deploy | — | — | Planned |

---

## Summary Counts

| Phase | Total Activities | Done | In Progress | Planned |
|-------|-----------------|------|-------------|---------|
| Planning | 8 | 8 | 0 | 0 |
| Development | 10 | 0 | 0 | 10 |
| Execution | 5 | 0 | 0 | 5 |
| Testing | 7 | 0 | 0 | 7 |
| **Total** | **30** | **8** | **0** | **22** |

---

*Document version: v1 — Planning phase populated. Development, Execution, and Testing phases to be updated as work proceeds.*
