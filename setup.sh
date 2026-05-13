#!/usr/bin/env bash
# =============================================================================
# One-command setup for UI Regression Monitoring Agent
# Idempotent — safe to re-run at any time.
#
# Usage:
#   bash setup.sh              # full setup (recommended)
#   bash setup.sh deps         # only install system dependencies
#   bash setup.sh env          # only configure .env
#   bash setup.sh python       # only install Python packages
#   bash setup.sh db           # only initialise database
#   bash setup.sh health       # only run health checks
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[0;33m'; BLU='\033[0;34m'; CYN='\033[0;36m'; DIM='\033[2m'; RST='\033[0m'
log()  { printf "${BLU}▸${RST} %s\n" "$*"; }
ok()   { printf "${GRN}✓${RST} %s\n" "$*"; }
warn() { printf "${YLW}!${RST} %s\n" "$*"; }
err()  { printf "${RED}✗${RST} %s\n" "$*" >&2; }
hdr()  { printf "\n${CYN}━━━ %s ━━━${RST}\n" "$*"; }
ask()  { printf "${YLW}?${RST} %s " "$*"; }

AGENT_NAME="UI Regression Monitoring Agent"
AGENT_ID="ui-regression-monitoring-agent"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# ─── OS detection ────────────────────────────────────────────────
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then echo "macos"
  elif [[ -f /etc/debian_version ]]; then echo "debian"
  elif [[ -f /etc/redhat-release ]]; then echo "rhel"
  elif [[ -f /etc/alpine-release ]]; then echo "alpine"
  else echo "unknown"; fi
}
OS="$(detect_os)"
SUDO=""
if [[ "${OS}" != "macos" && "$(id -u)" -ne 0 ]]; then
  command -v sudo >/dev/null 2>&1 && SUDO="sudo"
fi
have() { command -v "$1" >/dev/null 2>&1; }

# ─── Phase 1: System dependencies ────────────────────────────────
phase_deps() {
  hdr "Phase 1 — System dependencies (OS: ${OS})"

  # python3
  if have python3; then
    ok "python3 $(python3 --version 2>&1 | awk '{print $2}')"
  else
    log "Installing python3..."
    case "${OS}" in
      debian) ${SUDO} apt-get install -y -qq python3 python3-pip ;;
      rhel)   ${SUDO} dnf install -y -q python3 python3-pip ;;
      alpine) ${SUDO} apk add --no-cache python3 py3-pip ;;
      macos)  brew install python3 ;;
      *)      err "python3 not found. Install Python 3 manually and re-run."; exit 1 ;;
    esac
    ok "python3 $(python3 --version 2>&1 | awk '{print $2}') installed"
  fi

  # pip
  if have pip || have pip3; then
    ok "pip present"
  else
    log "Installing pip..."
    python3 -m ensurepip --upgrade 2>/dev/null || true
    if ! have pip && ! have pip3; then
      case "${OS}" in
        debian) ${SUDO} apt-get install -y -qq python3-pip ;;
        rhel)   ${SUDO} dnf install -y -q python3-pip ;;
        alpine) ${SUDO} apk add --no-cache py3-pip ;;
        macos)  python3 -m ensurepip ;;
      esac
    fi
    ok "pip ready"
  fi

  # psql client (needed for DB checks — data_writer.py uses its own connection)
  if have psql; then
    ok "psql $(psql --version 2>/dev/null | awk '{print $3}')"
  else
    log "Installing PostgreSQL client..."
    case "${OS}" in
      debian) ${SUDO} apt-get install -y -qq postgresql-client ;;
      rhel)   ${SUDO} dnf install -y -q postgresql ;;
      alpine) ${SUDO} apk add --no-cache postgresql-client ;;
      macos)  brew install libpq && brew link --force libpq 2>/dev/null || true ;;
      *)      warn "Could not install psql — continuing without it" ;;
    esac
    have psql && ok "psql installed" || warn "psql not on PATH (non-fatal)"
  fi

  # curl
  if have curl; then ok "curl present"
  else
    log "Installing curl..."
    case "${OS}" in
      debian) ${SUDO} apt-get install -y -qq curl ;;
      rhel)   ${SUDO} dnf install -y -q curl ;;
      alpine) ${SUDO} apk add --no-cache curl ;;
      macos)  brew install curl ;;
    esac
    have curl && ok "curl installed" || warn "curl not found (non-fatal)"
  fi
}

