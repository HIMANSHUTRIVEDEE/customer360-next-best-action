\--Prompt 1 - CoCo the project charter



We are building an enterprise-ready Customer 360 and Next Best Action

Engine for the Snowflake CoCo CLI Hackathon.



Business context:

Insurance organizations have customer information across customer,

policy, coverage, claim, payment and servicing systems. Important context

also exists in call transcripts, emails and agent notes.



Required experience:

A user selects or asks about a customer, receives a unified Customer 360

view, understands recent interactions and risk signals, and receives an

evidence-backed Next Best Action in one experience.



Required CoCo demonstration:

\- Planning, development, execution, testing and validation

\- Synthetic data generation

\- Data pipelines and incremental processing

\- Semantic model and ontology

\- Unstructured document/transcript processing

\- Streamlit application

\- Automation

\- Guardrails and graceful fallback

\- Preferably a reusable skill, multi-agent orchestration and one action tool



Judging focus:

\- Real World Relevance

\- Technical Execution

\- Solution Completeness



Submission requires:

\- Problem brief

\- Architecture diagram

\- Impact statement

\- Public GitHub repository

\- Working prototype



For this session, perform planning only. Do not create implementation code

until the planning artifacts have been reviewed.

Acknowledge the constraints and propose the planning sequence.





\--Prompt 2 - Frame the business problem



Act as an insurance-domain strategist and enterprise solution architect.



Create docs/problem-and-impact.md.



Include:

1\. Precise business problem

2\. Current fragmented workflow

3\. Primary and secondary personas

4\. Persona pain points

5\. Proposed future workflow

6\. Business value hypothesis

7\. Measurable target metrics without inventing results

8\. Insurance-specific relevance

9\. How the architecture can later extend to lending

10\. Assumptions and constraints



Clearly distinguish measured results from target outcomes.



\-- Prompt 2 - Frame the business problem



Critically revise docs/problem-and-impact.md.



&#x20; Required changes:



&#x20; 1. Establish the customer service representative as the single primary

&#x20;    MVP user.

&#x20; 2. Define one principal servicing decision:

&#x20;    determine the safest Next Best Action during an inbound interaction

&#x20;    involving negative interactions and an approaching renewal.

&#x20; 3. Move claims-adjuster, agency-principal and operations-manager scenarios

&#x20;    to future scope.

&#x20; 4. Describe the solution as a human-in-the-loop decision-support and

&#x20;    action application, not as a dashboard.

&#x20; 5. Review every number, percentage, range and benchmark.

&#x20; 6. Retain a number only when it is explicitly labeled as:

&#x20;    - a prototype target,

&#x20;    - a synthetic scenario assumption,

&#x20;    - a measurement placeholder, or

&#x20;    - an externally sourced benchmark with a citation.

&#x20; 7. Remove unsupported factual language and uncited industry benchmarks.

&#x20; 8. Preserve evidence, confidence, consent, human approval, fallback and

&#x20;    outcome tracking.

&#x20; 9. Add a concise MVP decision statement and golden demo scenario near

&#x20;    the beginning.

&#x20; 10. Do not add new unsupported claims.



\-- Prompt 3 - Freeze the MVP



Create the MVP scope section in docs/solution-design.md.



The solution must be achievable by 30 August.



Divide requirements into:

1\. Mandatory MVP

2\. High-value bonus

3\. Explicitly out of scope



The mandatory MVP must include:

\- Synthetic structured and unstructured data

\- Customer 360

\- Transcript enrichment

\- Semantic model

\- Explainable churn indicators

\- Next Best Action

\- Confidence and evidence

\- Human review

\- Streamlit

\- Automation

\- RBAC and auditability

\- Testing



Do not make MCP, Slack, Jira or predictive ML dependencies of the MVP.

Define a specific golden demo scenario and acceptance criteria.



\-- Prompt 3 - Freeze the MVP follow up



Critically revise docs/problem-and-impact.md.



&#x20; Required changes:



&#x20; 1. Establish the customer service representative as the single primary

&#x20;    MVP user.

&#x20; 2. Define one principal servicing decision:

&#x20;    determine the safest Next Best Action during an inbound interaction

&#x20;    involving negative interactions and an approaching renewal.

&#x20; 3. Move claims-adjuster, agency-principal and operations-manager scenarios

&#x20;    to future scope.

&#x20; 4. Describe the solution as a human-in-the-loop decision-support and

&#x20;    action application, not as a dashboard.

&#x20; 5. Review every number, percentage, range and benchmark.

&#x20; 6. Retain a number only when it is explicitly labeled as:

&#x20;    - a prototype target,

&#x20;    - a synthetic scenario assumption,

&#x20;    - a measurement placeholder, or

&#x20;    - an externally sourced benchmark with a citation.

&#x20; 7. Remove unsupported factual language and uncited industry benchmarks.

