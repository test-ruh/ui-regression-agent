---
name: compare-visual-baselines
version: 1.0.1
description: "Loads current artifact context and QA-owned baselines, computes read-only comparison candidates, and emits findings without rewriting baselines."
user-invocable: false
metadata:
  openclaw:
    requires:
      bins: [bash, python3]
      env: [BASELINE_ROOT, ARTIFACT_ROOT, RESULT_ROOT, PG_CONNECTION_STRING, ORG_ID, AGENT_ID, RUN_ID]
    primaryEnv: BASELINE_ROOT
---
# Compare Visual Baselines

## I/O Contract

- **Input:** `/tmp/compare-visual-baselines_${RUN_ID}.json`
- **Output:** `outputs/compare-visual-baselines.json`

## Execute

```bash
bash {baseDir}/scripts/run.sh
```
