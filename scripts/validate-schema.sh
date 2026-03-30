#!/usr/bin/env bash
# Validate plugin structure and frontmatter schemas
# Usage: validate-schema.sh
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/.." && pwd)
cd "${repo_root}"

errors=0

echo "omo schema validation"
echo "====================="
echo ""

# ─── plugin.json ─────────────────────────────────────────────
echo "plugin.json:"
if [ ! -f ".claude-plugin/plugin.json" ]; then
  echo "  FAIL: file not found"
  errors=$((errors + 1))
else
  for field in name description version; do
    if ! grep -q "\"${field}\"" .claude-plugin/plugin.json; then
      echo "  FAIL: missing field '${field}'"
      errors=$((errors + 1))
    fi
  done
  echo "  OK: required fields present"
fi
echo ""

# ─── Skills ──────────────────────────────────────────────────
echo "Skills:"
for skill_dir in skills/*/; do
  skill_name=$(basename "${skill_dir}")
  skill_file="${skill_dir}SKILL.md"

  if [ ! -f "${skill_file}" ]; then
    echo "  FAIL: ${skill_name}/ missing SKILL.md"
    errors=$((errors + 1))
    continue
  fi

  # Check frontmatter exists
  if ! head -1 "${skill_file}" | grep -q '^---$'; then
    echo "  FAIL: ${skill_name} missing YAML frontmatter"
    errors=$((errors + 1))
    continue
  fi

  # Required fields
  for field in name description allowed-tools; do
    if ! grep -q "^${field}:" "${skill_file}"; then
      echo "  FAIL: ${skill_name} missing '${field}'"
      errors=$((errors + 1))
    fi
  done

  # Name matches directory
  fm_name=$(grep '^name:' "${skill_file}" | head -1 | sed 's/^name:[[:space:]]*//')
  if [ "${fm_name}" != "${skill_name}" ]; then
    echo "  FAIL: ${skill_name} name mismatch (frontmatter='${fm_name}')"
    errors=$((errors + 1))
  fi
done
echo "  Checked $(ls -d skills/*/ | wc -l | tr -d ' ') skills"
echo ""

# ─── Agents ──────────────────────────────────────────────────
echo "Agents:"
for agent_file in agents/*.md; do
  agent_name=$(basename "${agent_file}" .md)

  # Required fields
  for field in name description tools model maxTurns; do
    if ! grep -q "^${field}:" "${agent_file}"; then
      echo "  FAIL: ${agent_name} missing '${field}'"
      errors=$((errors + 1))
    fi
  done

  # Valid model
  model=$(grep '^model:' "${agent_file}" | head -1 | sed 's/^model:[[:space:]]*//')
  case "${model}" in
    haiku|sonnet|opus) ;;
    *) echo "  FAIL: ${agent_name} invalid model '${model}'"; errors=$((errors + 1)) ;;
  esac

  # Valid category
  category=$(grep '^category:' "${agent_file}" | head -1 | sed 's/^category:[[:space:]]*//' || true)
  if [ -n "${category}" ]; then
    case "${category}" in
      fast-search|verification|implementation|planning|deep-reasoning|research|media) ;;
      *) echo "  FAIL: ${agent_name} invalid category '${category}'"; errors=$((errors + 1)) ;;
    esac
  else
    echo "  WARN: ${agent_name} missing category field"
  fi
done
echo "  Checked $(ls agents/*.md | wc -l | tr -d ' ') agents"
echo ""

# ─── Config (.omo/config.json) ──────────────────────────────
echo "Config:"
if [ -f ".omo/config.json" ]; then
  if command -v jq >/dev/null 2>&1; then
    if ! jq empty .omo/config.json 2>/dev/null; then
      echo "  FAIL: .omo/config.json is not valid JSON"
      errors=$((errors + 1))
    else
      echo "  OK: valid JSON"
      # Check version field
      cfg_version=$(jq -r '.version // empty' .omo/config.json)
      if [ "${cfg_version}" != "1" ]; then
        echo "  FAIL: config version should be \"1\", got \"${cfg_version}\""
        errors=$((errors + 1))
      fi
    fi
  elif command -v python3 >/dev/null 2>&1; then
    if ! python3 -c "import json; json.load(open('.omo/config.json'))" 2>/dev/null; then
      echo "  FAIL: .omo/config.json is not valid JSON"
      errors=$((errors + 1))
    else
      echo "  OK: valid JSON"
    fi
  else
    echo "  SKIP: no jq or python3 for JSON validation"
  fi
else
  echo "  SKIP: no .omo/config.json (optional)"
fi
echo ""

# ─── Hooks ────────────────────────────────────────────────────
echo "Hooks:"
if [ -d "hooks" ]; then
  if [ -f "hooks/hooks.json" ]; then
    if command -v jq >/dev/null 2>&1; then
      if ! jq empty hooks/hooks.json 2>/dev/null; then
        echo "  FAIL: hooks/hooks.json is not valid JSON"
        errors=$((errors + 1))
      else
        echo "  OK: hooks/hooks.json is valid JSON"
        # Verify expected hook events
        for event in Stop SessionStart Notification SubagentStop TeammateIdle TaskCompleted PreCompact; do
          if ! jq -e ".hooks.${event}" hooks/hooks.json >/dev/null 2>&1; then
            echo "  WARN: hooks/hooks.json missing '${event}' event"
          fi
        done
      fi
    elif command -v python3 >/dev/null 2>&1; then
      if ! python3 -c "import json; json.load(open('hooks/hooks.json'))" 2>/dev/null; then
        echo "  FAIL: hooks/hooks.json is not valid JSON"
        errors=$((errors + 1))
      else
        echo "  OK: hooks/hooks.json is valid JSON"
      fi
    else
      echo "  SKIP: no jq or python3 for JSON validation"
    fi
  else
    echo "  WARN: hooks/ directory exists but hooks.json not found"
  fi
else
  echo "  SKIP: no hooks/ directory (optional)"
fi
echo ""

# ─── Scripts ─────────────────────────────────────────────────
echo "Scripts:"
for script in scripts/*.sh; do
  script_name=$(basename "${script}")

  if ! head -1 "${script}" | grep -qE '^#!/'; then
    echo "  FAIL: ${script_name} missing shebang"
    errors=$((errors + 1))
  fi

  if [ ! -x "${script}" ]; then
    echo "  FAIL: ${script_name} not executable"
    errors=$((errors + 1))
  fi

  if ! bash -n "${script}" 2>/dev/null; then
    echo "  FAIL: ${script_name} syntax error"
    errors=$((errors + 1))
  fi
done
echo "  Checked $(ls scripts/*.sh | wc -l | tr -d ' ') scripts"
echo ""

# ─── Summary ─────────────────────────────────────────────────
echo "====================="
if [ "${errors}" -gt 0 ]; then
  echo "FAIL: ${errors} error(s) found"
  exit 1
else
  echo "PASS: All schemas valid"
  exit 0
fi
