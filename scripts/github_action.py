#!/usr/bin/env python3
"""
github_action.py — Git branch + PR workflow for OpenClaw agents.

Safety-guarded: NEVER pushes to protected branches (main, master, production, release).
All changes flow through feature branches and pull requests.

Commands:
  status        — Show uncommitted changes (git status)
  commit-and-pr — Create branch, commit all changes, push, create PR
  commit        — Add commit to current feature branch
  info          — Show current branch, remote, open PRs

Environment Variables:
  GITHUB_TOKEN      — Personal access token with repo scope (required)
  GITHUB_OWNER      — GitHub username or org (required)
  AGENT_REPO_NAME   — Repository name (required)

Usage:
  python3 scripts/github_action.py status
  python3 scripts/github_action.py commit-and-pr --message "Fixed timeout" --branch "fix/timeout"
  python3 scripts/github_action.py commit --message "Additional fix"
  python3 scripts/github_action.py info
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

# ── Safety: protected branches ──────────────────────────────────────────────

PROTECTED_BRANCHES = frozenset({"main", "master", "production", "release", "develop"})

def _run(cmd, check=True, capture=True, timeout=60):
    """Run a shell command and return stdout."""
    result = subprocess.run(
        cmd, shell=True, capture_output=capture, text=True, timeout=timeout
    )
    if check and result.returncode != 0:
        stderr = result.stderr.strip() if result.stderr else ""
        raise RuntimeError(f"Command failed ({result.returncode}): {cmd}\n{stderr}")
    return result.stdout.strip() if result.stdout else ""

def _ensure_not_protected(branch):
    """Block any operation targeting a protected branch."""
    clean = branch.strip().lstrip("origin/")
    if clean in PROTECTED_BRANCHES:
        print(f"BLOCKED: Cannot push to protected branch '{clean}'.", file=sys.stderr)
        print("Use a feature branch instead: fix/<description> or feat/<description>", file=sys.stderr)
        sys.exit(1)

def _ensure_git_repo():
    """Verify we're inside a git repository."""
    try:
        _run("git rev-parse --is-inside-work-tree", check=True)
    except (RuntimeError, subprocess.TimeoutExpired):
        print("ERROR: Not inside a git repository.", file=sys.stderr)
        print("Run this script from the agent's workspace root.", file=sys.stderr)
        sys.exit(1)

def _get_current_branch():
    """Return the current branch name."""
    return _run("git branch --show-current")

def _configure_remote(token, owner, repo):
    """Set the remote URL with token authentication."""
    remote_url = f"https://x-access-token:{token}@github.com/{owner}/{repo}.git"
    try:
        _run(f"git remote set-url origin {remote_url}")
    except RuntimeError:
        _run(f"git remote add origin {remote_url}")

def _configure_identity():
    """Set git user identity for commits."""
    _run('git config user.email "agent@ruh.ai"', check=False)
    _run('git config user.name "Ruh Agent"', check=False)

# ── Environment ─────────────────────────────────────────────────────────────

def _load_env():
    """Load and validate required environment variables."""
    token = os.environ.get("GITHUB_TOKEN", "").strip()
    owner = os.environ.get("GITHUB_OWNER", "").strip()
    repo = os.environ.get("AGENT_REPO_NAME", "").strip()

    missing = []
    if not token:
        missing.append("GITHUB_TOKEN")
    if not owner:
        missing.append("GITHUB_OWNER")
    if not repo:
        missing.append("AGENT_REPO_NAME")

    if missing:
        print(f"ERROR: Missing required environment variables: {', '.join(missing)}", file=sys.stderr)
        print("Set these in .env or deployment config before using github-action.", file=sys.stderr)
        sys.exit(1)

    return token, owner, repo

# ── Commands ────────────────────────────────────────────────────────────────

def cmd_status():
    """Show uncommitted changes."""
    _ensure_git_repo()
    branch = _get_current_branch()
    status = _run("git status --porcelain", check=False)

    if not status:
        print(json.dumps({
            "status": "clean",
            "branch": branch,
            "message": "No uncommitted changes — workspace is clean.",
            "files": []
        }, indent=2))
        return

    files = []
    for line in status.split("\n"):
        if line.strip():
            parts = line.strip().split(None, 1)
            if len(parts) == 2:
                files.append({"status": parts[0], "path": parts[1]})

    modified = sum(1 for f in files if f["status"] in ("M", "MM"))
    added = sum(1 for f in files if f["status"] in ("A", "??"))
    deleted = sum(1 for f in files if f["status"] == "D")

    print(json.dumps({
        "status": "changes_detected",
        "branch": branch,
        "message": f"{len(files)} files changed ({modified} modified, {added} new, {deleted} deleted)",
        "files": files,
        "summary": {
            "total": len(files),
            "modified": modified,
            "added": added,
            "deleted": deleted
        }
    }, indent=2))


