\-- PROMPT 1 - CoCo context prompt



Read the approved planning documents:



@docs/problem-and-impact.md

@docs/solution-design.md

@docs/ontology.md

@docs/data-model.md

@docs/architecture.md

@docs/security.md

@docs/coco-lifecycle-evidence.md



We are beginning Day 2: Synthetic Data and Secure Snowflake Foundation.



Use these approved MVP physical schemas:



RAW

ANALYTICS

DECISION



Day 2 scope is limited to:



1\. Synthetic scenario catalogue

2\. Deterministic synthetic source-data generation

3\. Local data validation

4\. Secure Snowflake database, warehouse, schemas and roles

5\. RAW tables, stage, file format and data loading

6\. Source-to-target reconciliation

7\. RAW data-quality testing

8\. RBAC and privacy validation

9\. CoCo evidence capture



Do not create:



\- Dynamic tables

\- Cortex enrichment

\- Customer 360

\- Semantic views

\- Risk scoring

\- NBA logic

\- Streamlit application



First, inspect the repository and return:



\- Relevant approved entities

\- Required source files

\- Required Day 2 scripts

\- Important data-quality rules

\- Security constraints

\- Potential contradictions



Do not modify files or execute Snowflake statements yet.





\--- PROMPT 2 - Inspect the Snowflake environment safely



Inspect my current Snowflake environment using read-only queries.



Return:



\- CURRENT\_USER()

\- CURRENT\_ROLE()

\- CURRENT\_WAREHOUSE()

\- CURRENT\_DATABASE()

\- CURRENT\_SCHEMA()

\- Available project-related roles

\- Privileges relevant to creating databases, warehouses, schemas, roles,

&#x20; stages, file formats, tables and masking policies

\- Whether CUSTOMER360\_DB and CUSTOMER360\_WH already exist

\- Account edition or feature limitations relevant to masking policies



Do not create, alter, grant or drop anything.

Do not display credentials, connection strings or secrets.



\--- PROMPT 3 - Freeze object names



Database:

CUSTOMER360\_DB



Warehouse:

CUSTOMER360\_WH



Schemas:

RAW

ANALYTICS

DECISION



Roles:

C360\_ADMIN

C360\_DATA\_ENGINEER

C360\_SERVICE\_APP

C360\_AUDITOR



\--- Create the scenario catalogue



Review these proposed object names against the approved architecture and

security design.



Produce a concise access matrix covering:



\- Database and schema ownership

\- Warehouse usage

\- RAW read/write access

\- ANALYTICS future read/write access

\- DECISION insert/read access

\- Stage and file-format access

\- Masking-policy ownership

\- Explicitly prohibited privileges



Do not execute anything.



\---



Create data/scenarios/scenario-catalog.md.



Define 12 synthetic scenarios supporting the approved golden demo and

later pipeline tests:



1\. Maria Chen golden-demo scenario

2\. Approaching renewal with negative interactions

3\. Approaching renewal with positive interactions

4\. Negative interactions outside the renewal window

5\. No recent interactions

6\. Interaction without transcript

7\. Transcript without recording consent

8\. Repeated late payments

9\. Unresolved complaint

10\. Single-policy customer

11\. Multi-policy customer

12\. Contradictory risk signals



For each scenario include:



\- scenario\_id

\- category: positive, negative or edge case

\- business purpose

\- customer and household requirements

\- policy requirements

\- claim and payment requirements

\- interaction requirements

\- transcript requirements

\- expected downstream signal behavior

\- expected fallback behavior



Expected signals and recommendations are test expectations only.

Do not place expected NBA outcomes in production-style source files.

All values and distributions must be labeled synthetic prototype

assumptions, not insurance-industry benchmarks.



\---





Using:



@docs/ontology.md

@docs/data-model.md

@data/scenarios/scenario-catalog.md



Create data/scenarios/generation-specification.md.



Define these source datasets:



\- customers

\- policies

\- coverages

\- claims

\- payments

\- interactions

\- transcripts

\- service\_representatives



For every dataset document:



\- Exact grain

\- Primary identifier

\- Foreign-key relationships

\- Required columns

\- Nullable columns

\- Allowed enumeration values

\- Date and timestamp rules

\- Cardinality assumptions

\- Scenario dependencies

