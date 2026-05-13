# Step 3 of 5 — Skills

## Added Skills

| #    | Skill ID                  | Skill Name               | Mode   | Risk Level | Description                |
|------|---------------------------|--------------------------|--------|------------|----------------------------|
| S1   | `data-writer` | Data Writer | Auto | Low | Provision, write, and query the agent database schema via scripts/data_writer.py. Use for all PostgreSQL operations and any result-table persistence. |
| S2   | `result-query` | Result Query | Auto | Low | Read stored records from the agent result tables for inspection and follow-up questions. |
| S3   | `github-action` | GitHub Action | Auto | Low | Git branch + PR workflow for syncing agent changes to GitHub. Creates feature branches, commits changes, and opens pull requests against main. NEVER pushes to main directly. MANDATORY for every agent. |
| S4   | `capture-ui-artifacts` | Capture UI Artifacts | Auto | Low | Runs Playwright CLI in read-only mode to capture screenshots, videos, and a manifest for the requested scope and environment, then records run and artifact rows through the runtime data writer. |
| S5   | `compare-visual-baselines` | Compare Visual Baselines | Auto | Low | Loads current artifact context and QA-owned baselines, computes read-only comparison candidates, and emits findings without rewriting baselines. |
| S6   | `triage-regression-findings` | Triage Regression Findings | Auto | Low | Builds the QA review package from comparison output, marks manual-review-required cases, updates the run summary, and persists result_findings when findings exist. |

## Skill Dependencies (Execution Order)

```
data-writer
result-query
github-action
capture-ui-artifacts
compare-visual-baselines
triage-regression-findings
```

## Execution Mode Summary

| Mode  | Count          |
|-------|----------------|
| HiTL  | 0              |
| Auto  | 6 |
