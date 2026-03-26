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
done
echo "  Checked $(ls agents/*.md | wc -l | tr -d ' ') agents"
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
