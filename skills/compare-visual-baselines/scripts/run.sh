#!/usr/bin/env bash
# Auto-generated script for compare-visual-baselines
# DO NOT MODIFY — this script is executed verbatim by the OpenClaw agent
set -euo pipefail

SKILL_ID="compare-visual-baselines"
export SKILL_ID
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
export PROJECT_ROOT

# ── Environment validation ────────────────────────────────────────────────────
: "${BASELINE_ROOT:?ERROR: BASELINE_ROOT not set}"
: "${ARTIFACT_ROOT:?ERROR: ARTIFACT_ROOT not set}"
: "${RESULT_ROOT:?ERROR: RESULT_ROOT not set}"
: "${PG_CONNECTION_STRING:?ERROR: PG_CONNECTION_STRING not set}"
: "${ORG_ID:?ERROR: ORG_ID not set}"
: "${AGENT_ID:?ERROR: AGENT_ID not set}"
: "${RUN_ID:?ERROR: RUN_ID not set}"

# ── File paths ────────────────────────────────────────────────────────────────
INPUT_FILE="/tmp/compare-visual-baselines_${RUN_ID}.json"
OUTPUT_FILE="outputs/compare-visual-baselines.json"
export INPUT_FILE OUTPUT_FILE

# ── Input validation ──────────────────────────────────────────────────────────
[ -s "${INPUT_FILE}" ] || { echo "ERROR: input missing: ${INPUT_FILE}" >&2; exit 1; }

# ── Main logic ────────────────────────────────────────────────────────────────
set -euo pipefail

SKILL_ID="compare-visual-baselines"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
OUTPUT_FILE="${OUTPUT_FILE:-outputs/compare-visual-baselines.json}"
INPUT_FILE="${INPUT_FILE:-/tmp/compare-visual-baselines_${RUN_ID}.json}"
export SKILL_ID PROJECT_ROOT OUTPUT_FILE INPUT_FILE

: "${BASELINE_ROOT:?ERROR: BASELINE_ROOT not set}"
: "${ARTIFACT_ROOT:?ERROR: ARTIFACT_ROOT not set}"
: "${RESULT_ROOT:?ERROR: RESULT_ROOT not set}"
: "${PG_CONNECTION_STRING:?ERROR: PG_CONNECTION_STRING not set}"
: "${ORG_ID:?ERROR: ORG_ID not set}"
: "${AGENT_ID:?ERROR: AGENT_ID not set}"
: "${RUN_ID:?ERROR: RUN_ID not set}"

mkdir -p "$(dirname "$OUTPUT_FILE")" "$RESULT_ROOT/state"

python3 - <<'PY'
import json, os, pathlib, uuid
from datetime import datetime, timezone
from PIL import Image, ImageChops

def now():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z')

def load_json(path):
    return json.loads(path.read_text())