# ─── Phase 2: Configure .env ─────────────────────────────────────
phase_env() {
  hdr "Phase 2 — Environment configuration"

  if [[ ! -f .env ]]; then
    log "No .env found — creating from .env.example"
    cp .env.example .env
    ok ".env created"
  else
    ok ".env exists"
  fi

  # Load what's already set
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a

  local changed=false

  # ── Required vars (user must provide) ──
  local required_vars=(
  # Required vars — user must provide these
  "PLAYWRIGHT_BROWSERS_PATH|Playwright Browsers Path|Browser installation path used by Playwright CLI for capture runs.|Point to the Playwright browser cache or installed browser directory on the runner."
  "ARTIFACT_ROOT|Artifact Root|Immutable storage root for screenshots, videos, manifests, and diff evidence retained for one month.|Provision a writable artifact directory for this agent's evidence output."
  "REPORT_ROOT|Report Root|Output directory for the QA review report artifact.|Provision a writable report directory for this agent's markdown review reports."
  )

  # ── Optional vars (press Enter to skip) ──
  local optional_vars=(
  # Optional vars — press Enter to skip
  "CI|CI Flag|Optional CI mode flag passed through to Playwright CLI.|Set by the runner when CI-compatible Playwright behavior is needed."
  )

  prompt_var() {
    local key="$1" label="$2" description="$3" how_to_get="$4" is_required="$5"
    local current="${!key:-}"
    if [[ -n "${current}" ]]; then
      ok "  ${key} already set"
      return
    fi
    echo ""
    if [[ "${is_required}" == "true" ]]; then
      printf "  ${CYN}%s${RST} ${DIM}(required)${RST}\n" "${label}"
    else
      printf "  ${YLW}%s${RST} ${DIM}(optional — press Enter to skip)${RST}\n" "${label}"
    fi
    [[ -n "${description}" ]] && printf "  ${DIM}%s${RST}\n" "${description}"
    [[ -n "${how_to_get}"  ]] && printf "  ${DIM}How to get: %s${RST}\n" "${how_to_get}"
    ask "  ${key}:"
    local val
    read -r val
    if [[ -n "${val}" ]]; then
      if grep -q "^${key}=" .env 2>/dev/null; then
        sed -i.bak "s|^${key}=.*|${key}=${val}|" .env && rm -f .env.bak
      else
        echo "${key}=${val}" >> .env
      fi
      export "${key}=${val}"
      ok "  ${key} set"
      changed=true
    elif [[ "${is_required}" == "true" ]]; then
      err "  ${key} is required but was left empty."
      err "  Edit .env and re-run: bash setup.sh env"
      exit 1
    else
      warn "  ${key} skipped (optional)"
    fi
  }

  for entry in "${required_vars[@]}"; do
    IFS='|' read -r key label description how_to_get <<< "${entry}"
    prompt_var "${key}" "${label}" "${description}" "${how_to_get}" "true"
  done

  for entry in "${optional_vars[@]}"; do
    IFS='|' read -r key label description how_to_get <<< "${entry}"
    prompt_var "${key}" "${label}" "${description}" "${how_to_get}" "false"
  done

  # Reload after updates
  set -a; source .env; set +a
  "${changed}" && ok ".env updated" || true
}

# ─── Phase 3: Python dependencies ────────────────────────────────
phase_python() {
  hdr "Phase 3 — Python dependencies"
  bash install-dependencies.sh
  ok "Python dependencies installed"
}

