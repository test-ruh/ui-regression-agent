#!/usr/bin/env bash
# Check required environment variables are set.
set -euo pipefail

missing=0
if [ -z "${PG_CONNECTION_STRING:-}" ]; then echo "MISSING: PG_CONNECTION_STRING"; missing=$((missing+1)); fi
if [ -z "${ORG_ID:-}" ]; then echo "MISSING: ORG_ID"; missing=$((missing+1)); fi
if [ -z "${AGENT_ID:-}" ]; then echo "MISSING: AGENT_ID"; missing=$((missing+1)); fi
if [ -z "${BASELINE_ROOT:-}" ]; then echo "MISSING: BASELINE_ROOT"; missing=$((missing+1)); fi
if [ -z "${RESULT_ROOT:-}" ]; then echo "MISSING: RESULT_ROOT"; missing=$((missing+1)); fi
if [ -z "${PLAYWRIGHT_BROWSERS_PATH:-}" ]; then echo "MISSING: PLAYWRIGHT_BROWSERS_PATH"; missing=$((missing+1)); fi
if [ -z "${ARTIFACT_ROOT:-}" ]; then echo "MISSING: ARTIFACT_ROOT"; missing=$((missing+1)); fi
if [ -z "${REPORT_ROOT:-}" ]; then echo "MISSING: REPORT_ROOT"; missing=$((missing+1)); fi

if [ $missing -gt 0 ]; then
    echo "$missing required env var(s) missing"
    exit 1
fi
echo "OK: all required env vars set"
