#!/usr/bin/env bash
# Auto-generated script for capture-ui-artifacts
# DO NOT MODIFY — this script is executed verbatim by the OpenClaw agent
set -euo pipefail

SKILL_ID="capture-ui-artifacts"
export SKILL_ID
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
export PROJECT_ROOT

# ── Environment validation ────────────────────────────────────────────────────
: "${PLAYWRIGHT_BROWSERS_PATH:?ERROR: PLAYWRIGHT_BROWSERS_PATH not set}"
: "${ARTIFACT_ROOT:?ERROR: ARTIFACT_ROOT not set}"
: "${RESULT_ROOT:?ERROR: RESULT_ROOT not set}"
: "${PG_CONNECTION_STRING:?ERROR: PG_CONNECTION_STRING not set}"
: "${ORG_ID:?ERROR: ORG_ID not set}"
: "${AGENT_ID:?ERROR: AGENT_ID not set}"
: "${RUN_ID:?ERROR: RUN_ID not set}"

# ── File paths ────────────────────────────────────────────────────────────────
INPUT_FILE="/tmp/capture-ui-artifacts_${RUN_ID}.json"
OUTPUT_FILE="outputs/capture-ui-artifacts.json"
export INPUT_FILE OUTPUT_FILE

# ── Input validation ──────────────────────────────────────────────────────────
[ -s "${INPUT_FILE}" ] || { echo "ERROR: input missing: ${INPUT_FILE}" >&2; exit 1; }

# ── Main logic ────────────────────────────────────────────────────────────────
set -euo pipefail

SKILL_ID="capture-ui-artifacts"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
OUTPUT_FILE="${OUTPUT_FILE:-outputs/capture-ui-artifacts.json}"
INPUT_FILE="${INPUT_FILE:-/tmp/capture-ui-artifacts_${RUN_ID}.json}"
export SKILL_ID PROJECT_ROOT OUTPUT_FILE INPUT_FILE

: "${PLAYWRIGHT_BROWSERS_PATH:?ERROR: PLAYWRIGHT_BROWSERS_PATH not set}"
: "${ARTIFACT_ROOT:?ERROR: ARTIFACT_ROOT not set}"
: "${RESULT_ROOT:?ERROR: RESULT_ROOT not set}"
: "${PG_CONNECTION_STRING:?ERROR: PG_CONNECTION_STRING not set}"
: "${ORG_ID:?ERROR: ORG_ID not set}"
: "${AGENT_ID:?ERROR: AGENT_ID not set}"
: "${RUN_ID:?ERROR: RUN_ID not set}"

mkdir -p "$(dirname "$OUTPUT_FILE")" "$ARTIFACT_ROOT" "$RESULT_ROOT/state"

python3 - <<'PY'
import json, os, pathlib, subprocess, uuid, hashlib
from datetime import datetime, timezone

def now():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z')

def slug(value):
    text = ''.join(ch.lower() if ch.isalnum() else '-' for ch in str(value))
    while '--' in text:
        text = text.replace('--', '-')
    return text.strip('-') or 'target'

def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

run_id = os.environ['RUN_ID']
result_root = pathlib.Path(os.environ['RESULT_ROOT'])
artifact_root = pathlib.Path(os.environ['ARTIFACT_ROOT'])
state_root = result_root / 'state'
state_root.mkdir(parents=True, exist_ok=True)
run_root = artifact_root / run_id
screens_dir = run_root / 'screenshots'
videos_dir = run_root / 'videos'
manifest_dir = run_root / 'manifests'
screens_dir.mkdir(parents=True, exist_ok=True)
videos_dir.mkdir(parents=True, exist_ok=True)
manifest_dir.mkdir(parents=True, exist_ok=True)
input_path = pathlib.Path(os.environ['INPUT_FILE'])
payload = {}
if input_path.exists() and input_path.read_text().strip():
    payload = json.loads(input_path.read_text())
source = payload.get('source') or os.environ.get('RUN_SOURCE', 'manual')
target_scope = payload.get('target_scope') or os.environ.get('TARGET_SCOPE', 'default-scope')
environment = payload.get('environment') or os.environ.get('TARGET_ENVIRONMENT', 'default-environment')
raw_capture = payload.get('capture_parameters') if payload else None
if raw_capture is None:
    raw_capture = os.environ.get('CAPTURE_PARAMETERS_JSON', '{}')
if isinstance(raw_capture, str):
    capture_parameters = json.loads(raw_capture or '{}')
else:
    capture_parameters = raw_capture
if not isinstance(capture_parameters, dict):
    raise SystemExit('capture_parameters must be a JSON object')