&#x20; 8. Preserve evidence, confidence, consent, human approval, fallback and

&#x20;    outcome tracking.

&#x20; 9. Add a concise MVP decision statement and golden demo scenario near

&#x20;    the beginning.

&#x20; 10. Do not add new unsupported claims.



&#x20; After editing, provide a change summary and run the same four-question

&#x20; quality review again.



\-- Prompt 4 - Generate the ontology



Act as an insurance ontologist.



Create docs/ontology.md for the Customer 360 and Next Best Action solution.



Do not begin with database tables. First define:



1\. Business concepts

2\. Definitions

3\. Relationships

&#x20;4. Cardinalities

&#x20;5. Important business rules

&#x20;6. Customer and interaction lifecycle

&#x20;7. Recommendation and action lifecycle

&#x20;8. Consent and communication preferences

&#x20;9. Evidence supporting a recommendation

&#x20;10. Action outcome and feedback loop

&#x20;

&#x20;Consider, but do not blindly assume:

&#x20;Customer, Household, Policy, Coverage, Claim, Payment, Interaction,

&#x20;Transcript, Agent, Complaint, Consent, Risk Signal, Recommendation,

&#x20;Business Action and Action Outcome.

&#x20;

&#x20;Challenge unnecessary concepts and identify missing concepts.

&#x20;Include a Mermaid relationship diagram.





Review the ontology from the perspectives of: 



\- Customer servicing 



\- Retention 



\- Underwriting relevance 



\- Privacy 



\- Recommendation explainability 



\- Action outcome measurement 



Identify gaps, correct the ontology and document major decisions. 



\-- Prompt 5 - Derive the data model from the ontology



Using docs/ontology.md, create docs/data-model.md. 



Produce: 



1\. Conceptual model 



2\. Logical model 



3\. Proposed physical Snowflake model 



4\. Entity grain 



5\. Business and surrogate keys 



6\. Relationships 



&#x20;7. Slowly changing dimensions where justified 



&#x20;8. Fact and dimension candidates 



&#x20;9. Raw, curated, AI-enriched and serving layers 



&#x20;10. Customer 360 serving structure 



&#x20;11. Recommendation and action history 



&#x20;12. Source-to-target outline 



&#x20;13. Data-quality rules 



&#x20;14. Audit and lineage columns 



&#x20;Do not generate executable DDL today. 



&#x20;Explain each important modeling decision.

&#x20;

&#x20;

&#x20;Does the model preserve interaction history? 



&#x20;Can every recommendation be traced to evidence? 



&#x20;Can action outcomes be used for future evaluation? 



&#x20;Does the model prevent AI-generated values from overwriting source facts? 



&#x20;Does it support incremental processing? 

&#x20;

\-- Prompt 5 - Design the architecture and workflow



Create docs/architecture.md. 



Design a Snowflake-native architecture covering: 



\- Synthetic data generation 



\- Raw ingestion 



\- Curated dimensional model 



\- Streams, tasks and dynamic tables 



\- Transcript enrichment 



&#x20;- Customer 360 



&#x20;- Semantic views and verified questions 



&#x20;- AI analysis 



&#x20;- Next Best Action policy layer 



&#x20;- Streamlit application 



&#x20;- Action execution 



&#x20;- Monitoring, audit and testing 



&#x20;- RBAC, masking and consent controls 

&#x20; 



&#x20;Separate deterministic business rules from generative AI. 



&#x20;Show trust boundaries and human approval. 



&#x20;Include: 



&#x20;1. Component responsibilities 



&#x20;2. End-to-end data flow 



&#x20;3. Incremental real time workflow 



&#x20;4. Mermaid architecture diagram 



&#x20;5. Failure and fallback paths 



&#x20;6. CoCo involvement in each lifecycle phase

&#x20;

&#x20;Critique this architecture for: 



\- Excessive complexity for a six-day build 



\- Missing dependencies 



\- Security gaps 



\- Unsupported AI decisions 



\- Poor explainability 



\- Demo risks 



Simplify it while retaining enterprise credibility. 



\-- Prompt 6 - Create the security blueprint



Act as a Snowflake security architect. 



Create docs/security.md containing: 



\- Least-privilege roles 



\- Access-role hierarchy 



\- Service and human roles 



\- Classification and masking requirements 



\- Consent-aware outreach 



&#x20;- Raw transcript access restrictions 



&#x20;- Audit fields 



&#x20;- Secrets-management rules 



&#x20;- Prompt-injection defenses for transcript text 



&#x20;- AI output validation 



&#x20;- Human approval requirements 



&#x20;- Low-confidence fallback 



&#x20;- Data retention considerations 



&#x20;- Security tests for Day 6 



&#x20;Describe controls at planning level only; do not generate SQL yet.



\-- Prompt 7 - Document CoCo lifecycle evidence

&#x20;