\- Synthetic row-count target

\- Validation rules



Household attributes may be embedded in customers for source generation,

matching the approved source-to-target design.



Do not include enrichments, risk signals, recommendations, follow-ups or

outcomes as source datasets.



\---



Create a deterministic synthetic-data generator.



Output:

data/generate\_synthetic.py



Generated files:

data/generated/customers.csv

data/generated/policies.csv

data/generated/coverages.csv

data/generated/claims.csv

data/generated/payments.csv

data/generated/interactions.csv

data/generated/transcripts.csv

data/generated/service\_representatives.csv

data/generated/scenario\_expectations.csv

data/generated/manifest.json



Requirements:



\- Entirely fictional data

\- Fixed documented random seed

\- UTF-8 output

\- Stable identifiers across repeated runs

\- Referential consistency

\- Maria Chen explicitly labeled synthetic

\- Synthetic example.com email addresses

\- Reserved fictional phone-number patterns

\- Positive, neutral and negative transcript content

\- recording\_consent\_flag included

\- Interactions without transcripts included

\- Missing-data and contradictory-signal scenarios included

\- No protected characteristics used as risk or recommendation inputs

\- No generated enrichment, risk score or NBA in source files

\- Re-running the generator produces identical output

\- Manifest records seed, filenames, row counts and SHA-256 checksums



Execute the generator locally after creating it.

Do not upload data to Snowflake yet.



\----





Create and execute a local validation script:



data/validate\_synthetic.py



Validate:



\- Required files exist

\- Manifest matches generated files

\- Primary identifiers are unique

\- Customer foreign keys are valid

\- Policy foreign keys are valid

\- Claim and payment policy/customer relationships agree

\- Every transcript references an interaction

\- At most one transcript exists per interaction

\- Active policies have at least one coverage

\- Policy effective\_date precedes expiration\_date

\- Payment amounts are positive

\- Enumerations contain only approved values

\- recording\_consent\_flag is populated

\- word\_count matches transcript text

\- Every scenario is represented

\- Maria Chen's complete golden-demo graph exists

\- No source file contains expected NBA or derived sentiment fields

\- Repeated generation produces identical checksums

\- No credential-like strings or obvious real personal data are present



Generate:

data/generated/validation-report.json

evidence/development/day-2/validation-results.md



Do not silently repair failures.

Return PASS or FAIL for every check.



\--- 



Create these idempotent scripts:



sql/00\_setup/01\_roles.sql

sql/00\_setup/02\_database\_warehouse.sql

sql/00\_setup/03\_schemas.sql

sql/07\_security/01\_grants.sql



Use:



CUSTOMER360\_DB

CUSTOMER360\_WH

RAW

ANALYTICS

DECISION



Roles:



C360\_ADMIN

C360\_DATA\_ENGINEER

C360\_SERVICE\_APP

C360\_AUDITOR



Requirements:



\- Least privilege

\- No grants to PUBLIC

\- No hard-coded users

\- No credentials or account identifiers

\- X-Small development warehouse unless an approved warehouse already exists

\- Auto-suspend enabled

\- DATA\_ENGINEER can load and manage RAW

\- SERVICE\_APP cannot access RAW directly

\- SERVICE\_APP receives only future application privileges needed later

\- AUDITOR has no write privileges

\- DECISION is append-only for the future application role

\- Every object has a comment

\- Clearly identify the administrative role required for each section

\- Do not execute any script yet



\---



Review the generated setup and grant scripts as a Snowflake security

architect.



Check for:



\- PUBLIC access

\- ALL PRIVILEGES

\- Excessive OWNERSHIP

\- Role inheritance risks

\- Missing parent USAGE privileges

\- Dangerous future grants

\- Human users receiving service roles

\- DATA\_ENGINEER access to decision records

\- AUDITOR write access

\- SERVICE\_APP access to RAW

\- Non-idempotent statements

\- Warehouse cost-control omissions

\- Secret exposure



Correct the files and show the final diff.

Do not execute them.



\---





Create:



sql/01\_raw/01\_raw\_tables.sql



Create these RAW tables:



RAW\_CUSTOMERS

RAW\_POLICIES

RAW\_COVERAGES

RAW\_CLAIMS

RAW\_PAYMENTS

RAW\_INTERACTIONS

