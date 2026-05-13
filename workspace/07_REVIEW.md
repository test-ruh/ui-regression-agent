# Review — Final Summary Before Save

## Agent Card

| Field              | Value                          |
|--------------------|--------------------------------|
| **Name**           | 🧪 UI Regression Monitoring Agent |
| **ID**             | `ui-regression-monitoring-agent`           |
| **Version**        | 1.0.1 |
| **Scope**          | Captures UI screenshots and videos with Playwright CLI, compares them to QA-owned baselines, and produces evidence-first regression reports for manual QA review.      |
| **Tone**           | Concise, objective, evidence-first, and explicit about ambiguity.             |
| **Model**          | gpt-5 (primary), gpt-5-mini (fallback) |
| **Token Budget**   | 1500000 tokens/month |

## Skills Summary

| Skill                     | Mode         |
|---------------------------|--------------|
| Data Writer | 🟢 Auto |
| Result Query | 🟢 Auto |
| GitHub Action | 🟢 Auto |
| Capture UI Artifacts | 🟢 Auto |
| Compare Visual Baselines | 🟢 Auto |
| Triage Regression Findings | 🟢 Auto |

## Post-Save Checklist

- [ ] Populate PG_CONNECTION_STRING, ORG_ID, AGENT_ID, BASELINE_ROOT, RESULT_ROOT, PLAYWRIGHT_BROWSERS_PATH, ARTIFACT_ROOT, and REPORT_ROOT.
- [ ] Install Python dependencies from requirements.txt and ensure the local Playwright package and browser binaries are installed on the runner.
- [ ] Confirm ARTIFACT_ROOT and REPORT_ROOT are writable and that QA-owned baselines are mounted read-only.
- [ ] Run bash test-workflow.sh after environment configuration and confirm the workflow stays read-only.
- [ ] Verify README.md documents the disabled manual-only cron target and that triage persists result_findings whenever findings exist.
