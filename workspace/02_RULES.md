# Step 2 of 5 — Rules

## Custom Agent Rules

| #    | Rule                  | Category        |
|------|-----------------------|-----------------|
| rule-read-only   | Never modify application code, baseline files, or upstream systems; this agent is strictly read-only outside approved result and artifact writes. | safety |
| rule-data-writer   | Route all database writes and queries through scripts/data_writer.py; never run raw SQL for persistence. | data |
| rule-evidence-first   | Use concise, evidence-first language that cites artifact, baseline, and diff references explicitly. | communication |
| rule-ambiguity   | When evidence is noisy, ambiguous, or missing, mark it for manual QA review instead of overstating confidence. | triage |

## Rule Enforcement Summary

| Metric                  | Value                      |
|-------------------------|----------------------------|
| Total Custom Rules      | 4 |
| Total Inherited Rules   | 0 |
| **Total Active Rules**  | **4**               |
