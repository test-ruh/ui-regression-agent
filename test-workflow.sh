#!/usr/bin/env bash
# Smoke-test the workflow.
#   1. If 'lobster' is on PATH, validate workflows/main.yaml via 'lobster run --dry-run'.
#   2. Then iterate skills/*/scripts/run.sh as a direct fallback smoke test.
set -euo pipefail

export RUN_ID="test-$(date +%s)"
echo "RUN_ID=${RUN_ID}"

if command -v lobster >/dev/null 2>&1; then
    echo "--- Validating workflows/main.yaml via lobster --dry-run ---"
    lobster run --dry-run --file workflows/main.yaml
else
    echo "(lobster CLI not installed — skipping workflow validation; run install-dependencies.sh)"
fi

for skill_dir in skills/*/; do
    name=$(basename "$skill_dir")
    runner="${skill_dir}scripts/run.sh"
    if [ -x "$runner" ]; then
        echo "--- Running $name ---"
        bash "$runner" || { echo "FAIL: $name"; exit 1; }
    fi
done
echo "OK: all skills ran without errors"
