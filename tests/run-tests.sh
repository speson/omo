#!/usr/bin/env bash
# omo integration test suite
# Usage: ./tests/run-tests.sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "${script_dir}/.." && pwd)
cd "${repo_root}"

pass=0
fail=0
total=0

run_test() {
  local name="$1"
  local cmd="$2"
  total=$((total + 1))
  printf "  %-50s " "${name}"
  if eval "${cmd}" >/dev/null 2>&1; then
    echo "PASS"
    pass=$((pass + 1))
  else
    echo "FAIL"
    fail=$((fail + 1))
  fi
}

echo "omo test suite"
echo "=============="
echo ""

# ─── Structure tests ────────────────────────────────────────
echo "Structure:"
run_test "plugin.json exists" "[ -f .claude-plugin/plugin.json ]"
run_test "marketplace.json exists" "[ -f .claude-plugin/marketplace.json ]"
run_test "plugin.json is valid JSON" "python3 -c \"import json; json.load(open('.claude-plugin/plugin.json'))\""
run_test "marketplace.json is valid JSON" "python3 -c \"import json; json.load(open('.claude-plugin/marketplace.json'))\""
run_test "skills/ directory exists" "[ -d skills ]"
run_test "agents/ directory exists" "[ -d agents ]"
run_test "scripts/ directory exists" "[ -d scripts ]"
run_test "templates/ directory exists" "[ -d templates ]"
run_test "examples/ directory exists" "[ -d examples ]"
echo ""

# ─── Version consistency ────────────────────────────────────
echo "Versions:"
run_test "Version consistency" "bash scripts/check-version.sh"
echo ""

# ─── Skill validation ───────────────────────────────────────
echo "Skills:"
for skill_dir in skills/*/; do
  skill_name=$(basename "${skill_dir}")
  run_test "skill/${skill_name}: SKILL.md exists" "[ -f '${skill_dir}SKILL.md' ]"
  run_test "skill/${skill_name}: has name field" "grep -q '^name:' '${skill_dir}SKILL.md'"
  run_test "skill/${skill_name}: name matches dir" "grep -q '^name: ${skill_name}$' '${skill_dir}SKILL.md'"
  run_test "skill/${skill_name}: has allowed-tools" "grep -q '^allowed-tools:' '${skill_dir}SKILL.md'"
done
echo ""

# ─── Agent validation ───────────────────────────────────────
echo "Agents:"
for agent_file in agents/*.md; do
  agent_name=$(basename "${agent_file}" .md)
  run_test "agent/${agent_name}: has name" "grep -q '^name:' '${agent_file}'"
  run_test "agent/${agent_name}: has model" "grep -q '^model:' '${agent_file}'"
  run_test "agent/${agent_name}: has maxTurns" "grep -q '^maxTurns:' '${agent_file}'"
  run_test "agent/${agent_name}: valid model" "grep -qE '^model: (haiku|sonnet|opus)$' '${agent_file}'"
done
echo ""

# ─── Script validation ──────────────────────────────────────
echo "Scripts:"
for script in scripts/*.sh; do
  script_name=$(basename "${script}")
  run_test "script/${script_name}: has shebang" "head -1 '${script}' | grep -qE '^#!/'"
  run_test "script/${script_name}: is executable" "[ -x '${script}' ]"
  run_test "script/${script_name}: bash syntax ok" "bash -n '${script}'"
done
echo ""

# ─── Ralph-loop state machine ───────────────────────────────
echo "Ralph-loop state machine:"
tmpdir=$(mktemp -d)
trap "rm -rf '${tmpdir}'" EXIT
cd "${tmpdir}"
mkdir -p .claude/state

run_test "start: creates state file" "bash '${repo_root}/scripts/ralph-loop-start.sh' 'test task' && [ -f .claude/state/ralph-loop.json ]"
run_test "start: phase is working" "grep -q '\"phase\":\"working\"' .claude/state/ralph-loop.json || grep -q '\"phase\": \"working\"' .claude/state/ralph-loop.json"
run_test "done: transitions phase" "bash '${repo_root}/scripts/ralph-loop-done.sh' && (grep -q '\"phase\":\"verified\"' .claude/state/ralph-loop.json || grep -q '\"phase\": \"verified\"' .claude/state/ralph-loop.json)"
run_test "cancel: removes state" "bash '${repo_root}/scripts/ralph-loop-start.sh' 'test2' && bash '${repo_root}/scripts/ralph-loop-cancel.sh' && [ ! -f .claude/state/ralph-loop.json ]"

# Oracle mode test
run_test "oracle: done→verification_pending" "bash '${repo_root}/scripts/ralph-loop-start.sh' 'oracle test' --oracle && bash '${repo_root}/scripts/ralph-loop-done.sh' && (grep -q '\"phase\":\"verification_pending\"' .claude/state/ralph-loop.json || grep -q '\"phase\": \"verification_pending\"' .claude/state/ralph-loop.json)"
run_test "oracle: verified→verified" "bash '${repo_root}/scripts/ralph-loop-verified.sh' && (grep -q '\"phase\":\"verified\"' .claude/state/ralph-loop.json || grep -q '\"phase\": \"verified\"' .claude/state/ralph-loop.json)"

cd "${repo_root}"
echo ""

# ─── Marketplace build ──────────────────────────────────────
echo "Marketplace:"
run_test "build-marketplace.sh succeeds" "bash scripts/build-marketplace.sh"
run_test "dist bundle exists" "[ -d dist/omo-marketplace/plugins/omo ]"
echo ""

# ─── Summary ────────────────────────────────────────────────
echo "=============="
echo "Total: ${total} | Pass: ${pass} | Fail: ${fail}"
if [ "${fail}" -gt 0 ]; then
  echo "RESULT: FAIL"
  exit 1
else
  echo "RESULT: PASS"
  exit 0
fi