# ─── Phase 4: Database ────────────────────────────────────────────
phase_db() {
  hdr "Phase 4 — Database"
  set -a; source .env; set +a

  # Resolve PG_CONNECTION_STRING
  if [[ -n "${PG_CONNECTION_STRING:-}" ]]; then
    ok "PG_CONNECTION_STRING from .env"
  else
    log "PG_CONNECTION_STRING not set — checking for local Postgres..."

    local local_pg=false
    if have pg_isready && pg_isready -h localhost -p 5432 -q 2>/dev/null; then
      local_pg=true
    elif have psql && psql "postgresql://localhost:5432/postgres" -c "SELECT 1" >/dev/null 2>&1; then
      local_pg=true
    fi

    if ${local_pg}; then
      ok "Local Postgres detected on localhost:5432"
      echo ""
      ask "  Database name (default: ${AGENT_ID}):"
      local db_name; read -r db_name; db_name="${db_name:-${AGENT_ID}}"
      ask "  Username      (default: postgres):"
      local db_user; read -r db_user; db_user="${db_user:-postgres}"
      ask "  Password      (press Enter for none):"
      local db_pass; read -rs db_pass; echo ""

      if [[ -n "${db_pass}" ]]; then
        export PG_CONNECTION_STRING="postgresql://${db_user}:${db_pass}@localhost:5432/${db_name}"
      else
        export PG_CONNECTION_STRING="postgresql://${db_user}@localhost:5432/${db_name}"
      fi
    else
      echo ""
      err "PG_CONNECTION_STRING is not set and no local Postgres was found."
      err ""
      warn "Options:"
      warn "  1. Start local Postgres, then re-run: bash setup.sh db"
      warn "  2. Set PG_CONNECTION_STRING in .env manually, then re-run"
      warn "  3. Launch via Docker:"
      warn "       docker run -d --name pg -e POSTGRES_PASSWORD=secret -p 5432:5432 postgres:16"
      warn "     Then set in .env: PG_CONNECTION_STRING=postgresql://postgres:secret@localhost:5432/ui-regression-monitoring-agent"
      exit 1
    fi

    # Save to .env
    if grep -q "^PG_CONNECTION_STRING=" .env 2>/dev/null; then
      sed -i.bak "s|^PG_CONNECTION_STRING=.*|PG_CONNECTION_STRING=${PG_CONNECTION_STRING}|" .env && rm -f .env.bak
    else
      echo "PG_CONNECTION_STRING=${PG_CONNECTION_STRING}" >> .env
    fi
    ok "PG_CONNECTION_STRING saved to .env"
  fi

  # Wait for DB + provision schema
  log "Connecting to database and provisioning schema..."
  local attempt=0
  while [[ ${attempt} -lt 15 ]]; do
    if PG_CONNECTION_STRING="${PG_CONNECTION_STRING}" python3 scripts/data_writer.py provision 2>/dev/null; then
      ok "Database schema provisioned"
      return
    fi
    attempt=$((attempt + 1))
    warn "Database not ready yet — retry ${attempt}/15 in 2s..."
    sleep 2
  done

  err "Could not provision database after 30s."
  err "Check your connection string: ${PG_CONNECTION_STRING}"
  err "Re-run when the database is available: bash setup.sh db"
  exit 1
}

# ─── Phase 5: Final checks + cron ────────────────────────────────
phase_finish() {
  hdr "Phase 5 — Final checks"
  set -a; source .env; set +a

  bash check-environment.sh

  # Register cron jobs
  if command -v openclaw >/dev/null 2>&1; then
    if openclaw cron list 2>/dev/null | grep -q "^manual-only\b"; then
      ok "cron 'manual-only' already registered"
    else
      openclaw cron add --file cron/manual-only.json && ok "registered cron 'manual-only'"
    fi
  else
    warn "openclaw CLI not found — register manually: openclaw cron add --file cron/manual-only.json"
  fi

  echo ""
  ok "${AGENT_NAME} is ready!"
  echo ""
  log "Useful commands:"
  log "  bash test-workflow.sh                      # smoke-test all skills"
  log "  openclaw cron run --name manual-only    # trigger manually"
  log "  python3 scripts/data_writer.py query --table <name> --limit 10"
}

# ─── Dispatcher ──────────────────────────────────────────────────
main() {
  local target="${1:-all}"
  hdr "🤖 ${AGENT_NAME} setup"
  log "Agent ID : ${AGENT_ID}"
  log "Phase    : ${target}"

  case "${target}" in
    deps)   phase_deps ;;
    env)    phase_env ;;
    python) phase_python ;;
    db)     phase_db ;;
    health) phase_finish ;;
    all|"")
      phase_deps
      phase_env
      phase_python
      phase_db
      phase_finish
      ;;
    *)
      err "Unknown phase: ${target}"
      echo "Usage: bash setup.sh [deps|env|python|db|health|all]"
      exit 2
      ;;
  esac
}

main "$@"
