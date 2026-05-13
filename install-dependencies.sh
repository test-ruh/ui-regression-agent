#!/usr/bin/env bash
# Install runtime dependencies for this agent.
#   - Python deps from requirements.txt (data_writer, scripts) — resilient to
#     fresh hosts that don't have `pip` on PATH (Debian/Ubuntu out of the box,
#     PEP 668 systems, macOS).
#   - @clawdbot/lobster — workflow runtime that executes workflows/main.yaml.
set -euo pipefail

if command -v pip >/dev/null 2>&1; then
    pip install -r requirements.txt
elif command -v pip3 >/dev/null 2>&1; then
    pip3 install -r requirements.txt
elif command -v python3 >/dev/null 2>&1; then
    python3 -m pip install -r requirements.txt --break-system-packages 2>/dev/null \
        || python3 -m pip install -r requirements.txt
else
    echo "ERROR: no pip / pip3 / python3 found on PATH — install Python 3.x first" >&2
    exit 1
fi

if ! command -v lobster >/dev/null 2>&1; then
    echo "Installing @clawdbot/lobster (Lobster workflow runtime)..."
    if command -v npm >/dev/null 2>&1; then
        npm install -g @clawdbot/lobster
    elif command -v pnpm >/dev/null 2>&1; then
        pnpm add -g @clawdbot/lobster
    else
        echo "ERROR: neither npm nor pnpm found — install Node.js (>= 22.14) first" >&2
        exit 1
    fi
fi

lobster --version
