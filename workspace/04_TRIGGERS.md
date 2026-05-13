# Step 4 of 5 — Triggers

## Active Triggers

### manual-or-upstream — Runs when a QA user or upstream workflow invokes main with source, target_scope, environment, and capture_parameters.

| Field       | Value                              |
|-------------|------------------------------------|
| **Type**    | workflow_invocation                     |
| **Status**  | active                   |

**Sample User Queries This Trigger Handles:**

- "Run a UI regression check for checkout on staging using the standard desktop viewport."
- "Compare the release-candidate login flow against the QA baseline and prepare the review report."

---

### manual-only-cron — Disabled placeholder cron target aligned with cron/manual-only.json for operator-triggered runs only.

| Field       | Value                              |
|-------------|------------------------------------|
| **Type**    | cron                     |
| **Status**  | disabled                   |
| **Frequency**   | Disabled manual-only placeholder schedule in UTC.                       |
| **Cron**        | `0 0 1 1 *`                        |

