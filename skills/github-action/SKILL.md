---
name: github-action
version: 1.0.0
description: "Git branch + PR workflow for syncing agent changes to GitHub. Creates feature branches, commits changes, and opens pull requests against main. NEVER pushes to main directly. MANDATORY for every agent."
user-invocable: true
metadata:
  openclaw:
    always: true
    requires:
      bins: [git, gh]
      env: [GITHUB_TOKEN, GITHUB_OWNER, AGENT_REPO_NAME]
    primaryEnv: GITHUB_TOKEN
---
# GitHub Action — Branch + PR Workflow

Syncs workspace changes to GitHub via feature branches and pull requests.
This agent NEVER pushes to main directly — all changes go through PRs.

## Status (check what would be synced)

```bash
python3 scripts/github_action.py status
```

## Sync Changes (create branch + commit + PR)

```bash
python3 scripts/github_action.py commit-and-pr \
  --message "Description of changes" \
  --branch "fix/short-description"
```

## Add More Commits (to existing feature branch)

```bash
python3 scripts/github_action.py commit \
  --message "Additional changes"
```

## Info (current branch + PR status)

```bash
python3 scripts/github_action.py info
```

## Rules

- NEVER push to main — always use feature branches
- NEVER force push — protect commit history
- Developer merges PRs manually via GitHub UI
- Use descriptive commit messages explaining what changed and why
- Always run `status` first to show what would be committed
