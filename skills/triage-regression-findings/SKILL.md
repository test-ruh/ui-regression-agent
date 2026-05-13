---
name: triage-regression-findings
version: 1.0.1
description: "Builds the QA review package from comparison output, marks manual-review-required cases, updates the run summary, and persists result_findings when findings exist."
user-invocable: false
metadata:
  openclaw:
    requires:
      bins: [bash, python3]
      env: [REPORT_ROOT, ARTIFACT_ROOT, RESULT_ROOT, PG_CONNECTION_STRING, ORG_ID, AGENT_ID, RUN_ID]
    primaryEnv: REPORT_ROOT
---
# Triage Regression Findings

## I/O Contract

- **Input:** `/tmp/triage-regression-findings_${RUN_ID}.json`
- **Output:** `outputs/triage-regression-findings.json`

## Execute

```bash
bash {baseDir}/scripts/run.sh
```