def cmd_commit_and_pr(message, branch=None):
    """Create feature branch, commit all changes, push, and create PR."""
    _ensure_git_repo()
    token, owner, repo = _load_env()

    # Check for changes first
    status = _run("git status --porcelain", check=False)
    if not status:
        print(json.dumps({
            "status": "no_changes",
            "message": "Nothing to commit — workspace is clean."
        }, indent=2))
        return

    # Generate branch name if not provided
    if not branch:
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        branch = f"fix/{timestamp}"

    # Safety: ensure branch is not protected
    _ensure_not_protected(branch)

    # Ensure we're on main before branching (so the branch is based on main)
    current = _get_current_branch()
    if current != "main" and current != branch:
        # If already on a non-main, non-target branch, go back to main first
        _run("git stash", check=False)
        _run("git checkout main", check=False)
        _run("git stash pop", check=False)

    # Configure git
    _configure_identity()
    _configure_remote(token, owner, repo)

    # Create and checkout feature branch
    try:
        _run(f"git checkout -b {branch}")
    except RuntimeError:
        # Branch might already exist
        _run(f"git checkout {branch}")

    # Stage and commit
    _run("git add -A")
    _run(f'git commit -m "{message}"')

    # Push to remote
    _run(f"git push -u origin {branch}", timeout=120)

    # Create PR using gh CLI
    pr_url = ""
    pr_number = ""
    try:
        pr_output = _run(
            f'gh pr create --base main --head {branch} '
            f'--title "{message}" '
            f'--body "Automated PR from agent runtime.\\n\\nChanges synced via github-action skill."',
            timeout=30
        )
        # gh pr create outputs the PR URL
        pr_url = pr_output.strip()
        # Extract PR number from URL
        if "/pull/" in pr_url:
            pr_number = pr_url.split("/pull/")[-1]
    except RuntimeError as e:
        # gh might not be available — PR creation is best-effort
        print(f"WARNING: Could not create PR via gh CLI: {e}", file=sys.stderr)
        print("Changes were pushed to the branch. Create the PR manually on GitHub.", file=sys.stderr)
        pr_url = f"https://github.com/{owner}/{repo}/compare/main...{branch}"

    commit_sha = _run("git rev-parse HEAD")

    print(json.dumps({
        "status": "success",
        "branch": branch,
        "commit_sha": commit_sha,
        "pr_url": pr_url,
        "pr_number": pr_number,
        "message": f"Changes committed to branch '{branch}' and PR created.",
        "files_committed": len(status.split("\n")),
        "next_step": f"Review and merge the PR at: {pr_url}"
    }, indent=2))


def cmd_commit(message):
    """Add a commit to the current feature branch (must not be main)."""
    _ensure_git_repo()
    token, owner, repo = _load_env()

    current = _get_current_branch()
    _ensure_not_protected(current)

    status = _run("git status --porcelain", check=False)
    if not status:
        print(json.dumps({
            "status": "no_changes",
            "message": "Nothing to commit — workspace is clean."
        }, indent=2))
        return

    _configure_identity()
    _configure_remote(token, owner, repo)

    _run("git add -A")
    _run(f'git commit -m "{message}"')
    _run(f"git push origin {current}", timeout=120)

    commit_sha = _run("git rev-parse HEAD")

    print(json.dumps({
        "status": "success",
        "branch": current,
        "commit_sha": commit_sha,
        "message": f"Committed and pushed to '{current}'.",
        "files_committed": len(status.split("\n"))
    }, indent=2))


def cmd_info():
    """Show current branch, remote, and open PR status."""
    _ensure_git_repo()

    branch = _get_current_branch()
    is_protected = branch in PROTECTED_BRANCHES

    info = {
        "branch": branch,
        "is_protected": is_protected,
        "on_feature_branch": not is_protected,
    }

    # Check remote
    try:
        remote = _run("git remote get-url origin", check=False)
        # Strip token from URL for display
        if "@github.com" in remote:
            remote = "https://github.com/" + remote.split("github.com/")[1]
        info["remote"] = remote
    except Exception:
        info["remote"] = "not configured"

    # Check for uncommitted changes
    status = _run("git status --porcelain", check=False)
    info["has_uncommitted_changes"] = bool(status)
    info["uncommitted_file_count"] = len(status.split("\n")) if status else 0

    # Check for open PRs (if gh is available)
    try:
        prs = _run("gh pr list --head " + branch + " --json number,url,title --limit 5", check=False)
        if prs:
            info["open_prs"] = json.loads(prs)
        else:
            info["open_prs"] = []
    except Exception:
        info["open_prs"] = "gh CLI not available"

    print(json.dumps(info, indent=2))


# ── CLI ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Git branch + PR workflow for OpenClaw agents"
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # status
    sub.add_parser("status", help="Show uncommitted changes")

    # commit-and-pr
    cap = sub.add_parser("commit-and-pr", help="Create branch, commit, push, create PR")
    cap.add_argument("--message", "-m", required=True, help="Commit message")
    cap.add_argument("--branch", "-b", default=None, help="Branch name (default: fix/<timestamp>)")

    # commit
    c = sub.add_parser("commit", help="Commit to current feature branch")
    c.add_argument("--message", "-m", required=True, help="Commit message")

    # info
    sub.add_parser("info", help="Show branch and PR info")

    args = parser.parse_args()

    if args.command == "status":
        cmd_status()
    elif args.command == "commit-and-pr":
        cmd_commit_and_pr(args.message, args.branch)
    elif args.command == "commit":
        cmd_commit(args.message)
    elif args.command == "info":
        cmd_info()


if __name__ == "__main__":
    main()
