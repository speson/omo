#!/usr/bin/env bash
# Collect project metrics for evolve skill
# Output: JSON to stdout, human-readable summary to stderr
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
project_dir="${CLAUDE_PROJECT_DIR:-.}"
repo_root=$(CDPATH='' cd -- "${script_dir}/.." && pwd)

# Resolve project root — prefer CLAUDE_PROJECT_DIR, fall back to repo_root
if [ -d "${project_dir}" ]; then
  root="${project_dir}"
else
  root="${repo_root}"
fi

# ─── Metric collection ──────────────────────────────────────────────────────

# Tests
tests_count=0
if [ -f "${root}/tests/backtest.sh" ]; then
  tests_count=$(grep -c 'run_test\|run_test_fail\|run_test_output' "${root}/tests/backtest.sh" 2>/dev/null) || tests_count=0
fi

# Scripts
scripts_count=0
if [ -d "${root}/scripts" ]; then
  scripts_count=$(find "${root}/scripts" -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
fi

# Shellcheck issues
shellcheck_issues=-1
if command -v shellcheck >/dev/null 2>&1 && [ -d "${root}/scripts" ]; then
  shellcheck_issues=$(shellcheck "${root}/scripts/"*.sh 2>&1 | grep -c '^[[:space:]]') || shellcheck_issues=0
fi

# Skills
skills_count=0
if [ -d "${root}/skills" ]; then
  skills_count=$(find "${root}/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
fi

# Agents
agents_count=0
if [ -d "${root}/agents" ]; then
  agents_count=$(find "${root}/agents" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
fi

# Memory
memory_conventions=0
memory_decisions=0
memory_failures=0
if [ -f "${root}/.claude/state/memory/conventions.md" ]; then
  memory_conventions=$(grep -c '^\- \[' "${root}/.claude/state/memory/conventions.md" 2>/dev/null) || memory_conventions=0
fi
if [ -f "${root}/.claude/state/memory/decisions.md" ]; then
  memory_decisions=$(grep -c '^\- \[' "${root}/.claude/state/memory/decisions.md" 2>/dev/null) || memory_decisions=0
fi
if [ -f "${root}/.claude/state/memory/failures.md" ]; then
  memory_failures=$(grep -c '^\- \[' "${root}/.claude/state/memory/failures.md" 2>/dev/null) || memory_failures=0
fi

# Previous improvement runs
previous_runs=0
if [ -f "${root}/.claude/state/improvements/history.log" ]; then
  previous_runs=$(wc -l < "${root}/.claude/state/improvements/history.log" | tr -d ' ')
fi

# Config exists
config_exists=false
if [ -f "${root}/.omo/config.json" ]; then
  config_exists=true
fi

# ─── Timestamp ───────────────────────────────────────────────────────────────

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ─── JSON output ─────────────────────────────────────────────────────────────

if command -v jq >/dev/null 2>&1; then
  jq -n \
    --arg ts "${timestamp}" \
    --argjson tc "${tests_count}" \
    --argjson sc "${scripts_count}" \
    --argjson si "${shellcheck_issues}" \
    --argjson skc "${skills_count}" \
    --argjson ac "${agents_count}" \
    --argjson mc "${memory_conventions}" \
    --argjson md "${memory_decisions}" \
    --argjson mf "${memory_failures}" \
    --argjson pr "${previous_runs}" \
    --argjson ce "${config_exists}" \
    '{
      timestamp: $ts,
      tests: { count: $tc },
      scripts: { count: $sc, shellcheck_issues: $si },
      skills: { count: $skc },
      agents: { count: $ac },
      memory: { conventions: $mc, decisions: $md, failures: $mf },
      improvements: { previous_runs: $pr },
      config: { exists: $ce }
    }'
elif command -v python3 >/dev/null 2>&1; then
  python3 - "${timestamp}" "${tests_count}" "${scripts_count}" "${shellcheck_issues}" \
    "${skills_count}" "${agents_count}" "${memory_conventions}" "${memory_decisions}" \
    "${memory_failures}" "${previous_runs}" "${config_exists}" <<'PYEOF'
import json, sys
a = sys.argv[1:]
print(json.dumps({
    "timestamp": a[0],
    "tests": {"count": int(a[1])},
    "scripts": {"count": int(a[2]), "shellcheck_issues": int(a[3])},
    "skills": {"count": int(a[4])},
    "agents": {"count": int(a[5])},
    "memory": {"conventions": int(a[6]), "decisions": int(a[7]), "failures": int(a[8])},
    "improvements": {"previous_runs": int(a[9])},
    "config": {"exists": a[10] == "true"}
}, indent=2))
PYEOF
else
  # Raw fallback
  cat <<RAWEOF
{"timestamp":"${timestamp}","tests":{"count":${tests_count}},"scripts":{"count":${scripts_count},"shellcheck_issues":${shellcheck_issues}},"skills":{"count":${skills_count}},"agents":{"count":${agents_count}},"memory":{"conventions":${memory_conventions},"decisions":${memory_decisions},"failures":${memory_failures}},"improvements":{"previous_runs":${previous_runs}},"config":{"exists":${config_exists}}}
RAWEOF
fi

# ─── Human-readable summary (stderr) ────────────────────────────────────────

{
  echo "Project Metrics:"
  echo "  Tests: ${tests_count}"
  echo "  Scripts: ${scripts_count} (shellcheck issues: ${shellcheck_issues})"
  echo "  Skills: ${skills_count}"
  echo "  Agents: ${agents_count}"
  echo "  Memory: conventions=${memory_conventions} decisions=${memory_decisions} failures=${memory_failures}"
  echo "  Previous evolve runs: ${previous_runs}"
  echo "  Config: ${config_exists}"
} >&2