RAW\_TRANSCRIPTS

RAW\_SERVICE\_REPRESENTATIVES



Requirements:



\- Match generated CSV headers exactly

\- Preserve source-level grain

\- Use appropriate Snowflake data types

\- Do not create derived sentiment or NBA fields

\- Include:

&#x20; \_loaded\_at

&#x20; \_source\_file

&#x20; \_batch\_id

&#x20; \_row\_hash

\- Declare logical keys for documentation where appropriate

\- Add comments to tables and columns

\- Do not assume Snowflake enforces referential integrity

\- Make the script safely rerunnable

\- Do not execute yet



\---



Create:



sql/01\_raw/02\_stage\_file\_format.sql

sql/01\_raw/03\_load\_raw.sql

sql/01\_raw/04\_reconciliation.sql



Requirements:



\- Named internal stage

\- UTF-8 CSV file format

\- Header handling

\- Explicit column mapping

\- Safe error reporting

\- Batch identifier

\- Source filename capture

\- Row-hash population

\- Idempotent reload behavior

\- Source-manifest to target-row reconciliation

\- Rejected-row visibility

\- No CONTINUE-on-error behavior that hides failures



Do not execute yet.



\---



Create:



sql/08\_tests/01\_raw\_data\_quality.sql



Return one PASS or FAIL row for each test:



\- Source and target row counts match

\- No duplicate primary identifiers

\- No orphan customer references

\- No orphan policy references

\- Claim customer matches policy customer

\- Payment customer matches policy customer

\- Transcript interaction exists

\- One transcript maximum per interaction

\- Active policies have coverage

\- Valid policy dates

\- Positive payment amounts

\- Valid enumerations

\- Consent flag populated

\- Audit columns populated

\- Golden-demo graph complete

\- All scenario IDs represented

\- No load errors



Do not execute yet.



\----



Review all Day 2 generated artifacts against the approved Day 1 design.



Return PASS, PARTIAL or FAIL for:



\- Entity coverage

\- Grain consistency

\- Referential integrity

\- Scenario coverage

\- Golden-demo completeness

\- Privacy

\- Reproducibility

\- Idempotency

\- Least privilege

\- Raw-table fidelity

\- Load reconciliation

\- No premature Day 3 or Day 4 implementation



Do not execute Snowflake statements during this review.



\---



&#x20;Execute sql/00\_setup/01\_roles.sql only.



&#x20; Before execution:

&#x20; - Show the current user and role.

&#x20; - List the objects affected.

&#x20; - Show the statements to be executed.



&#x20; Stop on the first error.

&#x20; Do not modify the script.

&#x20; Do not broaden privileges.

&#x20; Return results and query IDs.



\---

Execute the reviewed Day 2 scripts in dependency order.



&#x20; Before each script:



&#x20; 1. State the active role.

&#x20; 2. State the objects affected.

&#x20; 3. Show the script path.

&#x20; 4. Stop if execution fails.

&#x20; 5. Record query IDs and results.

&#x20; 6. Do not execute unrelated statements.

&#x20; 7. Do not broaden privileges to bypass an error.



&#x20; After loading, execute reconciliation and data-quality tests.





&#x20;Resume the previous execution was cancelled during Script 7.



&#x20; Scripts 1 through 6 completed successfully. Do not rerun them.



&#x20; Resume in this order:



&#x20; 7. sql/01\_raw/03\_load\_raw.sql

&#x20; 8. sql/01\_raw/04\_reconciliation.sql

&#x20; 9. sql/08\_tests/01\_raw\_data\_quality.sql



&#x20; Re-read the updated sql/01\_raw/03\_load\_raw.sql before execution.



&#x20; Before each script:



&#x20; 1. State the active role.

&#x20; 2. State the objects affected.

&#x20; 3. Show the script path.

&#x20; 4. Show the exact statements to be executed.

&#x20; 5. Do not modify the script.

&#x20; 6. Do not execute unrelated statements.

&#x20; 7. Do not broaden privileges to bypass an error.



&#x20; For Script 7:



&#x20; 1. Confirm the active role is C360\_DATA\_ENGINEER.

&#x20; 2. Execute each PUT statement individually.

&#x20; 3. Stop immediately if any PUT fails.

&#x20; 4. Run LIST and confirm all eight expected CSV files are staged.

