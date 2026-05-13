# 🧪 UI Regression Monitoring Agent

Captures UI screenshots and videos with Playwright CLI, compares them to QA-owned baselines, and produces evidence-first regression reports for manual QA review.

## Quick Start

```bash
git clone git@github.com:${GITHUB_OWNER}/ui-regression-monitoring-agent.git
cd ui-regression-monitoring-agent

# 1. Configure
cp .env.example .env
# Edit .env with your credentials (see "Required Environment Variables" below)

# 2. One-shot setup: validates env, installs deps, provisions DB, registers cron
chmod +x setup.sh
./setup.sh
```

## Manual Setup (if you prefer step-by-step)

```bash
cp .env.example .env             # then edit it
set -a; source .env; set +a       # load vars into the current shell
bash check-environment.sh         # verify everything required is set
bash install-dependencies.sh      # install Python deps plus the local Playwright package and browser binaries
python3 scripts/data_writer.py provision   # create tables in your schema
openclaw cron add --file cron/manual-only.json
```

## Runtime Notes

- Playwright runtime is installed from the local `package.json` manifest so the capture skill can import `playwright` from Node.
- `bash install-dependencies.sh` installs both the Node package and the required Chromium, Firefox, and WebKit browser binaries before smoke testing.
- `cron/manual-only.json` is a disabled placeholder schedule for operator-triggered manual runs; register it with `openclaw cron add --file cron/manual-only.json` and invoke it with `openclaw cron run --name manual-only` when needed.

## Running

```bash
bash test-workflow.sh             # run every skill in order locally (smoke test)
openclaw cron run --name manual-only    # trigger manually
openclaw cron list                # see registered jobs
openclaw cron runs                # see run history
```

## Required Environment Variables

| Variable | Description |
|----------|-------------|
| `PG_CONNECTION_STRING` | Postgres Connection String |
| `ORG_ID` | Organization ID |
| `AGENT_ID` | Agent ID |
| `BASELINE_ROOT` | Baseline Root |
| `RESULT_ROOT` | Result Root |
| `PLAYWRIGHT_BROWSERS_PATH` | Playwright Browsers Path |
| `ARTIFACT_ROOT` | Artifact Root |
| `REPORT_ROOT` | Report Root |

## Skills

| Skill | Mode | Description |
|-------|------|-------------|
| `data-writer` | Auto | Provision, write, and query the agent database schema via scripts/data_writer.py. Use for all PostgreSQL operations and any result-table persistence. |
| `result-query` | User-invocable | Read stored records from the agent result tables for inspection and follow-up questions. |
| `github-action` | User-invocable | Git branch + PR workflow for syncing agent changes to GitHub. Creates feature branches, commits changes, and opens pull requests against main. NEVER pushes to main directly. MANDATORY for every agent. |
| `capture-ui-artifacts` | Auto | Runs Playwright CLI in read-only mode to capture screenshots, videos, and a manifest for the requested scope and environment, then records run and artifact rows through the runtime data writer. |
| `compare-visual-baselines` | Auto | Loads current artifact context and QA-owned baselines, computes read-only comparison candidates, and emits findings without rewriting baselines. |
| `triage-regression-findings` | Auto | Builds the QA review package from comparison output, marks manual-review-required cases, updates the run summary, and persists result_findings when findings exist. |

## Scheduled Jobs

| Job Name | Schedule | Notes |
|----------|----------|-------|
| `manual-only` | `0 0 1 1 *` | Timezone: UTC |


## Architecture

- **Runtime**: OpenClaw AI agent framework
- **Data Layer**: PostgreSQL via `scripts/data_writer.py`
- **Scheduling**: OpenClaw cron
- **Schema**: `org_{org_id}_a_ui_regression_monitoring_agent`

## Directory Structure

```
ui-regression-monitoring-agent/
├── README.md
├── openclaw.json
├── result-schema.yml
├── env-manifest.yml
├── .env.example
├── requirements.txt
├── .gitignore
├── check-environment.sh
├── install-dependencies.sh
├── test-workflow.sh
├── cron/
├── workflows/
├── scripts/
│   ├── data_writer.py
│   └── github_action.py
├── skills/
└── workspace/
    ├── SOUL.md
    ├── 01_IDENTITY.md
    ├── 02_RULES.md
    ├── 03_SKILLS.md
    ├── 04_TRIGGERS.md
    ├── 05_ACCESS.md
    ├── 06_WORKFLOW.md
    └── 07_REVIEW.md
```
