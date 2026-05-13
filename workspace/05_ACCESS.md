# Step 5 of 5 — Access

## User Access

### Authorized Teams

| Team               | Access Level | Members (approx) |
|--------------------|-------------|-------------------|
| QA | run_and_review | QA analysts, QA leads, and release testers |
| Platform Operations | configure_runtime | Operators who manage env vars, storage mounts, and database connectivity |

### Restricted From

| Team / Role          | Reason                          |
|----------------------|---------------------------------|
| Developers requesting code changes | The agent may not edit application code, rewrite baselines, or apply remediation. |
| Anyone requesting destructive data actions | The workflow only provisions/query/upserts through scripts/data_writer.py and refuses deletes or schema mutations. |

## HiTL Approvers

| Skill                | Action                         | Approver             | Fallback Approver    |
|----------------------|--------------------------------|----------------------|----------------------|
| triage-regression-findings | Review ambiguous diffs or missing baselines before escalation or dismissal. | QA Lead | Senior QA Analyst |

## Model Configuration

| Field                | Value                          |
|----------------------|--------------------------------|
| **Primary Model**    | gpt-5   |
| **Fallback Model**   | gpt-5-mini  |

## Token Budget

| Field                  | Value                  |
|------------------------|------------------------|
| **Monthly Budget**     | 1500000 tokens |
| **Alert Threshold**    | 1200000 tokens |
| **Auto-Pause on Limit**| No |

## Security & Permissions

| Permission                         | Allowed    |
|------------------------------------|------------|
| Filesystem writes under ARTIFACT_ROOT | ✅ |
| Filesystem writes under REPORT_ROOT and RESULT_ROOT | ✅ |
| PostgreSQL provision/query/upsert through scripts/data_writer.py | ✅ |
| Modify baseline files | ❌ |
| Modify application code or open pull requests automatically | ❌ |
