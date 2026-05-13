#!/usr/bin/env bash
# Auto-generated script for triage-regression-findings
# DO NOT MODIFY — this script is executed verbatim by the OpenClaw agent
set -euo pipefail

SKILL_ID="triage-regression-findings"
export SKILL_ID
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
export PROJECT_ROOT

# ── Environment validation ────────────────────────────────────────────────────
: "${REPORT_ROOT:?ERROR: REPORT_ROOT not set}"
: "${ARTIFACT_ROOT:?ERROR: ARTIFACT_ROOT not set}"
: "${RESULT_ROOT:?ERROR: RESULT_ROOT not set}"
: "${PG_CONNECTION_STRING:?ERROR: PG_CONNECTION_STRING not set}"
: "${ORG_ID:?ERROR: ORG_ID not set}"
: "${AGENT_ID:?ERROR: AGENT_ID not set}"
: "${RUN_ID:?ERROR: RUN_ID not set}"

# ── File paths ────────────────────────────────────────────────────────────────
INPUT_FILE="/tmp/triage-regression-findings_${RUN_ID}.json"
OUTPUT_FILE="outputs/triage-regression-findings.json"
export INPUT_FILE OUTPUT_FILE

# ── Input validation ──────────────────────────────────────────────────────────
[ -s "${INPUT_FILE}" ] || { echo "ERROR: input missing: ${INPUT_FILE}" >&2; exit 1; }

# ── Main logic ────────────────────────────────────────────────────────────────
set -euo pipefail

SKILL_ID="triage-regression-findings"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
OUTPUT_FILE="${OUTPUT_FILE:-outputs/triage-regression-findings.json}"
INPUT_FILE="${INPUT_FILE:-/tmp/triage-regression-findings_${RUN_ID}.json}"
export SKILL_ID PROJECT_ROOT OUTPUT_FILE INPUT_FILE

: "${REPORT_ROOT:?ERROR: REPORT_ROOT not set}"
: "${ARTIFACT_ROOT:?ERROR: ARTIFACT_ROOT not set}"
: "${RESULT_ROOT:?ERROR: RESULT_ROOT not set}"
: "${PG_CONNECTION_STRING:?ERROR: PG_CONNECTION_STRING not set}"
: "${ORG_ID:?ERROR: ORG_ID not set}"
: "${AGENT_ID:?ERROR: AGENT_ID not set}"
: "${RUN_ID:?ERROR: RUN_ID not set}"

mkdir -p "$(dirname "$OUTPUT_FILE")" "$REPORT_ROOT" "$RESULT_ROOT/state"

python3 - <<'PY'
import json, os, pathlib
from datetime import datetime, timezone

def now():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z')

run_id = os.environ['RUN_ID']
state_root = pathlib.Path(os.environ['RESULT_ROOT']) / 'state'
capture = json.loads((state_root / f'{run_id}-capture.json').read_text())
comparison = json.loads((state_root / f'{run_id}-comparison.json').read_text())
run = capture['run']
payload = run['payload']
environment = payload.get('environment', 'default-environment')
scope = payload.get('target_scope', 'default-scope')
report_root = pathlib.Path(os.environ['REPORT_ROOT'])
report_path = report_root / f'{run_id}-qa-review.md'
findings = comparison.get('findings', [])
manual_queue = comparison.get('manual_review_queue', [])
critical = [f for f in findings if f['severity'] == 'critical']
warning = [f for f in findings if f['severity'] == 'warning']
status = 'completed_no_findings' if not findings else 'completed_with_findings'
summary = 'No visual regressions exceeded the configured thresholds.' if not findings else f'{len(findings)} potential regression finding(s) detected.'
lines = ['# QA Visual Regression Review', '', f'- Run ID: {run_id}', f'- Scope: {scope}', f'- Environment: {environment}', f'- Created At: {now()}', '- Retention: 30 days', f'- Status: {status}', '', '## Summary', summary, '', '## Counts', f'- Critical: {len(critical)}', f'- Warning: {len(warning)}', f'- Manual review: {len(manual_queue)}', '']
if findings:
    lines.extend(['## Findings', ''])
    for finding in findings:
        meta = finding.get('metadata', {})
        lines.extend([f"### {finding['severity'].upper()} — {meta.get('label', 'artifact')}", f"- Diff score: {finding['diff_score']}", f"- Artifact: {meta.get('artifact_uri')}", f"- Baseline: {meta.get('baseline_uri')}", f"- Diff image: {meta.get('diff_image_uri')}", f"- Summary: {finding['summary']}", f"- Details: {finding.get('details', '')}", ''])
else:
    lines.extend(['## Findings', '', '- None. All compared screenshots were clean within the configured thresholds.', ''])
lines.extend(['## Manual Review Queue', ''])
if manual_queue:
    for item in manual_queue:
        lines.append(f"- {item['label']}: {item['reason']} (artifact: {item.get('artifact_uri')}, baseline: {item.get('baseline_uri')}, diff: {item.get('diff_image_uri')}, score: {item.get('diff_score')})")
else:
    lines.append('- None.')
lines.extend(['', '## Guardrails', '- Baselines remain QA-owned and read-only.', '- This agent does not rewrite baselines, edit code, or perform destructive actions.', '- Ambiguous diffs require human QA review before escalation or dismissal.', ''])
report_path.write_text('\n'.join(lines), encoding='utf-8')
run['status'] = status
run['summary'] = summary
run['payload']['report_path'] = str(report_path.resolve())
run['payload']['manual_review_required'] = bool(manual_queue)
state = {'run': run, 'report_path': str(report_path.resolve()), 'findings': findings, 'manual_review_queue': manual_queue, 'status': status, 'summary': summary}
(state_root / f'{run_id}-triage.json').write_text(json.dumps(state, indent=2), encoding='utf-8')
pathlib.Path(os.environ['OUTPUT_FILE']).write_text(json.dumps(state, indent=2), encoding='utf-8')
PY

RUN_RECORDS=$(python3 - <<'PY'
import json, os
from pathlib import Path
state = json.loads(Path(os.environ['OUTPUT_FILE']).read_text())
print(json.dumps([state['run']]))
PY
)
FINDING_RECORDS=$(python3 - <<'PY'
import json, os
from pathlib import Path
state = json.loads(Path(os.environ['OUTPUT_FILE']).read_text())
print(json.dumps(state['findings']))
PY
)
python3 "$PROJECT_ROOT/scripts/data_writer.py" write --table result_runs --conflict id --run-id "$RUN_ID" --records "$RUN_RECORDS"
if [ "$FINDING_RECORDS" != "[]" ]; then
  python3 "$PROJECT_ROOT/scripts/data_writer.py" write --table result_findings --conflict id --run-id "$RUN_ID" --records "$FINDING_RECORDS"
fi
[ -s "$OUTPUT_FILE" ]
echo "OK: triage-regression-findings complete"

# ── Output validation ─────────────────────────────────────────────────────────
[ -s "${OUTPUT_FILE}" ] || { echo "ERROR: output empty: ${OUTPUT_FILE}" >&2; exit 1; }

echo "OK: triage-regression-findings complete"