targets = capture_parameters.get('targets') or []
if not targets:
    default_url = capture_parameters.get('url') or payload.get('target_url') or os.environ.get('TARGET_URL')
    if default_url:
        targets = [{
            'label': target_scope,
            'url': default_url,
            'viewport': capture_parameters.get('viewport', {'width': 1440, 'height': 900}),
            'full_page': capture_parameters.get('full_page', True),
            'capture_video': capture_parameters.get('capture_video', True),
            'wait_until': capture_parameters.get('wait_until', 'networkidle'),
        }]
if not targets:
    raise SystemExit('No capture targets were supplied. Provide capture_parameters.targets or capture_parameters.url/TARGET_URL.')
node_script = result_root / f'{run_id}-playwright-capture.mjs'
node_script.write_text("""
import { chromium, firefox, webkit } from 'playwright';
import fs from 'fs';
import path from 'path';
const payload = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const browserTypes = { chromium, firefox, webkit };
const browserType = browserTypes[payload.browser_name || 'chromium'];
const browser = await browserType.launch({ headless: payload.headless !== false });
const context = await browser.newContext({
  viewport: payload.viewport || { width: 1440, height: 900 },
  ignoreHTTPSErrors: true,
  recordVideo: payload.capture_video ? { dir: payload.video_dir, size: payload.video_size || payload.viewport || { width: 1440, height: 900 } } : undefined,
  storageState: payload.storage_state_path || undefined,
  baseURL: payload.base_url || undefined,
  userAgent: payload.user_agent || undefined,
  locale: payload.locale || undefined,
  colorScheme: payload.color_scheme || undefined
});
if (payload.extra_http_headers && typeof payload.extra_http_headers === 'object') {
  await context.setExtraHTTPHeaders(payload.extra_http_headers);
}
const page = await context.newPage();
const gotoOptions = { waitUntil: payload.wait_until || 'networkidle', timeout: payload.timeout_ms || 120000 };
await page.goto(payload.url, gotoOptions);
if (payload.wait_for_selector) {
  await page.waitForSelector(payload.wait_for_selector, { timeout: payload.timeout_ms || 120000 });
}
if (Number.isFinite(payload.post_load_wait_ms) && payload.post_load_wait_ms > 0) {
  await page.waitForTimeout(payload.post_load_wait_ms);
}
if (payload.mask_selectors && Array.isArray(payload.mask_selectors) && payload.mask_selectors.length > 0) {
  const styleTag = payload.mask_selectors.map((selector) => `${selector}{visibility:hidden !important;}`).join('\n');
  await page.addStyleTag({ content: styleTag });
}
await page.screenshot({ path: payload.screenshot_path, fullPage: payload.full_page !== false, animations: 'disabled' });
if (payload.capture_video) {
  await page.waitForTimeout(payload.video_wait_ms || 500);
}
const video = payload.capture_video ? page.video() : null;
await page.close();
await context.close();
await browser.close();
let videoPath = null;
if (video) {
  const savedPath = await video.path();
  videoPath = path.join(payload.video_dir, payload.video_name || path.basename(savedPath));
  if (savedPath !== videoPath) {
    fs.copyFileSync(savedPath, videoPath);
  }
}
process.stdout.write(JSON.stringify({ screenshot_path: payload.screenshot_path, video_path: videoPath }));
""", encoding='utf-8')
created_at = now()
artifacts = []
manifest = {'run_id': run_id, 'created_at': created_at, 'source': source, 'target_scope': target_scope, 'environment': environment, 'retention_days': 30, 'artifacts': []}
for idx, target in enumerate(targets, start=1):
    label = target.get('label') or f'{target_scope}-{idx}'
    file_stem = slug(label)
    screenshot_path = screens_dir / f'{file_stem}.png'
    request = {
        'url': target['url'],
        'viewport': target.get('viewport', {'width': 1440, 'height': 900}),
        'capture_video': bool(target.get('capture_video', True)),
        'video_dir': str(videos_dir),
        'video_name': f'{file_stem}.webm',
        'screenshot_path': str(screenshot_path),
        'full_page': bool(target.get('full_page', True)),
        'wait_until': target.get('wait_until', 'networkidle'),
        'wait_for_selector': target.get('wait_for_selector'),
        'post_load_wait_ms': target.get('post_load_wait_ms', capture_parameters.get('post_load_wait_ms', 0)),
        'timeout_ms': target.get('timeout_ms', capture_parameters.get('timeout_ms', 120000)),
        'headless': capture_parameters.get('headless', True),
        'browser_name': target.get('browser_name', capture_parameters.get('browser_name', 'chromium')),
        'storage_state_path': target.get('storage_state_path') or capture_parameters.get('storage_state_path'),
        'base_url': target.get('base_url') or capture_parameters.get('base_url'),
        'user_agent': target.get('user_agent') or capture_parameters.get('user_agent'),
        'locale': target.get('locale') or capture_parameters.get('locale'),
        'color_scheme': target.get('color_scheme') or capture_parameters.get('color_scheme'),
        'extra_http_headers': target.get('extra_http_headers') or capture_parameters.get('extra_http_headers'),
        'mask_selectors': target.get('mask_selectors') or capture_parameters.get('mask_selectors') or [],
        'video_size': target.get('video_size') or capture_parameters.get('video_size'),
    }
    request_path = result_root / f'{run_id}-{file_stem}-capture-request.json'
    request_path.write_text(json.dumps(request), encoding='utf-8')
    completed = subprocess.run(['node', str(node_script), str(request_path)], check=True, capture_output=True, text=True)
    capture_result = json.loads(completed.stdout)
    captured_at = now()
    screenshot_record = {
        'id': str(uuid.uuid4()), 'run_id': run_id, 'artifact_type': 'screenshot', 'label': label,
        'uri': str(pathlib.Path(capture_result['screenshot_path']).resolve()), 'checksum': sha256(capture_result['screenshot_path']),
        'mime_type': 'image/png', 'captured_at': captured_at,
        'metadata': {'scope': target_scope, 'environment': environment, 'source': source, 'target': target, 'retention_days': 30}
    }
    artifacts.append(screenshot_record)
    manifest['artifacts'].append(screenshot_record)
    if capture_result.get('video_path') and pathlib.Path(capture_result['video_path']).exists():
        video_record = {
            'id': str(uuid.uuid4()), 'run_id': run_id, 'artifact_type': 'video', 'label': label,
            'uri': str(pathlib.Path(capture_result['video_path']).resolve()), 'checksum': sha256(capture_result['video_path']),
            'mime_type': 'video/webm', 'captured_at': captured_at,
            'metadata': {'scope': target_scope, 'environment': environment, 'source': source, 'target': target, 'retention_days': 30}
        }
        artifacts.append(video_record)
        manifest['artifacts'].append(video_record)