def find_baseline(label, environment, scope, baseline_root):
    stem = ''.join(ch.lower() if ch.isalnum() else '-' for ch in label).strip('-')
    candidates = [
        baseline_root / environment / scope / f'{stem}.png',
        baseline_root / scope / environment / f'{stem}.png',
        baseline_root / scope / f'{stem}.png',
        baseline_root / environment / f'{stem}.png',
        baseline_root / f'{stem}.png',
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    matches = list(baseline_root.rglob(f'{stem}.png'))
    return matches[0] if matches else None

run_id = os.environ['RUN_ID']
state_root = pathlib.Path(os.environ['RESULT_ROOT']) / 'state'
capture_state = load_json(state_root / f'{run_id}-capture.json')
run = capture_state['run']
payload = run['payload']
environment = payload.get('environment', 'default-environment')
scope = payload.get('target_scope', 'default-scope')
baseline_root = pathlib.Path(os.environ['BASELINE_ROOT'])
artifact_root = pathlib.Path(os.environ['ARTIFACT_ROOT'])
diff_root = artifact_root / run_id / 'diffs'
diff_root.mkdir(parents=True, exist_ok=True)
warning = float(payload.get('capture_parameters', {}).get('warning_threshold', os.environ.get('DIFF_WARNING_THRESHOLD', '0.01')))
critical = float(payload.get('capture_parameters', {}).get('critical_threshold', os.environ.get('DIFF_CRITICAL_THRESHOLD', '0.05')))
ambiguous = float(payload.get('capture_parameters', {}).get('ambiguous_threshold', os.environ.get('DIFF_AMBIGUOUS_THRESHOLD', str(warning))))
comparisons, findings, manual_review_queue = [], [], []
for artifact in capture_state['artifacts']:
    if artifact['artifact_type'] != 'screenshot':
        continue
    baseline_path = find_baseline(artifact['label'], environment, scope, baseline_root)
    if baseline_path is None:
        findings.append({
            'id': str(uuid.uuid4()), 'run_id': run_id, 'artifact_id': artifact['id'],
            'baseline_id': '00000000-0000-0000-0000-000000000000', 'severity': 'manual_review', 'diff_score': 1.0,
            'summary': f'No QA-owned baseline was found for {artifact["label"]}.',
            'details': 'Comparison skipped because no active baseline image was available for the requested label and environment.',
            'created_at': now(),
            'metadata': {'label': artifact['label'], 'environment': environment, 'scope': scope, 'review_reason': 'missing_baseline', 'artifact_uri': artifact['uri'], 'baseline_uri': None, 'retention_days': 30}
        })
        manual_review_queue.append({'label': artifact['label'], 'reason': 'missing_baseline', 'artifact_uri': artifact['uri']})
        comparisons.append({'label': artifact['label'], 'artifact_id': artifact['id'], 'baseline_path': None, 'diff_score': 1.0, 'status': 'missing_baseline'})
        continue
    current = Image.open(artifact['uri']).convert('RGBA')
    baseline = Image.open(baseline_path).convert('RGBA')
    dimensions_match = current.size == baseline.size
    if not dimensions_match:
        baseline = baseline.resize(current.size)
    diff = ImageChops.difference(current, baseline)
    bbox = diff.getbbox()
    if bbox is None:
        changed_ratio = 0.0
    else:
        histogram = diff.convert('L').histogram()
        total = sum(v * i for i, v in enumerate(histogram))
        max_total = 255 * current.size[0] * current.size[1]
        changed_ratio = total / max_total if max_total else 0.0
    diff_image_path = diff_root / f"{artifact['label'].replace('/', '-')}-diff.png"
    diff.save(diff_image_path)
    severity, review_reason = 'info', None
    if changed_ratio >= critical or not dimensions_match:
        severity = 'critical'
    elif changed_ratio >= warning:
        severity = 'warning'
    elif changed_ratio >= ambiguous:
        severity = 'manual_review'
        review_reason = 'ambiguous_diff'
    baseline_id = str(uuid.uuid5(uuid.NAMESPACE_URL, str(baseline_path.resolve())))
    comparisons.append({'label': artifact['label'], 'artifact_id': artifact['id'], 'baseline_path': str(baseline_path.resolve()), 'baseline_id': baseline_id, 'diff_score': round(changed_ratio, 6), 'dimensions_match': dimensions_match, 'diff_image_path': str(diff_image_path.resolve()), 'status': 'clean' if severity == 'info' and changed_ratio == 0 else severity})
    if severity != 'info' or changed_ratio > 0:
        findings.append({
            'id': str(uuid.uuid4()), 'run_id': run_id, 'artifact_id': artifact['id'], 'baseline_id': baseline_id,
            'severity': severity, 'diff_score': round(changed_ratio, 6),
            'summary': f'{artifact["label"]}: diff score {round(changed_ratio, 6)} against QA baseline.',
            'details': 'Dimensions differed and the baseline was resized for comparison.' if not dimensions_match else 'Visual difference computed from screenshot pixel delta against the QA-owned baseline.',
            'created_at': now(),
            'metadata': {'label': artifact['label'], 'environment': environment, 'scope': scope, 'artifact_uri': artifact['uri'], 'baseline_uri': str(baseline_path.resolve()), 'diff_image_uri': str(diff_image_path.resolve()), 'dimensions_match': dimensions_match, 'review_reason': review_reason, 'thresholds': {'ambiguous': ambiguous, 'warning': warning, 'critical': critical}, 'retention_days': 30}
        })
        if severity == 'manual_review':
            manual_review_queue.append({'label': artifact['label'], 'reason': review_reason, 'artifact_uri': artifact['uri'], 'baseline_uri': str(baseline_path.resolve()), 'diff_image_uri': str(diff_image_path.resolve()), 'diff_score': round(changed_ratio, 6)})
state = {'run': run, 'comparisons': comparisons, 'findings': findings, 'manual_review_queue': manual_review_queue, 'status': 'completed_no_findings' if not findings else 'findings_detected', 'summary': f'Compared {len(comparisons)} screenshot artifact(s) to QA-owned baselines for scope {scope} in {environment}.', 'retention_days': 30}
(state_root / f'{run_id}-comparison.json').write_text(json.dumps(state, indent=2), encoding='utf-8')
pathlib.Path(os.environ['OUTPUT_FILE']).write_text(json.dumps(state, indent=2), encoding='utf-8')
PY

[ -s "$OUTPUT_FILE" ]
echo "OK: compare-visual-baselines complete"

# ── Output validation ─────────────────────────────────────────────────────────
[ -s "${OUTPUT_FILE}" ] || { echo "ERROR: output empty: ${OUTPUT_FILE}" >&2; exit 1; }

echo "OK: compare-visual-baselines complete"
