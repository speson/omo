#!/usr/bin/env bash
# Create .omo/config.json with default content
# Usage: init-config.sh [--force]
set -eu

force=0
for arg in "$@"; do
  if [ "${arg}" = "--force" ]; then
    force=1
  fi
done

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/.." && pwd)
config_dir="${repo_root}/.omo"
config_file="${config_dir}/config.json"

if [ -f "${config_file}" ] && [ "${force}" -eq 0 ]; then
  echo "Config already exists. Use --force to overwrite."
  exit 0
fi

mkdir -p "${config_dir}"

if [ -f "${config_file}" ]; then
  action="overwritten"
else
  action="created"
fi

if command -v jq >/dev/null 2>&1; then
  jq -n '{
    "version": "1",
    "categories": {
      "fast-search":    { "model": "haiku" },
      "verification":   { "model": "sonnet" },
      "implementation": { "model": "sonnet" },
      "planning":       { "model": "sonnet" },
      "deep-reasoning": { "model": "opus" },
      "research":       { "model": "sonnet" },
      "media":          { "model": "sonnet" }
    },
    "ralph-loop": {
      "max_iterations": 100,
      "oracle_default": false
    },
    "spawn": {
      "max_concurrent_agents": 5
    },
    "boulder": {
      "enabled": true,
      "max_attempts": 5,
      "auto_resume": true
    },
    "teams": {
      "enabled": true,
      "max_teammates": 8,
      "auto_escalation": true,
      "notify_on_completion": true
    },
    "disabled_skills": []
  }' > "${config_file}"
else
  cat > "${config_file}" <<'EOF'
{
  "version": "1",
  "categories": {
    "fast-search":    { "model": "haiku" },
    "verification":   { "model": "sonnet" },
    "implementation": { "model": "sonnet" },
    "planning":       { "model": "sonnet" },
    "deep-reasoning": { "model": "opus" },
    "research":       { "model": "sonnet" },
    "media":          { "model": "sonnet" }
  },
  "ralph-loop": {
    "max_iterations": 100,
    "oracle_default": false
  },
  "spawn": {
    "max_concurrent_agents": 5
  },
  "boulder": {
    "enabled": true,
    "max_attempts": 5,
    "auto_resume": true
  },
  "teams": {
    "enabled": true,
    "max_teammates": 8,
    "auto_escalation": true,
    "notify_on_completion": true
  },
  "disabled_skills": []
}
EOF
fi

echo "Config ${action}: .omo/config.json"