&#x20; 5. Only after successful stage verification, execute the TRUNCATE and

&#x20;    COPY INTO statements.

&#x20; 6. Stop immediately if any COPY fails.

&#x20; 7. Record query IDs, filenames, load status and loaded row counts.



&#x20; After Script 7 succeeds:



&#x20; 1. Execute 04\_reconciliation.sql.

&#x20; 2. Continue only if reconciliation passes.

&#x20; 3. Execute 01\_raw\_data\_quality.sql.

&#x20; 4. Return PASS or FAIL for loading, reconciliation and data quality.

&#x20; 5. Include all failures and query IDs in the final summary.





\---





Script 7 failed because SHA2 is not supported inside a COPY INTO

&#x20; transformation.



&#x20; Update @sql/01\_raw/03\_load\_raw.sql using a two-step load pattern.



&#x20; For each of the eight RAW tables:



&#x20; 1. Keep the existing TRUNCATE statement.

&#x20; 2. In COPY INTO, replace the SHA2 expression for \_row\_hash with:

&#x20;    NULL

&#x20; 3. Immediately after the COPY succeeds, add an UPDATE statement that

&#x20;    calculates \_row\_hash using the original SHA2(CONCAT\_WS(...), 256)

&#x20;    expression against the loaded table columns.

&#x20; 4. Add a validation query confirming:

&#x20;    - expected rows were loaded;

&#x20;    - \_row\_hash contains no NULL values;

&#x20;    - hashes have the expected SHA-256 hexadecimal length.

&#x20; 5. Preserve:

&#x20;    - explicit PUT statements;

&#x20;    - forward-slash Windows file paths;

&#x20;    - LIST stage verification;

&#x20;    - batch ID;

&#x20;    - \_loaded\_at;

&#x20;    - \_source\_file;

&#x20;    - ON\_ERROR = 'ABORT\_STATEMENT';

&#x20;    - PURGE = FALSE.

&#x20; 6. Do not replace SHA2 with MD5.

&#x20; 7. Do not change table definitions, CSV mappings, grants, roles or

&#x20;    unrelated files.

&#x20; 8. Show the complete diff and perform a syntax review.

&#x20; 9. Do not execute the revised script yet.



\--



Execute the corrected sql/01\_raw/03\_load\_raw.sql from the beginning.



&#x20; The previous run stopped during the first COPY after truncating

&#x20; RAW\_SERVICE\_REPRESENTATIVES.



&#x20; Requirements:



&#x20; 1. Confirm C360\_DATA\_ENGINEER is active.

&#x20; 2. Confirm all eight files exist on the internal stage.

&#x20; 3. Execute one table section at a time:

&#x20;    TRUNCATE → COPY INTO → UPDATE SHA2 → validation.

&#x20; 4. Stop immediately on any failure.

&#x20; 5. Record COPY row counts, hash-validation results and query IDs.

&#x20; 6. Do not modify the script during execution.

&#x20; 7. Run reconciliation only after all eight table sections pass.

&#x20; 8. Run RAW data-quality tests only after reconciliation passes.



\-- 

Execute Day 2 RBAC tests.



&#x20; Verify:



&#x20; - C360\_DATA\_ENGINEER can load RAW.



&#x20; - C360\_SERVICE\_APP cannot SELECT from RAW.



&#x20; - C360\_SERVICE\_APP cannot INSERT, UPDATE or DELETE RAW.



&#x20; - C360\_AUDITOR cannot modify RAW, ANALYTICS or DECISION.



&#x20; - PUBLIC has no project database privileges.



&#x20;  - C360\_DATA\_ENGINEER cannot read future decision records.



&#x20;  - Only the approved administrative role can manage grants.



&#x20;  - Stages cannot be used by SERVICE\_APP or AUDITOR.



&#x20;  Record expected result, actual result and PASS/FAIL for every test.



&#x20;  Do not add privileges merely to make a test pass.



\---



Update README.md for Day 2.



Add:

\- Synthetic-data overview

\- Scenario catalogue

\- Snowflake schema layers

\- Security role summary

\- Reproduction instructions

\- Validation status

\- CoCo lifecycle progress



Mark Planning complete.

Mark Development in progress.

Do not claim that Customer 360, AI enrichment or Streamlit are complete.

