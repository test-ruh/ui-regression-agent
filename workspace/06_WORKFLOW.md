# Workflow — End-to-End Process Flow

Executed by the [Lobster runtime](https://github.com/openclaw/lobster) via `lobster run workflows/main.yaml`.
Steps run **sequentially** in the order shown below.

## Workflow Steps

1. **provision-schema** → `run: python3 scripts/data_writer.py provision` (timeout_ms=30000, retry=0)
2. **capture-ui-artifacts** → skill `capture-ui-artifacts` (timeout_ms=240000, retry=1)
3. **compare-visual-baselines** → skill `compare-visual-baselines` (timeout_ms=180000, retry=1)
4. **triage-regression-findings** → skill `triage-regression-findings` (timeout_ms=180000, retry=0)
5. **publish-review-summary** → `run: set -euo pipefail
mkdir -p "${RESULT_ROOT}"
cat > "${RESULT_ROOT}/workflow-summary.txt" <<'EOF'
UI regression monitoring completed in read-only mode. Review the QA markdown report in REPORT_ROOT and immutable evidence in ARTIFACT_ROOT.
EOF` (timeout_ms=30000, retry=0)

## Diagram

```
provision-schema → capture-ui-artifacts → compare-visual-baselines → triage-regression-findings → publish-review-summary
```
