---
name: capture-ui-artifacts
version: 1.0.1
description: "Runs Playwright CLI in read-only mode to capture screenshots, videos, and a manifest for the requested scope and environment, then records run and artifact rows through the runtime data writer."
user-invocable: false
metadata:
  openclaw:
    requires:
      bins: [bash, python3, node]
      env: [PLAYWRIGHT_BROWSERS_PATH, ARTIFACT_ROOT, RESULT_ROOT, PG_CONNECTION_STRING, ORG_ID, AGENT_ID, RUN_ID]
    primaryEnv: PLAYWRIGHT_BROWSERS_PATH
---
# Capture UI Artifacts

## I/O Contract

- **Input:** `/tmp/capture-ui-artifacts_${RUN_ID}.json`
- **Output:** `outputs/capture-ui-artifacts.json`

## Execute

```bash
bash {baseDir}/scripts/run.sh
```
