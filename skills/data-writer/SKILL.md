---
name: data-writer
version: 1.0.0
description: "Provision, write, and query the agent database schema via scripts/data_writer.py. Use for all PostgreSQL operations and any result-table persistence."
user-invocable: false
metadata:
  openclaw:
    requires:
      bins: [bash, python3]
      env: [RUN_ID, PG_CONNECTION_STRING, ORG_ID, AGENT_ID]
---
# Data Writer

## I/O Contract

- **Input:** JSON records provided by upstream steps
- **Output:** JSON result from scripts/data_writer.py
- **DB Write:** result_* tables via upsert on conflict columns defined in result-schema.yml

## Execute

Use `scripts/data_writer.py write --table <name> --conflict <cols> --run-id ${RUN_ID} --records '<json>'` inline from another skill's run.sh. Do NOT run this skill directly — it is invoked by other skills that produce records.
