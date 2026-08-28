/*==============================================================================
  CUSTOMER360 — AUTOMATION: CUSTOMER 360 REFRESH TASK
  Schema: CUSTOMER360_DB.ANALYTICS
  Pattern: Scheduled task to refresh serving-layer objects

  Purpose:
    Periodically refreshes DT_CUSTOMER360 (and future downstream dynamic
    tables) so the customer-facing serving layer stays reasonably current
    without manual intervention.

  Schedule:
    - Every 4 hours (6 runs/day).
    - At XS warehouse size this produces negligible credit consumption
      (~6 × ~5 seconds = ~30 seconds of XS compute per day).
    - For hackathon demos, manually run:
        EXECUTE TASK CUSTOMER360_DB.ANALYTICS.TASK_REFRESH_CUSTOMER360;
      to trigger an immediate refresh without waiting for the schedule.

  Cost Controls:
    - ALLOW_OVERLAPPING_EXECUTION = FALSE prevents pile-up if a run
      exceeds the interval (unlikely at this data scale).
    - USER_TASK_TIMEOUT_MS = 300000 (5 min) hard-kills runaway refreshes.
    - Warehouse: C360_TRANSFORM_WH (XS, auto-suspend 60s).

  Note:
    - Task is created in SUSPENDED state. Resume with:
        ALTER TASK CUSTOMER360_DB.ANALYTICS.TASK_REFRESH_CUSTOMER360 RESUME;
    - Requires EXECUTE TASK privilege on the schema or ownership.

  Dependencies:
    - CUSTOMER360_DB.ANALYTICS.DT_CUSTOMER360 (dynamic table)
==============================================================================*/

USE ROLE C360_DATA_ENGINEER;
USE DATABASE CUSTOMER360_DB;
USE SCHEMA ANALYTICS;

CREATE OR REPLACE TASK TASK_REFRESH_CUSTOMER360
WAREHOUSE = CUSTOMER360_WH
ALLOW_OVERLAPPING_EXECUTION = FALSE
USER_TASK_TIMEOUT_MS = 300000
SUSPEND_TASK_AFTER_NUM_FAILURES = 3
COMMENT = 'Manual refresh task for Customer360 dynamic table.'
AS
ALTER DYNAMIC TABLE DT_CUSTOMER360 REFRESH;