manifest_path = manifest_dir / f'{run_id}-capture-manifest.json'
manifest_path.write_text(json.dumps(manifest, indent=2), encoding='utf-8')
manifest_record = {
    'id': str(uuid.uuid4()), 'run_id': run_id, 'artifact_type': 'manifest', 'label': f'{target_scope}-manifest',
    'uri': str(manifest_path.resolve()), 'checksum': sha256(manifest_path), 'mime_type': 'application/json',
    'captured_at': created_at, 'metadata': {'scope': target_scope, 'environment': environment, 'source': source, 'retention_days': 30}
}
artifacts.append(manifest_record)
state = {
    'run': {'id': run_id, 'created_at': created_at, 'status': 'pending', 'source': source,
            'summary': f'Captured {len(targets)} UI target(s) for scope {target_scope} in {environment}.',
            'payload': {'source': source, 'target_scope': target_scope, 'environment': environment, 'capture_parameters': capture_parameters, 'retention_days': 30}},
    'artifacts': artifacts,
    'manifest_path': str(manifest_path.resolve()),
    'capture_root': str(run_root.resolve())
}
(state_root / f'{run_id}-capture.json').write_text(json.dumps(state, indent=2), encoding='utf-8')
pathlib.Path(os.environ['OUTPUT_FILE']).write_text(json.dumps(state, indent=2), encoding='utf-8')
PY

RUN_RECORDS=$(python3 - <<'PY'
import json, os
from pathlib import Path
state = json.loads(Path(os.environ['OUTPUT_FILE']).read_text())
print(json.dumps([state['run']]))
PY
)
ARTIFACT_RECORDS=$(python3 - <<'PY'
import json, os
from pathlib import Path
state = json.loads(Path(os.environ['OUTPUT_FILE']).read_text())
print(json.dumps(state['artifacts']))
PY
)
python3 "$PROJECT_ROOT/scripts/data_writer.py" write --table result_runs --conflict id --run-id "$RUN_ID" --records "$RUN_RECORDS"
python3 "$PROJECT_ROOT/scripts/data_writer.py" write --table result_artifacts --conflict id --run-id "$RUN_ID" --records "$ARTIFACT_RECORDS"
[ -s "$OUTPUT_FILE" ]
echo "OK: capture-ui-artifacts complete"

# ── Output validation ─────────────────────────────────────────────────────────
[ -s "${OUTPUT_FILE}" ] || { echo "ERROR: output empty: ${OUTPUT_FILE}" >&2; exit 1; }

echo "OK: capture-ui-artifacts complete"
