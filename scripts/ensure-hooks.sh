#!/usr/bin/env bash
# Ensure the ralph-loop Stop hook is registered in .claude/settings.local.json
set -eu

# If plugin hooks file exists AND we're running in plugin context, hooks are auto-registered
# Check via CLAUDE_PLUGIN_ROOT env var (set when loaded as a plugin)
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json" ]; then
  echo "[ensure-hooks] Plugin hooks detected. Stop hook auto-registered via hooks/hooks.json."
  exit 0
fi

# Also check relative to script location (for standalone runs)
if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
  repo_root=$(CDPATH='' cd -- "${script_dir}/.." && pwd)
  if [ -f "${repo_root}/hooks/hooks.json" ]; then
    echo "[ensure-hooks] Plugin hooks found at ${repo_root}/hooks/hooks.json. Use 'claude --plugin-dir ${repo_root}' to auto-register."
    exit 0
  fi
fi

STATE_DIR=".claude"
SETTINGS_FILE="${STATE_DIR}/settings.local.json"

mkdir -p "${STATE_DIR}"

# Check if settings file exists and has Stop hook
if [ -f "${SETTINGS_FILE}" ]; then
  if grep -q 'ralph-loop-guard' "${SETTINGS_FILE}" 2>/dev/null; then
    echo "[ensure-hooks] Stop hook already registered."
    exit 0
  fi
fi

# Create or update settings file with the Stop hook
if [ -f "${SETTINGS_FILE}" ] && [ -s "${SETTINGS_FILE}" ]; then
  # File exists but doesn't have the hook — check if it has hooks section
  if grep -q '"hooks"' "${SETTINGS_FILE}" 2>/dev/null; then
    echo "[ensure-hooks] Settings file has hooks section but missing ralph-loop-guard."
    echo "[ensure-hooks] Please manually add the Stop hook. See examples/hooks.json.example"
    exit 1
  else
    # Has content but no hooks — we need to merge carefully
    # Use a temp approach: read, add hooks
    if command -v jq >/dev/null 2>&1; then
      jq '. + {"hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"bash scripts/ralph-loop-guard.sh"}]}]}}' "${SETTINGS_FILE}" > "${SETTINGS_FILE}.tmp"
      mv "${SETTINGS_FILE}.tmp" "${SETTINGS_FILE}"
      echo "[ensure-hooks] Stop hook registered via jq merge."
    else
      echo "[ensure-hooks] Cannot auto-merge without jq. Please add manually:"
      echo '  "hooks": { "Stop": [{ "matcher": "", "hooks": [{"type": "command", "command": "bash scripts/ralph-loop-guard.sh"}] }] }'
      exit 1
    fi
  fi
else
  # File doesn't exist or is empty — create fresh
  cat > "${SETTINGS_FILE}" <<'HOOKS_EOF'
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [{"type": "command", "command": "bash scripts/ralph-loop-guard.sh"}]
      }
    ]
  }
}
HOOKS_EOF
  echo "[ensure-hooks] Created ${SETTINGS_FILE} with Stop hook."
fi
