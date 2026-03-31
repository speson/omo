#!/usr/bin/env bash
# omo comprehensive backtest suite
# Tests all scripts with diverse input variations and edge cases
# Usage: ./tests/backtest.sh [section]
# Sections: ralph, briefing, hooks, tasks, version, schema, marketplace, misc, quality, templates, config, boulder, hookscripts, teamhooks, sprint6, nojq, evolve, hookjson, security, all
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/.." && pwd)

pass=0
fail=0
total=0
failures=""

run_test() {
  local name="$1"
  local cmd="$2"
  total=$((total + 1))
  printf "  %-60s " "${name}"
  local output
  if output=$(eval "${cmd}" 2>&1); then
    echo "PASS"
    pass=$((pass + 1))
  else
    echo "FAIL"
    fail=$((fail + 1))
    failures="${failures}\n  FAIL: ${name}"
    if [ -n "${output}" ]; then
      failures="${failures}\n        ${output}"
    fi
  fi
}

run_test_fail() {
  # Test that expects failure (non-zero exit)
  local name="$1"
  local cmd="$2"
  total=$((total + 1))
  printf "  %-60s " "${name}"
  if eval "${cmd}" >/dev/null 2>&1; then
    echo "FAIL (expected failure, got success)"
    fail=$((fail + 1))
    failures="${failures}\n  FAIL: ${name} (expected failure)"
  else
    echo "PASS"
    pass=$((pass + 1))
  fi
}

run_test_output() {
  # Test that checks output contains a string
  local name="$1"
  local cmd="$2"
  local expected="$3"
  total=$((total + 1))
  printf "  %-60s " "${name}"
  local output
  output=$(eval "${cmd}" 2>&1) || true
  if echo "${output}" | grep -q "${expected}"; then
    echo "PASS"
    pass=$((pass + 1))
  else
    echo "FAIL"
    fail=$((fail + 1))
    failures="${failures}\n  FAIL: ${name}"
    failures="${failures}\n        expected output to contain: ${expected}"
    failures="${failures}\n        got: ${output}"
  fi
}

section="${1:-all}"

echo "omo backtest suite"
echo "===================="
echo ""

# Create a shared temp directory
tmpdir=$(mktemp -d)
trap "rm -rf '${tmpdir}'" EXIT

# ═════════════════════════════════════════════════════════════════
# SECTION 1: Ralph-loop state machine
# ═════════════════════════════════════════════════════════════════
run_ralph_tests() {
  echo "Ralph-loop state machine:"
  echo "─────────────────────────"

  local rdir="${tmpdir}/ralph"
  mkdir -p "${rdir}/.claude/state"

  # --- Basic lifecycle ---
  echo ""
  echo "  [Basic lifecycle]"

  cd "${rdir}"
  run_test "start: basic create" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'hello world' && [ -f .claude/state/ralph-loop.json ]"

  run_test "start: phase is working" \
    "grep -q '\"phase\"' .claude/state/ralph-loop.json && (grep -q '\"working\"' .claude/state/ralph-loop.json)"

  run_test "start: iteration is 0" \
    "grep -q '\"iteration\"' .claude/state/ralph-loop.json && (grep -q '0' .claude/state/ralph-loop.json)"

  run_test "start: active is true" \
    "grep -q '\"active\"' .claude/state/ralph-loop.json && (grep -q 'true' .claude/state/ralph-loop.json)"

  run_test "start: prompt stored correctly" \
    "grep -q 'hello world' .claude/state/ralph-loop.json"

  run_test "done: non-oracle → verified" \
    "bash '${repo_root}/scripts/ralph-loop-done.sh' && grep -q 'verified' .claude/state/ralph-loop.json"

  run_test "guard: verified phase → exit 0" \
    "bash '${repo_root}/scripts/ralph-loop-guard.sh'"

  run_test "guard: state file removed after verified" \
    "[ ! -f .claude/state/ralph-loop.json ]"

  # --- Oracle lifecycle ---
  echo ""
  echo "  [Oracle lifecycle]"

  run_test "start --oracle: creates with oracle_verify" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'oracle task' --oracle && grep -q 'true' .claude/state/ralph-loop.json"

  run_test "done: oracle → verification_pending" \
    "bash '${repo_root}/scripts/ralph-loop-done.sh' && grep -q 'verification_pending' .claude/state/ralph-loop.json"

  run_test "guard: verification_pending → exit 2 (block)" \
    "! bash '${repo_root}/scripts/ralph-loop-guard.sh'"

  run_test_output "guard: verification_pending → ORACLE prompt" \
    "bash '${repo_root}/scripts/ralph-loop-guard.sh'" \
    "ORACLE VERIFICATION"

  run_test "verified: transitions to verified" \
    "bash '${repo_root}/scripts/ralph-loop-verified.sh' && grep -q 'verified' .claude/state/ralph-loop.json && ! grep -q 'verification_pending' .claude/state/ralph-loop.json"

  run_test "guard: verified → exit 0 (allow)" \
    "bash '${repo_root}/scripts/ralph-loop-guard.sh'"

  # --- Reject cycle ---
  echo ""
  echo "  [Reject cycle]"

  run_test "start: for reject test" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'reject test' --oracle"

  run_test "done: → verification_pending" \
    "bash '${repo_root}/scripts/ralph-loop-done.sh' && grep -q 'verification_pending' .claude/state/ralph-loop.json"

  run_test "reject: → back to working" \
    "bash '${repo_root}/scripts/ralph-loop-reject.sh' && grep -q 'working' .claude/state/ralph-loop.json"

  run_test "done again: → verification_pending again" \
    "bash '${repo_root}/scripts/ralph-loop-done.sh' && grep -q 'verification_pending' .claude/state/ralph-loop.json"

  run_test "verified: → verified" \
    "bash '${repo_root}/scripts/ralph-loop-verified.sh' && grep -q 'verified' .claude/state/ralph-loop.json"

  # Cleanup
  rm -f .claude/state/ralph-loop.json

  # --- Cancel ---
  echo ""
  echo "  [Cancel]"

  run_test "cancel: removes state" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'cancel test' && bash '${repo_root}/scripts/ralph-loop-cancel.sh' && [ ! -f .claude/state/ralph-loop.json ]"

  run_test_output "cancel: shows iteration count" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'cancel2' && bash '${repo_root}/scripts/ralph-loop-cancel.sh'" \
    "cancelled"

  # --- Max iterations ---
  echo ""
  echo "  [Max iterations]"

  run_test "start with max-iterations=2" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'max test' --max-iterations=2 && grep -q '\"max_iterations\"' .claude/state/ralph-loop.json"

  # Guard checks iteration BEFORE incrementing, so max_iterations=2 means:
  #   call 1: iter=0 (<2), increment→1, block
  #   call 2: iter=1 (<2), increment→2, block
  #   call 3: iter=2 (>=2), force stop
  run_test "guard: iteration 0→1, still blocks (exit 2)" \
    "! bash '${repo_root}/scripts/ralph-loop-guard.sh'"

  run_test "guard: iteration 1→2, still blocks (exit 2)" \
    "! bash '${repo_root}/scripts/ralph-loop-guard.sh'"

  run_test "guard: iteration 2 >= max(2) → force stop (exit 0)" \
    "bash '${repo_root}/scripts/ralph-loop-guard.sh'"

  run_test "guard: state removed after max reached" \
    "[ ! -f .claude/state/ralph-loop.json ]"

  # --- Custom promise ---
  echo ""
  echo "  [Custom promise]"

  # completion_promise removed in v1.9.0 — --promise flag no longer supported
  rm -f .claude/state/ralph-loop.json

  # --- Special characters in prompt ---
  echo ""
  echo "  [Special characters]"

  run_test "start: double quotes in prompt" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'say \"hello\" world' && grep -q 'hello' .claude/state/ralph-loop.json"
  rm -f .claude/state/ralph-loop.json

  run_test "start: single quotes in prompt" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' \"it's a test\" && grep -q 'test' .claude/state/ralph-loop.json"
  rm -f .claude/state/ralph-loop.json

  run_test "start: ampersand in prompt" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'foo & bar' && grep -q 'foo' .claude/state/ralph-loop.json"
  rm -f .claude/state/ralph-loop.json

  run_test "start: dollar sign in prompt" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'cost is \$100' && [ -f .claude/state/ralph-loop.json ]"
  rm -f .claude/state/ralph-loop.json

  run_test "start: backtick in prompt" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'run \`echo hi\`' && [ -f .claude/state/ralph-loop.json ]"
  rm -f .claude/state/ralph-loop.json

  run_test "start: unicode/Korean in prompt" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' '사용자 인증 구현' && grep -q '사용자' .claude/state/ralph-loop.json"
  rm -f .claude/state/ralph-loop.json

  run_test "start: angle brackets in prompt" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'fix <bug> in [code]' && [ -f .claude/state/ralph-loop.json ]"
  rm -f .claude/state/ralph-loop.json

  run_test "start: pipe and semicolon in prompt" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'cmd | grep; echo done' && [ -f .claude/state/ralph-loop.json ]"
  rm -f .claude/state/ralph-loop.json

  run_test "start: parentheses in prompt" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'function(arg1, arg2)' && [ -f .claude/state/ralph-loop.json ]"
  rm -f .claude/state/ralph-loop.json

  run_test "start: backslash in prompt" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'path\\\\to\\\\file' && [ -f .claude/state/ralph-loop.json ]"
  rm -f .claude/state/ralph-loop.json

  run_test "start: very long prompt (500+ chars)" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' \"\$(printf 'x%.0s' {1..500})\" && [ -f .claude/state/ralph-loop.json ]"
  rm -f .claude/state/ralph-loop.json

  # --- Error cases ---
  echo ""
  echo "  [Error cases]"

  run_test_fail "start: empty args → error" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh'"

  run_test_fail "done: no state file → error" \
    "rm -f .claude/state/ralph-loop.json && bash '${repo_root}/scripts/ralph-loop-done.sh'"

  run_test_fail "reject: no state file → error" \
    "rm -f .claude/state/ralph-loop.json && bash '${repo_root}/scripts/ralph-loop-reject.sh'"

  run_test_fail "verified: no state file → error" \
    "rm -f .claude/state/ralph-loop.json && bash '${repo_root}/scripts/ralph-loop-verified.sh'"

  run_test "cancel: no state file → no error" \
    "rm -f .claude/state/ralph-loop.json && bash '${repo_root}/scripts/ralph-loop-cancel.sh'"

  run_test "guard: no state file → exit 0 (allow)" \
    "rm -f .claude/state/ralph-loop.json && bash '${repo_root}/scripts/ralph-loop-guard.sh'"

  # --- Guard with inactive state ---
  echo ""
  echo "  [Guard with inactive/corrupted state]"

  run_test "guard: active=false → exit 0" \
    "echo '{\"active\":false,\"phase\":\"working\"}' > .claude/state/ralph-loop.json && bash '${repo_root}/scripts/ralph-loop-guard.sh'"

  # --- Verified called from wrong phase ---
  run_test "start: setup for wrong-phase verified" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'phase test'"

  run_test_fail "verified: from working phase → error" \
    "bash '${repo_root}/scripts/ralph-loop-verified.sh'"
  rm -f .claude/state/ralph-loop.json

  # --- JSON validity check ---
  echo ""
  echo "  [JSON validity]"

  run_test "start: output is valid JSON" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'json test' && python3 -c \"import json; json.load(open('.claude/state/ralph-loop.json'))\""
  rm -f .claude/state/ralph-loop.json

  run_test "start with quotes: output is valid JSON" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'has \"quotes\" and \\\\backslash' && python3 -c \"import json; json.load(open('.claude/state/ralph-loop.json'))\""
  rm -f .claude/state/ralph-loop.json

  run_test "start with unicode: output is valid JSON" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' '한국어 테스트 日本語' && python3 -c \"import json; json.load(open('.claude/state/ralph-loop.json'))\""
  rm -f .claude/state/ralph-loop.json

  # --- State transitions produce valid JSON ---
  run_test "full cycle: all JSON valid" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'json cycle' --oracle && \
     python3 -c \"import json; json.load(open('.claude/state/ralph-loop.json'))\" && \
     bash '${repo_root}/scripts/ralph-loop-done.sh' && \
     python3 -c \"import json; json.load(open('.claude/state/ralph-loop.json'))\" && \
     bash '${repo_root}/scripts/ralph-loop-reject.sh' && \
     python3 -c \"import json; json.load(open('.claude/state/ralph-loop.json'))\" && \
     bash '${repo_root}/scripts/ralph-loop-done.sh' && \
     python3 -c \"import json; json.load(open('.claude/state/ralph-loop.json'))\" && \
     bash '${repo_root}/scripts/ralph-loop-verified.sh' && \
     python3 -c \"import json; json.load(open('.claude/state/ralph-loop.json'))\""
  rm -f .claude/state/ralph-loop.json

  cd "${tmpdir}"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
# SECTION 2: Briefing system
# ═════════════════════════════════════════════════════════════════
run_briefing_tests() {
  echo "Briefing system:"
  echo "────────────────"

  local bdir="${tmpdir}/briefing"
  mkdir -p "${bdir}/.claude/state/briefings"
  cd "${bdir}"

  echo ""
  echo "  [write-briefing]"

  run_test "write: creates file with template" \
    "bash '${repo_root}/scripts/write-briefing.sh' planner my-task 'summary here' | grep -q '.md'"

  run_test "write: file exists in briefings dir" \
    "ls .claude/state/briefings/my-task-planner-*.md >/dev/null 2>&1"

  run_test "write: contains agent name" \
    "grep -q 'planner' .claude/state/briefings/my-task-planner-*.md"

  run_test "write: contains task slug" \
    "grep -q 'my-task' .claude/state/briefings/my-task-planner-*.md"

  run_test "write: second briefing for different agent" \
    "bash '${repo_root}/scripts/write-briefing.sh' critic my-task 'review done' | grep -q '.md'"

  run_test "write: special chars in slug" \
    "bash '${repo_root}/scripts/write-briefing.sh' builder 'fix-bug-123' 'fixed it' | grep -q '.md'"

  run_test_fail "write: missing agent arg → error" \
    "bash '${repo_root}/scripts/write-briefing.sh'"

  run_test_fail "write: missing slug arg → error" \
    "bash '${repo_root}/scripts/write-briefing.sh' planner"

  echo ""
  echo "  [read-briefings]"

  run_test_output "read: shows recent briefings" \
    "bash '${repo_root}/scripts/read-briefings.sh'" \
    "Recent Briefings"

  run_test_output "read: count=1 limits output" \
    "bash '${repo_root}/scripts/read-briefings.sh' 1" \
    "Recent Briefings"

  run_test_output "read: filter by slug" \
    "bash '${repo_root}/scripts/read-briefings.sh' 5 my-task" \
    "my-task"

  run_test_output "read: filter with no match → no briefings" \
    "bash '${repo_root}/scripts/read-briefings.sh' 5 nonexistent-slug-xyz" \
    "No briefings found"

  echo ""
  echo "  [read-briefings: empty state]"

  local bdir2="${tmpdir}/briefing-empty"
  mkdir -p "${bdir2}"
  cd "${bdir2}"

  run_test_output "read: no briefings dir → message" \
    "bash '${repo_root}/scripts/read-briefings.sh'" \
    "No briefings"

  cd "${bdir}"

  echo ""
  echo "  [escalation-check]"

  # Create briefings with known confidence levels
  mkdir -p "${tmpdir}/esc/.claude/state/briefings"
  cd "${tmpdir}/esc"

  cat > .claude/state/briefings/high-conf.md <<'BEOF'
# Agent Briefing
## Metadata
- Confidence: HIGH
- Escalation: none
BEOF

  cat > .claude/state/briefings/low-conf.md <<'BEOF'
# Agent Briefing
## Metadata
- Confidence: LOW
- Escalation: recommended
BEOF

  run_test_output "escalation: detects HIGH confidence" \
    "bash '${repo_root}/scripts/escalation-check.sh' .claude/state/briefings/high-conf.md" \
    "OK"

  run_test_output "escalation: detects LOW confidence" \
    "bash '${repo_root}/scripts/escalation-check.sh' .claude/state/briefings/low-conf.md" \
    "ESCALATE"

  # Exit code 2 when escalation needed
  run_test_fail "escalation: exit 2 for LOW confidence" \
    "bash '${repo_root}/scripts/escalation-check.sh' .claude/state/briefings/low-conf.md"

  run_test "escalation: exit 0 for HIGH confidence" \
    "bash '${repo_root}/scripts/escalation-check.sh' .claude/state/briefings/high-conf.md"

  # MEDIUM confidence, no escalation
  cat > .claude/state/briefings/medium-conf.md <<'BEOF'
# Agent Briefing
## Metadata
- Confidence: MEDIUM
- Escalation: none
BEOF

  run_test "escalation: MEDIUM no-escalation → exit 0" \
    "bash '${repo_root}/scripts/escalation-check.sh' .claude/state/briefings/medium-conf.md"

  # Escalation recommended but HIGH confidence
  cat > .claude/state/briefings/high-escalate.md <<'BEOF'
# Agent Briefing
## Metadata
- Confidence: HIGH
- Escalation: recommended
BEOF

  run_test_fail "escalation: recommended overrides HIGH → exit 2" \
    "bash '${repo_root}/scripts/escalation-check.sh' .claude/state/briefings/high-escalate.md"

  # All briefings check (directory scan)
  run_test_output "escalation: directory scan finds issues" \
    "bash '${repo_root}/scripts/escalation-check.sh'" \
    "escalation"

  cd "${tmpdir}"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
# SECTION 3: ensure-hooks
# ═════════════════════════════════════════════════════════════════
run_hooks_tests() {
  echo "ensure-hooks:"
  echo "─────────────"

  echo ""
  echo "  [Plugin hooks detection]"

  # When run from repo root, ensure-hooks.sh detects hooks/hooks.json
  run_test_output "hooks: detects plugin hooks from script dir" \
    "bash '${repo_root}/scripts/ensure-hooks.sh'" \
    "hooks"

  # With CLAUDE_PLUGIN_ROOT set
  run_test_output "hooks: detects plugin hooks via CLAUDE_PLUGIN_ROOT" \
    "CLAUDE_PLUGIN_ROOT='${repo_root}' bash '${repo_root}/scripts/ensure-hooks.sh'" \
    "Plugin hooks detected"

  echo ""
  echo "  [Legacy path - isolated script]"

  # Copy ensure-hooks.sh to an isolated location to test legacy path
  local iso_dir="${tmpdir}/hooks-isolated"
  mkdir -p "${iso_dir}/scripts" "${iso_dir}/.claude"
  cp "${repo_root}/scripts/ensure-hooks.sh" "${iso_dir}/scripts/"
  cd "${iso_dir}"

  run_test "hooks: creates settings from scratch (legacy)" \
    "bash '${iso_dir}/scripts/ensure-hooks.sh' && [ -f .claude/settings.local.json ]"

  run_test "hooks: settings contains ralph-loop-guard" \
    "grep -q 'ralph-loop-guard' .claude/settings.local.json"

  run_test "hooks: settings is valid JSON" \
    "python3 -c \"import json; json.load(open('.claude/settings.local.json'))\""

  # Uses object format, not string format
  run_test "hooks: uses object format (not string)" \
    "grep -q '\"type\"' .claude/settings.local.json"

  echo ""
  echo "  [Idempotent - already registered]"

  run_test "hooks: second run is no-op (idempotent)" \
    "bash '${iso_dir}/scripts/ensure-hooks.sh'"

  run_test_output "hooks: second run says already registered" \
    "bash '${iso_dir}/scripts/ensure-hooks.sh'" \
    "already registered"

  echo ""
  echo "  [Existing settings without hooks]"

  local hdir2="${tmpdir}/hooks-existing"
  mkdir -p "${hdir2}/.claude" "${hdir2}/scripts"
  cp "${repo_root}/scripts/ensure-hooks.sh" "${hdir2}/scripts/"
  cd "${hdir2}"

  echo '{"permissions":{"allow":["Read","Write"]}}' > .claude/settings.local.json

  if command -v jq >/dev/null 2>&1; then
    run_test "hooks: merges into existing settings (jq)" \
      "bash '${hdir2}/scripts/ensure-hooks.sh' && grep -q 'ralph-loop-guard' .claude/settings.local.json"

    run_test "hooks: preserves existing fields" \
      "grep -q 'permissions' .claude/settings.local.json"

    run_test "hooks: merged result is valid JSON" \
      "python3 -c \"import json; json.load(open('.claude/settings.local.json'))\""
  else
    run_test_output "hooks: warns about manual merge without jq" \
      "bash '${hdir2}/scripts/ensure-hooks.sh' || true" \
      "Cannot auto-merge"
  fi

  echo ""
  echo "  [Existing settings with hooks section]"

  local hdir3="${tmpdir}/hooks-has-hooks"
  mkdir -p "${hdir3}/.claude" "${hdir3}/scripts"
  cp "${repo_root}/scripts/ensure-hooks.sh" "${hdir3}/scripts/"
  cd "${hdir3}"

  echo '{"hooks":{"PreToolUse":[{"matcher":"","hooks":["echo test"]}]}}' > .claude/settings.local.json

  run_test_fail "hooks: existing hooks section without guard → exit 1" \
    "bash '${hdir3}/scripts/ensure-hooks.sh'"

  run_test_output "hooks: tells user to add manually" \
    "bash '${hdir3}/scripts/ensure-hooks.sh' 2>&1 || true" \
    "manually"

  cd "${tmpdir}"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
# SECTION 4: Task notes and history
# ═════════════════════════════════════════════════════════════════
run_tasks_tests() {
  echo "Task notes and history:"
  echo "───────────────────────"

  echo ""
  echo "  [new-task-note]"

  local tdir="${tmpdir}/tasks"
  mkdir -p "${tdir}"
  cd "${tdir}"
  git init -q . 2>/dev/null || true

  run_test "task-note: creates file" \
    "bash '${repo_root}/scripts/new-task-note.sh' 'My Test Task' | grep -q '.md'"

  run_test "task-note: file exists in tasks dir" \
    "ls .claude/state/tasks/*.md >/dev/null 2>&1"

  run_test "task-note: current-task.txt updated" \
    "[ -f .claude/state/current-task.txt ] && [ -s .claude/state/current-task.txt ]"

  run_test "task-note: slug is lowercase hyphenated" \
    "ls .claude/state/tasks/ | head -1 | grep -q 'my-test-task'"

  # Special characters in title
  run_test "task-note: uppercase → lowercase slug" \
    "bash '${repo_root}/scripts/new-task-note.sh' 'UPPERCASE TITLE' | grep -q 'uppercase-title'"

  run_test "task-note: symbols removed from slug" \
    "bash '${repo_root}/scripts/new-task-note.sh' 'fix: bug #123!' | grep -q '.md'"

  run_test "task-note: unicode title → slug" \
    "bash '${repo_root}/scripts/new-task-note.sh' '사용자 인증' | grep -q '.md'"

  run_test "task-note: dots and slashes in title" \
    "bash '${repo_root}/scripts/new-task-note.sh' 'fix/path.to.file' | grep -q '.md'"

  run_test "task-note: empty-ish title → fallback slug" \
    "bash '${repo_root}/scripts/new-task-note.sh' '!!!' | grep -q '.md'"

  run_test_fail "task-note: no args → error" \
    "bash '${repo_root}/scripts/new-task-note.sh'"

  echo ""
  echo "  [log-task-event]"

  run_test "log-event: creates log file" \
    "bash '${repo_root}/scripts/log-task-event.sh' created my-task 'initial creation' && [ -f .claude/state/task-history.log ]"

  run_test "log-event: log contains event" \
    "grep -q 'created' .claude/state/task-history.log && grep -q 'my-task' .claude/state/task-history.log"

  run_test "log-event: appends (doesn't overwrite)" \
    "bash '${repo_root}/scripts/log-task-event.sh' started my-task 'starting work' && [ \$(wc -l < .claude/state/task-history.log) -ge 2 ]"

  run_test "log-event: all event types work" \
    "bash '${repo_root}/scripts/log-task-event.sh' completed my-task 'done' && \
     bash '${repo_root}/scripts/log-task-event.sh' cancelled other-task 'cancelled' && \
     bash '${repo_root}/scripts/log-task-event.sh' handoff other-task 'handing off'"

  run_test "log-event: has timestamp format" \
    "grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}T' .claude/state/task-history.log"

  run_test_fail "log-event: no args → error" \
    "bash '${repo_root}/scripts/log-task-event.sh'"

  run_test_fail "log-event: only event, no slug → error" \
    "bash '${repo_root}/scripts/log-task-event.sh' created"

  cd "${tmpdir}"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
# SECTION 5: Version consistency
# ═════════════════════════════════════════════════════════════════
run_version_tests() {
  echo "Version consistency:"
  echo "────────────────────"

  echo ""
  echo "  [Matching versions]"

  run_test "check-version: all match" \
    "cd '${repo_root}' && bash scripts/check-version.sh"

  run_test_output "check-version: shows PASS" \
    "cd '${repo_root}' && bash scripts/check-version.sh" \
    "PASS"

  echo ""
  echo "  [Mismatched versions]"

  local vdir="${tmpdir}/version"
  mkdir -p "${vdir}/.claude-plugin"
  mkdir -p "${vdir}/scripts"
  cp "${repo_root}/scripts/check-version.sh" "${vdir}/scripts/"
  cd "${vdir}"

  echo '{"name":"test","version":"2.0.0"}' > .claude-plugin/plugin.json
  echo '{"metadata":{"version":"1.0.0"},"plugins":[{"version":"1.0.0"}]}' > .claude-plugin/marketplace.json

  run_test_fail "check-version: mismatch → exit 1" \
    "bash scripts/check-version.sh"

  run_test_output "check-version: mismatch → FAIL message" \
    "bash scripts/check-version.sh 2>&1 || true" \
    "FAIL"

  echo ""
  echo "  [Missing marketplace.json]"

  rm -f .claude-plugin/marketplace.json
  run_test "check-version: missing marketplace → warning only" \
    "bash scripts/check-version.sh"

  cd "${tmpdir}"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
# SECTION 6: Schema validation
# ═════════════════════════════════════════════════════════════════
run_schema_tests() {
  echo "Schema validation:"
  echo "──────────────────"

  run_test "validate-schema: full repo passes" \
    "cd '${repo_root}' && bash scripts/validate-schema.sh"

  run_test_output "validate-schema: shows PASS" \
    "cd '${repo_root}' && bash scripts/validate-schema.sh" \
    "PASS"

  echo ""
  echo "  [Broken schema detection]"

  local sdir="${tmpdir}/schema"
  mkdir -p "${sdir}/.claude-plugin"
  mkdir -p "${sdir}/skills/broken-skill"
  mkdir -p "${sdir}/agents"
  mkdir -p "${sdir}/scripts"
  cp "${repo_root}/scripts/validate-schema.sh" "${sdir}/scripts/"
  chmod +x "${sdir}/scripts/validate-schema.sh"
  cd "${sdir}"

  # Valid plugin.json
  echo '{"name":"test","description":"test","version":"1.0.0"}' > .claude-plugin/plugin.json

  # Broken skill: missing name field
  cat > skills/broken-skill/SKILL.md <<'SKILLEOF'
---
description: "broken skill"
allowed-tools: Read
---
Do nothing.
SKILLEOF

  # Valid agent
  cat > agents/test-agent.md <<'AGENTEOF'
---
name: test-agent
description: "test agent"
tools: Read
model: sonnet
maxTurns: 5
---
You are a test agent.
AGENTEOF

  # Script with no shebang
  echo 'echo "no shebang"' > scripts/bad.sh
  chmod +x scripts/bad.sh

  run_test_fail "validate-schema: broken skill → fails" \
    "bash scripts/validate-schema.sh"

  cd "${tmpdir}"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
# SECTION 7: Marketplace build
# ═════════════════════════════════════════════════════════════════
run_marketplace_tests() {
  echo "Marketplace build:"
  echo "──────────────────"

  run_test "marketplace: build succeeds" \
    "cd '${repo_root}' && bash scripts/build-marketplace.sh"

  run_test "marketplace: dist exists" \
    "[ -d '${repo_root}/dist/omo-marketplace' ]"

  run_test "marketplace: plugin bundle has skills" \
    "[ -d '${repo_root}/dist/omo-marketplace/plugins/omo/skills' ]"

  run_test "marketplace: plugin bundle has agents" \
    "[ -d '${repo_root}/dist/omo-marketplace/plugins/omo/agents' ]"

  run_test "marketplace: plugin bundle has scripts" \
    "[ -d '${repo_root}/dist/omo-marketplace/plugins/omo/scripts' ]"

  run_test "marketplace: marketplace.json has correct version" \
    "cd '${repo_root}' && \
     pv=\$(python3 -c \"import json; print(json.load(open('.claude-plugin/plugin.json'))['version'])\") && \
     mv=\$(python3 -c \"import json; print(json.load(open('dist/omo-marketplace/.claude-plugin/marketplace.json'))['metadata']['version'])\") && \
     [ \"\${pv}\" = \"\${mv}\" ]"

  run_test "marketplace: bundle marketplace.json is valid JSON" \
    "python3 -c \"import json; json.load(open('${repo_root}/dist/omo-marketplace/.claude-plugin/marketplace.json'))\""

  run_test "marketplace: bundle plugin.json is valid JSON" \
    "python3 -c \"import json; json.load(open('${repo_root}/dist/omo-marketplace/plugins/omo/.claude-plugin/plugin.json'))\""

  echo ""
}

# ═════════════════════════════════════════════════════════════════
# SECTION 8: Miscellaneous scripts
# ═════════════════════════════════════════════════════════════════
run_misc_tests() {
  echo "Miscellaneous scripts:"
  echo "──────────────────────"

  echo ""
  echo "  [statusline]"

  run_test_output "statusline: outputs cc: prefix" \
    "cd '${repo_root}' && bash scripts/statusline.sh" \
    "cc:"

  run_test_output "statusline: includes git info" \
    "cd '${repo_root}' && bash scripts/statusline.sh" \
    "git:"

  # Test without current task
  local mdir="${tmpdir}/misc"
  mkdir -p "${mdir}"
  cd "${mdir}"

  run_test_output "statusline: works without .claude dir" \
    "bash '${repo_root}/scripts/statusline.sh'" \
    "cc:"

  echo ""
  echo "  [latest-context]"

  cd "${repo_root}"
  run_test_output "latest-context: outputs repo path" \
    "bash scripts/latest-context.sh" \
    "repo:"

  # With a current task
  local cdir="${tmpdir}/context"
  mkdir -p "${cdir}/.claude/state"
  cd "${cdir}"
  git init -q . 2>/dev/null || true
  echo "/tmp/fake-task.md" > .claude/state/current-task.txt

  run_test_output "latest-context: shows current task" \
    "bash '${repo_root}/scripts/latest-context.sh'" \
    "current-task:"

  # Without any state
  local cdir2="${tmpdir}/context-empty"
  mkdir -p "${cdir2}"
  cd "${cdir2}"

  run_test_output "latest-context: no state → current-task: none" \
    "bash '${repo_root}/scripts/latest-context.sh'" \
    "none"

  echo ""
  echo "  [notify]"

  run_test "notify: default args work" \
    "bash '${repo_root}/scripts/notify.sh'"

  run_test "notify: custom title and message" \
    "bash '${repo_root}/scripts/notify.sh' 'Test Title' 'Test message body'"

  run_test "notify: special chars in message" \
    "bash '${repo_root}/scripts/notify.sh' 'omo' 'Task \"done\" with <brackets>'"

  echo ""
  echo "  [mcp-doctor]"

  # Without .mcp.json
  local mcpdir="${tmpdir}/mcp-nomcp"
  mkdir -p "${mcpdir}"
  cd "${mcpdir}"

  run_test_output "mcp-doctor: no config → missing" \
    "bash '${repo_root}/scripts/mcp-doctor.sh'" \
    "missing"

  # With placeholder
  mkdir -p "${tmpdir}/mcp-placeholder"
  cd "${tmpdir}/mcp-placeholder"
  cat > .mcp.json <<'MCPEOF'
{
  "mcpServers": {
    "github": {
      "command": "REPLACE_WITH_YOUR_TOKEN"
    }
  }
}
MCPEOF

  run_test_output "mcp-doctor: detects placeholders" \
    "bash '${repo_root}/scripts/mcp-doctor.sh'" \
    "placeholders: yes"

  echo ""
  echo "  [release --dry-run]"

  cd "${repo_root}"
  # Note: release.sh will fail on tag-exists check since v1.0.0 already exists
  # We just verify it runs its checks
  run_test_output "release: dry-run runs checks" \
    "bash scripts/release.sh --dry-run 2>&1 || true" \
    "release"

  cd "${tmpdir}"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
# SECTION 9: Skill prompt quality
# ═════════════════════════════════════════════════════════════════
run_skill_quality_tests() {
  echo "Skill/Agent prompt quality:"
  echo "───────────────────────────"

  cd "${repo_root}"

  echo ""
  echo "  [Skill frontmatter completeness]"

  for skill_dir in skills/*/; do
    skill_name=$(basename "${skill_dir}")
    skill_file="${skill_dir}SKILL.md"

    run_test "skill/${skill_name}: has description" \
      "grep -q '^description:' '${skill_file}'"

    # Check that skills referencing agents use valid agent names
    # Extract agent references from skill body
    run_test "skill/${skill_name}: no empty body after frontmatter" \
      "awk '/^---$/{n++; next} n==2{found=1} found{print}' '${skill_file}' | grep -q '[a-zA-Z]'"
  done

  echo ""
  echo "  [Agent prompt completeness]"

  for agent_file in agents/*.md; do
    agent_name=$(basename "${agent_file}" .md)

    run_test "agent/${agent_name}: has description" \
      "grep -q '^description:' '${agent_file}'"

    run_test "agent/${agent_name}: has tools field" \
      "grep -q '^tools:' '${agent_file}'"

    # Check for body content after frontmatter
    run_test "agent/${agent_name}: has prompt body" \
      "awk '/^---$/{n++; next} n==2{found=1} found{print}' '${agent_file}' | grep -q '[a-zA-Z]'"
  done

  echo ""
  echo "  [Cross-reference validity]"

  # Check that skills reference valid agent subagent_types
  local valid_agents
  valid_agents=$(ls agents/*.md | xargs -I{} basename {} .md | tr '\n' '|' | sed 's/|$//')

  # Check scripts referenced in skills exist
  for skill_dir in skills/*/; do
    skill_name=$(basename "${skill_dir}")
    skill_file="${skill_dir}SKILL.md"

    # Find script references like scripts/something.sh
    local script_refs
    script_refs=$(grep -oE 'scripts/[a-z0-9_-]+\.sh' "${skill_file}" 2>/dev/null || true)
    if [ -n "${script_refs}" ]; then
      for script_ref in ${script_refs}; do
        run_test "skill/${skill_name}: references valid script ${script_ref}" \
          "[ -f '${script_ref}' ]"
      done
    fi
  done

  # Check agents referenced in skills exist
  for skill_dir in skills/*/; do
    skill_name=$(basename "${skill_dir}")
    skill_file="${skill_dir}SKILL.md"

    # Find agent references like `planner-sisyphus`, `build-integrator`, etc.
    local agent_refs
    agent_refs=$(grep -oE '\b(atlas|planner-sisyphus|critic|critic-lite|build-integrator|build-integrator-heavy|bug-hunter|oracle|oracle-lite|repo-librarian|repo-librarian-deep|deepsearch|test-commander|docs-keeper|vision|perf-analyst|memory-keeper|security-auditor|test-generator|migration-specialist)\b' "${skill_file}" 2>/dev/null | sort -u || true)
    if [ -n "${agent_refs}" ]; then
      for agent_ref in ${agent_refs}; do
        run_test "skill/${skill_name}: references valid agent ${agent_ref}" \
          "[ -f 'agents/${agent_ref}.md' ]"
      done
    fi
  done

  echo ""
  echo "  [Metadata protocol compliance]"

  # Check that agents have Confidence/Escalation in their prompts
  for agent_file in agents/*.md; do
    agent_name=$(basename "${agent_file}" .md)
    run_test "agent/${agent_name}: mentions Confidence or metadata" \
      "grep -qi 'confidence\|metadata\|escalat' '${agent_file}'"
  done

  cd "${tmpdir}"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
# SECTION 10: Template validation
# ═════════════════════════════════════════════════════════════════
run_template_tests() {
  echo "Templates:"
  echo "──────────"

  cd "${repo_root}"

  run_test "template: task-note.md exists" \
    "[ -f templates/task-note.md ]"

  run_test "template: briefing.md exists" \
    "[ -f templates/briefing.md ]"

  run_test "template: briefing has placeholders" \
    "grep -q '\[agent-name\]' templates/briefing.md"

  run_test "template: briefing has Confidence field" \
    "grep -q 'Confidence' templates/briefing.md"

  run_test "template: briefing has Escalation field" \
    "grep -q 'Escalation' templates/briefing.md"

  run_test "template: task-note has Goal section" \
    "grep -q 'Goal' templates/task-note.md"

  run_test "template: task-note has Verification section" \
    "grep -q 'Verification' templates/task-note.md"

  echo ""
  echo "  [Examples]"

  for example in examples/*.example; do
    ename=$(basename "${example}")
    run_test "example/${ename}: exists and non-empty" \
      "[ -s '${example}' ]"
  done

  cd "${tmpdir}"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
# SECTION 11: Config system
# ═════════════════════════════════════════════════════════════════
run_config_tests() {
  echo "Config system:"
  echo "──────────────"

  # Scripts resolve repo_root from their own location, so we create a
  # self-contained mini-repo in the temp dir with copies of the scripts.
  local cdir="${tmpdir}/config"
  mkdir -p "${cdir}/scripts" "${cdir}/agents"
  cp "${repo_root}/scripts/init-config.sh" "${cdir}/scripts/"
  cp "${repo_root}/scripts/validate-config.sh" "${cdir}/scripts/"
  cp "${repo_root}/scripts/read-config.sh" "${cdir}/scripts/"
  cp "${repo_root}/scripts/apply-config.sh" "${cdir}/scripts/"
  cp "${repo_root}/scripts/list-agents-by-category.sh" "${cdir}/scripts/"
  chmod +x "${cdir}/scripts/"*.sh

  cd "${cdir}"

  echo ""
  echo "  [init-config]"

  run_test "init-config: creates .omo/config.json" \
    "bash scripts/init-config.sh && [ -f .omo/config.json ]"

  run_test "init-config: output is valid JSON" \
    "python3 -c \"import json; json.load(open('.omo/config.json'))\""

  run_test "init-config: has version field" \
    "grep -q '\"version\"' .omo/config.json"

  run_test "init-config: has categories" \
    "grep -q '\"categories\"' .omo/config.json"

  run_test "init-config: has ralph-loop settings" \
    "grep -q '\"ralph-loop\"' .omo/config.json"

  run_test "init-config: has spawn settings" \
    "grep -q '\"spawn\"' .omo/config.json"

  run_test_output "init-config: no --force → already exists" \
    "bash scripts/init-config.sh" \
    "already exists"

  run_test_output "init-config: --force overwrites" \
    "bash scripts/init-config.sh --force" \
    "overwritten"

  echo ""
  echo "  [validate-config]"

  run_test "validate-config: default config passes" \
    "bash scripts/validate-config.sh"

  run_test_output "validate-config: shows PASS" \
    "bash scripts/validate-config.sh" \
    "PASS"

  # Invalid JSON
  local cdir2="${tmpdir}/config-bad"
  mkdir -p "${cdir2}/scripts"
  cp "${cdir}/scripts/validate-config.sh" "${cdir2}/scripts/"
  chmod +x "${cdir2}/scripts/validate-config.sh"
  mkdir -p "${cdir2}/.omo"
  echo "not json" > "${cdir2}/.omo/config.json"

  run_test_fail "validate-config: invalid JSON → fail" \
    "cd '${cdir2}' && bash scripts/validate-config.sh"

  # No config file
  local cdir3="${tmpdir}/config-none"
  mkdir -p "${cdir3}/scripts"
  cp "${cdir}/scripts/validate-config.sh" "${cdir3}/scripts/"
  cp "${cdir}/scripts/read-config.sh" "${cdir3}/scripts/"
  chmod +x "${cdir3}/scripts/"*.sh

  run_test "validate-config: no config → exit 0" \
    "cd '${cdir3}' && bash scripts/validate-config.sh"

  cd "${cdir}"

  echo ""
  echo "  [read-config]"

  run_test_output "read-config: reads category model" \
    "bash scripts/read-config.sh categories.fast-search.model haiku" \
    "haiku"

  run_test_output "read-config: reads max_iterations" \
    "bash scripts/read-config.sh ralph-loop.max_iterations 100" \
    "100"

  run_test_output "read-config: reads spawn max" \
    "bash scripts/read-config.sh spawn.max_concurrent_agents 5" \
    "5"

  run_test_output "read-config: missing key → default" \
    "bash scripts/read-config.sh nonexistent.key fallback" \
    "fallback"

  # No config file → default
  run_test_output "read-config: no config → default" \
    "cd '${cdir3}' && bash scripts/read-config.sh categories.fast-search.model haiku" \
    "haiku"

  cd "${cdir}"

  echo ""
  echo "  [apply-config]"

  # Set up a test agent for apply-config
  cat > agents/test-agent.md <<'AGENTEOF'
---
name: test-agent
description: test agent
tools: Read
model: haiku
category: fast-search
maxTurns: 5
---
You are a test agent.
AGENTEOF

  run_test_output "apply-config: --dry-run shows no changes" \
    "bash scripts/apply-config.sh --dry-run" \
    "unchanged"

  run_test "apply-config: --dry-run does not modify files" \
    "grep -q '^model: haiku' agents/test-agent.md"

  run_test "apply-config: apply keeps matching model" \
    "bash scripts/apply-config.sh && grep -q '^model: haiku' agents/test-agent.md"

  echo ""
  echo "  [list-agents-by-category]"

  cd "${repo_root}"

  run_test "list-agents: runs without error" \
    "bash scripts/list-agents-by-category.sh"

  run_test_output "list-agents: shows fast-search" \
    "bash scripts/list-agents-by-category.sh" \
    "fast-search"

  run_test_output "list-agents: filter by category" \
    "bash scripts/list-agents-by-category.sh planning" \
    "planner-sisyphus"

  run_test_fail "list-agents: invalid category → fail" \
    "bash scripts/list-agents-by-category.sh nonexistent-category"

  echo ""
  echo "  [round-trip pipeline]"

  local cdir4="${tmpdir}/config-roundtrip"
  mkdir -p "${cdir4}/scripts" "${cdir4}/agents"
  cp "${cdir}/scripts/"*.sh "${cdir4}/scripts/"
  chmod +x "${cdir4}/scripts/"*.sh
  cat > "${cdir4}/agents/roundtrip-agent.md" <<'AGENTEOF'
---
name: roundtrip-agent
description: roundtrip test
tools: Read
model: sonnet
category: fast-search
maxTurns: 5
---
Test agent.
AGENTEOF

  run_test "round-trip: init → validate → apply-dry-run" \
    "cd '${cdir4}' && bash scripts/init-config.sh && \
     bash scripts/validate-config.sh && \
     bash scripts/apply-config.sh --dry-run"

  echo ""
  echo "  [agent category field presence]"

  cd "${repo_root}"
  for agent_file in agents/*.md; do
    agent_name=$(basename "${agent_file}" .md)
    run_test "agent/${agent_name}: has category field" \
      "grep -q '^category:' '${agent_file}'"
  done

  echo ""
  echo "  [validate-config branch coverage]"

  local vcbase="${tmpdir}/vc-base"
  mkdir -p "${vcbase}/scripts"
  cp "${cdir}/scripts/validate-config.sh" "${vcbase}/scripts/"
  chmod +x "${vcbase}/scripts/validate-config.sh"

  # 1 — missing version field
  local vc1="${tmpdir}/vc-missing-version"
  mkdir -p "${vc1}/scripts" "${vc1}/.omo"
  cp "${vcbase}/scripts/validate-config.sh" "${vc1}/scripts/"
  printf '{"categories":{"fast-search":{"model":"haiku"}}}\n' > "${vc1}/.omo/config.json"
  run_test_output "validate: missing version -> error" \
    "cd '${vc1}' && bash scripts/validate-config.sh" \
    "ERROR"
  run_test_fail "validate: missing version -> exit 1" \
    "cd '${vc1}' && bash scripts/validate-config.sh"

  # 2 — wrong version
  local vc2="${tmpdir}/vc-wrong-version"
  mkdir -p "${vc2}/scripts" "${vc2}/.omo"
  cp "${vcbase}/scripts/validate-config.sh" "${vc2}/scripts/"
  printf '{"version":"2","categories":{"fast-search":{"model":"haiku"}}}\n' > "${vc2}/.omo/config.json"
  run_test_output "validate: wrong version -> error" \
    "cd '${vc2}' && bash scripts/validate-config.sh" \
    "ERROR"
  run_test_fail "validate: wrong version -> exit 1" \
    "cd '${vc2}' && bash scripts/validate-config.sh"

  # 3 — unknown category
  local vc3="${tmpdir}/vc-bad-category"
  mkdir -p "${vc3}/scripts" "${vc3}/.omo"
  cp "${vcbase}/scripts/validate-config.sh" "${vc3}/scripts/"
  printf '{"version":"1","categories":{"invalid-cat":{"model":"haiku"}}}\n' > "${vc3}/.omo/config.json"
  run_test_output "validate: unknown category -> error" \
    "cd '${vc3}' && bash scripts/validate-config.sh" \
    "ERROR"
  run_test_fail "validate: unknown category -> exit 1" \
    "cd '${vc3}' && bash scripts/validate-config.sh"

  # 4 — missing model in category
  local vc4="${tmpdir}/vc-no-model"
  mkdir -p "${vc4}/scripts" "${vc4}/.omo"
  cp "${vcbase}/scripts/validate-config.sh" "${vc4}/scripts/"
  printf '{"version":"1","categories":{"fast-search":{}}}\n' > "${vc4}/.omo/config.json"
  run_test_output "validate: missing model in category -> error" \
    "cd '${vc4}' && bash scripts/validate-config.sh" \
    "ERROR"
  run_test_fail "validate: missing model in category -> exit 1" \
    "cd '${vc4}' && bash scripts/validate-config.sh"

  # 5 — invalid model value
  local vc5="${tmpdir}/vc-bad-model"
  mkdir -p "${vc5}/scripts" "${vc5}/.omo"
  cp "${vcbase}/scripts/validate-config.sh" "${vc5}/scripts/"
  printf '{"version":"1","categories":{"fast-search":{"model":"gpt4"}}}\n' > "${vc5}/.omo/config.json"
  run_test_output "validate: invalid model -> error" \
    "cd '${vc5}' && bash scripts/validate-config.sh" \
    "ERROR"
  run_test_fail "validate: invalid model -> exit 1" \
    "cd '${vc5}' && bash scripts/validate-config.sh"

  # 6 — max_iterations negative
  local vc6="${tmpdir}/vc-iter-neg"
  mkdir -p "${vc6}/scripts" "${vc6}/.omo"
  cp "${vcbase}/scripts/validate-config.sh" "${vc6}/scripts/"
  printf '{"version":"1","categories":{"fast-search":{"model":"haiku"}},"ralph-loop":{"max_iterations":-1}}\n' \
    > "${vc6}/.omo/config.json"
  run_test_output "validate: max_iterations negative -> error" \
    "cd '${vc6}' && bash scripts/validate-config.sh" \
    "ERROR"
  run_test_fail "validate: max_iterations negative -> exit 1" \
    "cd '${vc6}' && bash scripts/validate-config.sh"

  # 7 — max_iterations string
  local vc7="${tmpdir}/vc-iter-str"
  mkdir -p "${vc7}/scripts" "${vc7}/.omo"
  cp "${vcbase}/scripts/validate-config.sh" "${vc7}/scripts/"
  printf '{"version":"1","categories":{"fast-search":{"model":"haiku"}},"ralph-loop":{"max_iterations":"abc"}}\n' \
    > "${vc7}/.omo/config.json"
  run_test_output "validate: max_iterations string -> error" \
    "cd '${vc7}' && bash scripts/validate-config.sh" \
    "ERROR"
  run_test_fail "validate: max_iterations string -> exit 1" \
    "cd '${vc7}' && bash scripts/validate-config.sh"

  # 8 — oracle_default invalid
  local vc8="${tmpdir}/vc-oracle-bad"
  mkdir -p "${vc8}/scripts" "${vc8}/.omo"
  cp "${vcbase}/scripts/validate-config.sh" "${vc8}/scripts/"
  printf '{"version":"1","categories":{"fast-search":{"model":"haiku"}},"ralph-loop":{"oracle_default":"yes"}}\n' \
    > "${vc8}/.omo/config.json"
  run_test_output "validate: oracle_default invalid -> error" \
    "cd '${vc8}' && bash scripts/validate-config.sh" \
    "ERROR"
  run_test_fail "validate: oracle_default invalid -> exit 1" \
    "cd '${vc8}' && bash scripts/validate-config.sh"

  # 9 — spawn max_concurrent_agents out of range (25)
  local vc9="${tmpdir}/vc-spawn-high"
  mkdir -p "${vc9}/scripts" "${vc9}/.omo"
  cp "${vcbase}/scripts/validate-config.sh" "${vc9}/scripts/"
  printf '{"version":"1","categories":{"fast-search":{"model":"haiku"}},"spawn":{"max_concurrent_agents":25}}\n' \
    > "${vc9}/.omo/config.json"
  run_test_output "validate: spawn out of range -> error" \
    "cd '${vc9}' && bash scripts/validate-config.sh" \
    "ERROR"
  run_test_fail "validate: spawn out of range -> exit 1" \
    "cd '${vc9}' && bash scripts/validate-config.sh"

  # 10 — spawn max_concurrent_agents zero
  local vc10="${tmpdir}/vc-spawn-zero"
  mkdir -p "${vc10}/scripts" "${vc10}/.omo"
  cp "${vcbase}/scripts/validate-config.sh" "${vc10}/scripts/"
  printf '{"version":"1","categories":{"fast-search":{"model":"haiku"}},"spawn":{"max_concurrent_agents":0}}\n' \
    > "${vc10}/.omo/config.json"
  run_test_output "validate: spawn zero -> error" \
    "cd '${vc10}' && bash scripts/validate-config.sh" \
    "ERROR"
  run_test_fail "validate: spawn zero -> exit 1" \
    "cd '${vc10}' && bash scripts/validate-config.sh"

  # 11 — boulder.enabled not boolean
  local vc11="${tmpdir}/vc-boulder-bad"
  mkdir -p "${vc11}/scripts" "${vc11}/.omo"
  cp "${vcbase}/scripts/validate-config.sh" "${vc11}/scripts/"
  printf '{"version":"1","categories":{"fast-search":{"model":"haiku"}},"boulder":{"enabled":"yes"}}\n' \
    > "${vc11}/.omo/config.json"
  run_test_output "validate: boulder.enabled invalid -> error" \
    "cd '${vc11}' && bash scripts/validate-config.sh" \
    "ERROR"
  run_test_fail "validate: boulder.enabled invalid -> exit 1" \
    "cd '${vc11}' && bash scripts/validate-config.sh"

  # 12 — teams.max_teammates out of range (0)
  local vc12="${tmpdir}/vc-teams-zero"
  mkdir -p "${vc12}/scripts" "${vc12}/.omo"
  cp "${vcbase}/scripts/validate-config.sh" "${vc12}/scripts/"
  printf '{"version":"1","categories":{"fast-search":{"model":"haiku"}},"teams":{"max_teammates":0}}\n' \
    > "${vc12}/.omo/config.json"
  run_test_output "validate: teams.max_teammates out of range -> error" \
    "cd '${vc12}' && bash scripts/validate-config.sh" \
    "ERROR"
  run_test_fail "validate: teams.max_teammates out of range -> exit 1" \
    "cd '${vc12}' && bash scripts/validate-config.sh"

  # 13 — disabled_skills not array
  local vc13="${tmpdir}/vc-ds-string"
  mkdir -p "${vc13}/scripts" "${vc13}/.omo"
  cp "${vcbase}/scripts/validate-config.sh" "${vc13}/scripts/"
  printf '{"version":"1","categories":{"fast-search":{"model":"haiku"}},"disabled_skills":"retro"}\n' \
    > "${vc13}/.omo/config.json"
  run_test_output "validate: disabled_skills not array -> error" \
    "cd '${vc13}' && bash scripts/validate-config.sh" \
    "ERROR"
  run_test_fail "validate: disabled_skills not array -> exit 1" \
    "cd '${vc13}' && bash scripts/validate-config.sh"

  # 14 — model hierarchy warning (deep-reasoning lower than planning)
  local vc14="${tmpdir}/vc-hierarchy-warn"
  mkdir -p "${vc14}/scripts" "${vc14}/.omo"
  cp "${vcbase}/scripts/validate-config.sh" "${vc14}/scripts/"
  printf '{"version":"1","categories":{"deep-reasoning":{"model":"haiku"},"planning":{"model":"opus"}}}\n' \
    > "${vc14}/.omo/config.json"
  run_test_output "validate: model hierarchy warning -> WARNING" \
    "cd '${vc14}' && bash scripts/validate-config.sh" \
    "WARNING"
  run_test "validate: model hierarchy warning -> exit 0" \
    "cd '${vc14}' && bash scripts/validate-config.sh"

  # 15 — valid full config with all fields
  local vc15="${tmpdir}/vc-full-valid"
  mkdir -p "${vc15}/scripts" "${vc15}/.omo"
  cp "${vcbase}/scripts/validate-config.sh" "${vc15}/scripts/"
  cat > "${vc15}/.omo/config.json" <<'VCEOF'
{
  "version": "1",
  "categories": {
    "fast-search":    {"model": "haiku"},
    "verification":   {"model": "sonnet"},
    "implementation": {"model": "sonnet"},
    "planning":       {"model": "sonnet"},
    "deep-reasoning": {"model": "opus"},
    "research":       {"model": "sonnet"},
    "media":          {"model": "sonnet"}
  },
  "ralph-loop": {
    "max_iterations": 50,
    "oracle_default": false
  },
  "spawn": {
    "max_concurrent_agents": 5
  },
  "boulder": {
    "enabled": true,
    "max_attempts": 3,
    "auto_resume": false
  },
  "teams": {
    "enabled": false,
    "max_teammates": 4,
    "auto_escalation": true,
    "notify_on_completion": true
  },
  "disabled_skills": []
}
VCEOF
  run_test "validate: valid full config -> pass" \
    "cd '${vc15}' && bash scripts/validate-config.sh"
  run_test_output "validate: valid full config -> PASS in output" \
    "cd '${vc15}' && bash scripts/validate-config.sh" \
    "PASS"

  cd "${tmpdir}"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
# SECTION 12: Boulder state machine
# ═════════════════════════════════════════════════════════════════
run_boulder_tests() {
  echo "Boulder state machine:"
  echo "──────────────────────"

  local bdir="${tmpdir}/boulder"
  mkdir -p "${bdir}/.claude/state"
  cd "${bdir}"

  echo ""
  echo "  [Init and lifecycle]"

  run_test "boulder-init: creates boulder.json" \
    "bash '${repo_root}/scripts/boulder-init.sh' 'test task' && [ -f .claude/state/boulder.json ]"

  run_test "boulder-init: valid JSON" \
    "python3 -c \"import json; json.load(open('.claude/state/boulder.json'))\""

  run_test "boulder-init: active is true" \
    "grep -q '\"active\"' .claude/state/boulder.json && grep -q 'true' .claude/state/boulder.json"

  run_test "boulder-init: goal stored" \
    "grep -q 'test task' .claude/state/boulder.json"

  run_test "boulder-init: attempts is 0" \
    "grep -q '\"attempts\"' .claude/state/boulder.json"

  run_test "boulder-init: slug generated" \
    "grep -q '\"task_slug\"' .claude/state/boulder.json"

  run_test_output "boulder-init: output shows slug" \
    "rm -f .claude/state/boulder.json && bash '${repo_root}/scripts/boulder-init.sh' 'my test'" \
    "Initialized"

  echo ""
  echo "  [Check]"

  run_test "boulder-check: active boulder → exit 0" \
    "bash '${repo_root}/scripts/boulder-check.sh'"

  run_test_output "boulder-check: shows task info" \
    "bash '${repo_root}/scripts/boulder-check.sh'" \
    "Active task"

  echo ""
  echo "  [Attempt recording]"

  run_test_output "boulder-attempt: working outcome" \
    "bash '${repo_root}/scripts/boulder-attempt.sh' working" \
    "Attempt"

  run_test "boulder-attempt: valid JSON after working" \
    "python3 -c \"import json; json.load(open('.claude/state/boulder.json'))\""

  run_test_output "boulder-attempt: interrupted outcome" \
    "bash '${repo_root}/scripts/boulder-attempt.sh' interrupted" \
    "Attempt"

  run_test_output "boulder-attempt: failed outcome" \
    "bash '${repo_root}/scripts/boulder-attempt.sh' failed 'test failure'" \
    "Attempt"

  run_test "boulder-attempt: valid JSON after failed" \
    "python3 -c \"import json; json.load(open('.claude/state/boulder.json'))\""

  run_test_output "boulder-attempt: second failure → warning" \
    "bash '${repo_root}/scripts/boulder-attempt.sh' failed 'another failure'" \
    "WARNING"

  run_test_output "boulder-attempt: working resets consecutive" \
    "bash '${repo_root}/scripts/boulder-attempt.sh' working" \
    "Attempt"

  run_test_fail "boulder-attempt: invalid outcome → error" \
    "bash '${repo_root}/scripts/boulder-attempt.sh' invalid_status"

  run_test_fail "boulder-attempt: no args → error" \
    "bash '${repo_root}/scripts/boulder-attempt.sh'"

  echo ""
  echo "  [Complete]"

  run_test_output "boulder-complete: marks complete" \
    "bash '${repo_root}/scripts/boulder-complete.sh'" \
    "Completed"

  run_test "boulder-complete: valid JSON" \
    "python3 -c \"import json; json.load(open('.claude/state/boulder.json'))\""

  run_test "boulder-complete: active is false" \
    "grep -q '\"active\":false' .claude/state/boulder.json || (command -v jq >/dev/null && [ \"\$(jq -r '.active' .claude/state/boulder.json)\" = 'false' ])"

  run_test_fail "boulder-check: completed boulder → exit 1" \
    "bash '${repo_root}/scripts/boulder-check.sh'"

  echo ""
  echo "  [Status]"

  run_test_output "boulder-status: shows status" \
    "bash '${repo_root}/scripts/boulder-status.sh'" \
    "Boulder Status"

  run_test_output "boulder-status: shows goal" \
    "bash '${repo_root}/scripts/boulder-status.sh'" \
    "Goal"

  echo ""
  echo "  [Edge cases]"

  rm -f .claude/state/boulder.json

  run_test_fail "boulder-check: no state → exit 1" \
    "bash '${repo_root}/scripts/boulder-check.sh'"

  run_test_fail "boulder-complete: no state → error" \
    "bash '${repo_root}/scripts/boulder-complete.sh'"

  run_test_fail "boulder-attempt: no state → error" \
    "bash '${repo_root}/scripts/boulder-attempt.sh' working"

  run_test "boulder-status: no state → no error" \
    "bash '${repo_root}/scripts/boulder-status.sh'"

  run_test_fail "boulder-init: no args → error" \
    "bash '${repo_root}/scripts/boulder-init.sh'"

  echo ""
  echo "  [Unicode goal]"

  run_test "boulder-init: unicode goal" \
    "bash '${repo_root}/scripts/boulder-init.sh' '사용자 인증 구현' && [ -f .claude/state/boulder.json ]"

  run_test "boulder-init: unicode valid JSON" \
    "python3 -c \"import json; json.load(open('.claude/state/boulder.json'))\""

  run_test_output "boulder-check: unicode task resumable" \
    "bash '${repo_root}/scripts/boulder-check.sh'" \
    "Active task"

  rm -f .claude/state/boulder.json

  echo ""
  echo "  [Max attempts]"

  run_test "boulder-init: custom max from config" \
    "mkdir -p .omo && echo '{\"boulder\":{\"max_attempts\":2}}' > .omo/config.json && bash '${repo_root}/scripts/boulder-init.sh' 'max test'"

  run_test "boulder-check: under max → exit 0" \
    "bash '${repo_root}/scripts/boulder-check.sh'"

  # Record attempts to reach max
  run_test "boulder-attempt: first attempt" \
    "bash '${repo_root}/scripts/boulder-attempt.sh' working"

  run_test "boulder-attempt: second attempt" \
    "bash '${repo_root}/scripts/boulder-attempt.sh' working"

  run_test_fail "boulder-check: at max → exit 1" \
    "bash '${repo_root}/scripts/boulder-check.sh'"

  rm -f .claude/state/boulder.json .omo/config.json
  rmdir .omo 2>/dev/null || true

  echo ""
  echo "  [Task file option]"

  run_test "boulder-init: --task-file option" \
    "bash '${repo_root}/scripts/boulder-init.sh' 'file test' --task-file=.claude/state/tasks/test.md && grep -q 'test.md' .claude/state/boulder.json"

  rm -f .claude/state/boulder.json

  cd "${tmpdir}"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
# SECTION 13: Hook scripts
# ═════════════════════════════════════════════════════════════════
run_hook_script_tests() {
  echo "Hook scripts:"
  echo "─────────────"

  local hdir="${tmpdir}/hooktest"
  mkdir -p "${hdir}/.claude/state"
  cd "${hdir}"

  echo ""
  echo "  [session-context-hook]"

  # No boulder → silent exit
  run_test "session-hook: no boulder → exit 0" \
    "echo '{}' | bash '${repo_root}/scripts/session-context-hook.sh'"

  # With active boulder
  bash "${repo_root}/scripts/boulder-init.sh" "hook test task" >/dev/null 2>&1

  run_test_output "session-hook: active boulder → context output" \
    "echo '{\"source\":\"resume\"}' | bash '${repo_root}/scripts/session-context-hook.sh'" \
    "omo"

  run_test_output "session-hook: output contains task slug" \
    "echo '{\"source\":\"startup\"}' | bash '${repo_root}/scripts/session-context-hook.sh'" \
    "hook-test-task"

  run_test "session-hook: output is valid JSON" \
    "echo '{\"source\":\"resume\"}' | bash '${repo_root}/scripts/session-context-hook.sh' | python3 -c 'import json,sys; json.load(sys.stdin)'"

  # Clear source → no output
  run_test "session-hook: clear source → no output" \
    "output=\$(echo '{\"source\":\"clear\"}' | bash '${repo_root}/scripts/session-context-hook.sh'); [ -z \"\${output}\" ]"

  echo ""
  echo "  [idle-resume-hook]"

  run_test_output "idle-hook: active boulder + idle_prompt → nudge" \
    "echo '{\"notification_type\":\"idle_prompt\"}' | bash '${repo_root}/scripts/idle-resume-hook.sh'" \
    "omo"

  run_test "idle-hook: output is valid JSON" \
    "echo '{\"notification_type\":\"idle_prompt\"}' | bash '${repo_root}/scripts/idle-resume-hook.sh' | python3 -c 'import json,sys; json.load(sys.stdin)'"

  # Non-idle notification → silent
  run_test "idle-hook: non-idle notification → no output" \
    "output=\$(echo '{\"notification_type\":\"other\"}' | bash '${repo_root}/scripts/idle-resume-hook.sh'); [ -z \"\${output}\" ]"

  # No boulder → silent
  rm -f .claude/state/boulder.json

  run_test "idle-hook: no boulder → no output" \
    "output=\$(echo '{\"notification_type\":\"idle_prompt\"}' | bash '${repo_root}/scripts/idle-resume-hook.sh'); [ -z \"\${output}\" ]"

  echo ""
  echo "  [hooks.json validation]"

  cd "${repo_root}"

  run_test "hooks.json: exists" \
    "[ -f hooks/hooks.json ]"

  run_test "hooks.json: valid JSON" \
    "python3 -c \"import json; json.load(open('hooks/hooks.json'))\""

  run_test "hooks.json: has Stop event" \
    "python3 -c \"import json; d=json.load(open('hooks/hooks.json')); assert 'Stop' in d['hooks']\""

  run_test "hooks.json: has SessionStart event" \
    "python3 -c \"import json; d=json.load(open('hooks/hooks.json')); assert 'SessionStart' in d['hooks']\""

  run_test "hooks.json: has Notification event" \
    "python3 -c \"import json; d=json.load(open('hooks/hooks.json')); assert 'Notification' in d['hooks']\""

  cd "${tmpdir}"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
# SECTION 14: Team hook scripts
# ═════════════════════════════════════════════════════════════════
run_team_hook_tests() {
  echo "Team hook scripts:"
  echo "──────────────────"

  local thdir="${tmpdir}/teamhooktest"
  mkdir -p "${thdir}/.claude/state"
  cd "${thdir}"

  echo ""
  echo "  [subagent-stop-hook]"

  # No boulder, no briefings → silent exit
  run_test "subagent-stop-hook: no boulder → exit 0" \
    "echo '{}' | bash '${repo_root}/scripts/subagent-stop-hook.sh'"

  # With boulder active
  CLAUDE_PROJECT_DIR="${thdir}" bash "${repo_root}/scripts/boulder-init.sh" "team hook test" >/dev/null 2>&1

  run_test "subagent-stop-hook: active boulder → exit 0" \
    "echo '{}' | CLAUDE_PROJECT_DIR='${thdir}' bash '${repo_root}/scripts/subagent-stop-hook.sh'"

  echo ""
  echo "  [teammate-idle-hook]"

  run_test "teammate-idle-hook: basic → outputs JSON" \
    "echo '{}' | bash '${repo_root}/scripts/teammate-idle-hook.sh' | python3 -c 'import json,sys; json.load(sys.stdin)'"

  run_test_output "teammate-idle-hook: output contains omo tag" \
    "echo '{\"teammate_name\":\"worker1\"}' | bash '${repo_root}/scripts/teammate-idle-hook.sh'" \
    "omo"

  # Teams disabled → silent
  mkdir -p "${thdir}/.omo"
  cat > "${thdir}/.omo/config.json" <<'CFGEOF'
{"version":"1","categories":{"fast-search":{"model":"sonnet"}},"teams":{"enabled":false}}
CFGEOF

  run_test "teammate-idle-hook: teams disabled → no output" \
    "output=\$(echo '{}' | CLAUDE_PROJECT_DIR='${thdir}' bash '${repo_root}/scripts/teammate-idle-hook.sh'); [ -z \"\${output}\" ]"

  rm -rf "${thdir}/.omo"

  echo ""
  echo "  [task-completed-hook]"

  run_test "task-completed-hook: basic → outputs JSON" \
    "echo '{}' | bash '${repo_root}/scripts/task-completed-hook.sh' | python3 -c 'import json,sys; json.load(sys.stdin)'"

  run_test_output "task-completed-hook: output contains omo tag" \
    "echo '{\"task_subject\":\"Fix bug\"}' | bash '${repo_root}/scripts/task-completed-hook.sh'" \
    "omo"

  echo ""
  echo "  [pre-compact-hook]"

  # No state → silent
  rm -f "${thdir}/.claude/state/boulder.json" "${thdir}/.claude/state/current-task.txt"

  run_test "pre-compact-hook: no state → exit 0 silent" \
    "output=\$(echo '{}' | CLAUDE_PROJECT_DIR='${thdir}' bash '${repo_root}/scripts/pre-compact-hook.sh'); [ -z \"\${output}\" ]"

  # With boulder
  CLAUDE_PROJECT_DIR="${thdir}" bash "${repo_root}/scripts/boulder-init.sh" "compact test" >/dev/null 2>&1

  run_test "pre-compact-hook: active boulder → outputs JSON" \
    "echo '{}' | CLAUDE_PROJECT_DIR='${thdir}' bash '${repo_root}/scripts/pre-compact-hook.sh' | python3 -c 'import json,sys; json.load(sys.stdin)'"

  run_test_output "pre-compact-hook: output contains systemMessage" \
    "echo '{}' | CLAUDE_PROJECT_DIR='${thdir}' bash '${repo_root}/scripts/pre-compact-hook.sh'" \
    "systemMessage"

  # With current-task.txt
  echo "/some/task.md" > "${thdir}/.claude/state/current-task.txt"

  run_test_output "pre-compact-hook: includes current task" \
    "echo '{}' | CLAUDE_PROJECT_DIR='${thdir}' bash '${repo_root}/scripts/pre-compact-hook.sh'" \
    "task"

  echo ""
  echo "  [hooks.json new events]"

  cd "${repo_root}"

  run_test "hooks.json: has SubagentStop event" \
    "python3 -c \"import json; d=json.load(open('hooks/hooks.json')); assert 'SubagentStop' in d['hooks']\""

  run_test "hooks.json: has TeammateIdle event" \
    "python3 -c \"import json; d=json.load(open('hooks/hooks.json')); assert 'TeammateIdle' in d['hooks']\""

  run_test "hooks.json: has TaskCompleted event" \
    "python3 -c \"import json; d=json.load(open('hooks/hooks.json')); assert 'TaskCompleted' in d['hooks']\""

  run_test "hooks.json: has PreCompact event" \
    "python3 -c \"import json; d=json.load(open('hooks/hooks.json')); assert 'PreCompact' in d['hooks']\""

  cd "${tmpdir}"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
# SECTION 15: Sprint 6 — Core quality fixes
# ═════════════════════════════════════════════════════════════════
run_sprint6_tests() {
  echo "Sprint 6 — Core quality fixes:"
  echo "───────────────────────────────"

  local s6dir="${tmpdir}/sprint6test"
  mkdir -p "${s6dir}/.claude/state" "${s6dir}/.omo"

  echo ""
  echo "  [boulder.enabled config gating]"

  # Config with boulder disabled
  cat > "${s6dir}/.omo/config.json" <<'S6EOF'
{"version":"1","categories":{"fast-search":{"model":"sonnet"}},"boulder":{"enabled":false,"max_attempts":5,"auto_resume":true}}
S6EOF

  run_test_output "boulder-init: disabled → skips" \
    "CLAUDE_PROJECT_DIR='${s6dir}' bash '${repo_root}/scripts/boulder-init.sh' 'disabled test'" \
    "Disabled via config"

  run_test_fail "boulder-check: disabled → exit 1" \
    "CLAUDE_PROJECT_DIR='${s6dir}' bash '${repo_root}/scripts/boulder-check.sh'"

  run_test_output "boulder-attempt: disabled → skips" \
    "CLAUDE_PROJECT_DIR='${s6dir}' bash '${repo_root}/scripts/boulder-attempt.sh' working" \
    "Disabled via config"

  run_test "boulder-complete: disabled → exit 0" \
    "CLAUDE_PROJECT_DIR='${s6dir}' bash '${repo_root}/scripts/boulder-complete.sh'"

  # Config with boulder enabled (default)
  cat > "${s6dir}/.omo/config.json" <<'S6EOF'
{"version":"1","categories":{"fast-search":{"model":"sonnet"}},"boulder":{"enabled":true,"max_attempts":5,"auto_resume":true}}
S6EOF

  run_test_output "boulder-init: enabled → initializes" \
    "CLAUDE_PROJECT_DIR='${s6dir}' bash '${repo_root}/scripts/boulder-init.sh' 'enabled test'" \
    "Initialized"

  run_test "boulder-check: enabled → exit 0" \
    "CLAUDE_PROJECT_DIR='${s6dir}' bash '${repo_root}/scripts/boulder-check.sh'"

  # Cleanup
  rm -f "${s6dir}/.claude/state/boulder.json"

  echo ""
  echo "  [subagent-stop-hook stdin parsing]"

  run_test_output "subagent-stop: parses agent_type from JSON" \
    "echo '{\"agent_type\":\"build-integrator\"}' | CLAUDE_PROJECT_DIR='${s6dir}' bash '${repo_root}/scripts/subagent-stop-hook.sh'; echo 'parsed ok'" \
    "parsed ok"

  run_test "subagent-stop: no boulder-attempt call (no boulder file)" \
    "echo '{\"agent_type\":\"test-commander\"}' | CLAUDE_PROJECT_DIR='${s6dir}' bash '${repo_root}/scripts/subagent-stop-hook.sh'"

  echo ""
  echo "  [escalation-check CLAUDE_PROJECT_DIR]"

  mkdir -p "${s6dir}/.claude/state/briefings"
  cat > "${s6dir}/.claude/state/briefings/test-brief.md" <<'BEOF'
- Confidence: HIGH
- Escalation: none
BEOF

  run_test_output "escalation-check: uses CLAUDE_PROJECT_DIR" \
    "CLAUDE_PROJECT_DIR='${s6dir}' bash '${repo_root}/scripts/escalation-check.sh'" \
    "No escalation needed"

  cat > "${s6dir}/.claude/state/briefings/low-brief.md" <<'BEOF'
- Confidence: LOW
- Escalation: recommended
BEOF

  run_test_fail "escalation-check: LOW confidence → exit 2" \
    "CLAUDE_PROJECT_DIR='${s6dir}' bash '${repo_root}/scripts/escalation-check.sh'"

  rm -rf "${s6dir}/.claude/state/briefings"

  echo ""
  echo "  [notify.sh sanitization]"

  run_test "notify: handles special chars safely" \
    "bash '${repo_root}/scripts/notify.sh' 'test\"title' 'msg\\with\"quotes'"

  echo ""
  echo "  [validate-schema 7 hook events]"

  cd "${repo_root}"

  run_test_output "validate-schema: checks all 7 events" \
    "bash scripts/validate-schema.sh 2>&1" \
    "All schemas valid"

  # Verify all 7 events are present in hooks.json
  for evt in Stop SessionStart Notification SubagentStop TeammateIdle TaskCompleted PreCompact; do
    run_test "hooks.json: contains ${evt}" \
      "python3 -c \"import json; d=json.load(open('hooks/hooks.json')); assert '${evt}' in d['hooks'], '${evt} missing'\""
  done

  cd "${tmpdir}"

  echo ""
  echo "  [ensure-hooks plugin detection]"

  # ensure-hooks should detect plugin hooks relative to script dir
  run_test_output "ensure-hooks: detects hooks/hooks.json" \
    "bash '${repo_root}/scripts/ensure-hooks.sh'" \
    "hooks"

  echo ""
  echo "  [CLAUDE.md consistency]"

  run_test "CLAUDE.md: oracle escalation says first failed attempt" \
    "grep -q 'first failed attempt' '${repo_root}/CLAUDE.md'"

  run_test_fail "CLAUDE.md: no 2+ failed attempts for oracle" \
    "grep -q 'use after 2+ failed attempts' '${repo_root}/CLAUDE.md'"

  run_test "CLAUDE.md: fast-search default is haiku" \
    "grep -q 'fast-search.*haiku' '${repo_root}/CLAUDE.md'"

  echo ""
  echo "  [fast-search default model]"

  run_test "init-config: fast-search default is haiku" \
    "grep -q '\"fast-search\".*\"haiku\"' '${repo_root}/scripts/init-config.sh'"

  run_test "docs/config.md: fast-search default is haiku" \
    "grep -q 'fast-search.*haiku' '${repo_root}/docs/config.md'"

  echo ""
  echo "  [team-status.sh]"

  local tsdir="${tmpdir}/team-status-test"

  # 1. No teams dir → expected message
  run_test_output "team-status: no teams dir → message" \
    "HOME='${tsdir}' bash '${repo_root}/scripts/team-status.sh'" \
    "No teams directory found."

  # 2. Empty teams dir → no active teams
  mkdir -p "${tsdir}/.claude/teams"
  run_test_output "team-status: empty teams dir → no active" \
    "HOME='${tsdir}' bash '${repo_root}/scripts/team-status.sh'" \
    "No active teams."

  # 3. Lists single team — output contains team name
  mkdir -p "${tsdir}/.claude/teams/test-team"
  cat > "${tsdir}/.claude/teams/test-team/config.json" <<'TSEOF'
{"members":[{"name":"worker1","agentId":"abc123","agentType":"build-integrator"}]}
TSEOF
  run_test_output "team-status: lists single team" \
    "HOME='${tsdir}' bash '${repo_root}/scripts/team-status.sh'" \
    "test-team"

  # 4. Specific team arg shows member details
  run_test_output "team-status: specific team shows details" \
    "HOME='${tsdir}' bash '${repo_root}/scripts/team-status.sh' test-team" \
    "worker1"

  # 5. Missing team → exit 1
  run_test_fail "team-status: missing team → exit 1" \
    "HOME='${tsdir}' bash '${repo_root}/scripts/team-status.sh' nonexistent-team"

  # 6. Multiple teams both appear in listing
  mkdir -p "${tsdir}/.claude/teams/alpha-team"
  cat > "${tsdir}/.claude/teams/alpha-team/config.json" <<'TSEOF'
{"members":[{"name":"worker2","agentId":"def456","agentType":"test-commander"}]}
TSEOF
  run_test_output "team-status: multiple teams listed (test-team)" \
    "HOME='${tsdir}' bash '${repo_root}/scripts/team-status.sh'" \
    "test-team"
  run_test_output "team-status: multiple teams listed (alpha-team)" \
    "HOME='${tsdir}' bash '${repo_root}/scripts/team-status.sh'" \
    "alpha-team"

  echo ""
  echo "  [check-skill-disabled]"

  local csdir="${tmpdir}/check-skill-test"
  mkdir -p "${csdir}/.omo"

  # No config → not disabled
  run_test "check-skill-disabled: no config → allowed" \
    "CLAUDE_PROJECT_DIR='${csdir}' bash '${repo_root}/scripts/check-skill-disabled.sh' retro"

  # Config with empty disabled_skills → allowed
  cat > "${csdir}/.omo/config.json" <<'CSEOF'
{"version":"1","categories":{"fast-search":{"model":"sonnet"}},"disabled_skills":[]}
CSEOF
  run_test "check-skill-disabled: empty array → allowed" \
    "CLAUDE_PROJECT_DIR='${csdir}' bash '${repo_root}/scripts/check-skill-disabled.sh' retro"

  # Config with skill in disabled_skills → disabled
  cat > "${csdir}/.omo/config.json" <<'CSEOF'
{"version":"1","categories":{"fast-search":{"model":"sonnet"}},"disabled_skills":["retro","dep-audit"]}
CSEOF
  run_test_fail "check-skill-disabled: listed skill → exit 1" \
    "CLAUDE_PROJECT_DIR='${csdir}' bash '${repo_root}/scripts/check-skill-disabled.sh' retro"

  # Non-listed skill → allowed
  run_test "check-skill-disabled: unlisted skill → allowed" \
    "CLAUDE_PROJECT_DIR='${csdir}' bash '${repo_root}/scripts/check-skill-disabled.sh' ultrawork"

  # No args → error
  run_test_fail "check-skill-disabled: no args → error" \
    "bash '${repo_root}/scripts/check-skill-disabled.sh'"

  echo ""
}

# ═════════════════════════════════════════════════════════════════
# SECTION 16: No-jq fallback paths
# ═════════════════════════════════════════════════════════════════
run_nojq_tests() {
  echo "No-jq fallback paths:"
  echo "─────────────────────"

  # Build a PATH with jq's directory removed so command -v jq fails.
  # This forces scripts onto their python3/grep fallback branches.
  # If jq is not installed the stripped PATH equals the original PATH,
  # and the fallback branches are already active — tests still pass.
  local ORIG_PATH="${PATH}"
  local jq_real
  jq_real=$(command -v jq 2>/dev/null || true)
  local NOJQ_PATH="${PATH}"
  if [ -n "${jq_real}" ]; then
    local jq_dir
    jq_dir=$(dirname "${jq_real}")
    NOJQ_PATH=$(printf '%s' "${PATH}" | tr ':' '\n' | grep -v "^${jq_dir}$" | tr '\n' ':' | sed 's/:$//')
  fi
  export PATH="${NOJQ_PATH}"

  local nojqdir="${tmpdir}/nojq"
  mkdir -p "${nojqdir}/.claude/state" "${nojqdir}/.omo"

  echo ""
  echo "  [read-config fallback]"

  # Write a minimal config so the python3 path is exercised
  cat > "${nojqdir}/.omo/config.json" <<'RCEOF'
{"version":"1","categories":{"fast-search":{"model":"haiku"}},"ralph-loop":{"max_iterations":42}}
RCEOF

  run_test_output "nojq: read-config fallback reads value" \
    "CLAUDE_PROJECT_DIR='${nojqdir}' PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/read-config.sh' categories.fast-search.model haiku" \
    "haiku"

  # No config file → default returned
  local nojqdir2="${tmpdir}/nojq-noconfig"
  mkdir -p "${nojqdir2}"
  run_test_output "nojq: read-config fallback default" \
    "CLAUDE_PROJECT_DIR='${nojqdir2}' PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/read-config.sh' categories.fast-search.model mydefault" \
    "mydefault"

  echo ""
  echo "  [boulder fallback lifecycle]"

  # boulder-init: the shell fallback writes the JSON file directly.
  # python3 validates the output is well-formed JSON.
  run_test "nojq: boulder-init fallback creates JSON" \
    "CLAUDE_PROJECT_DIR='${nojqdir}' PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/boulder-init.sh' 'nojq test task' && \
     [ -f '${nojqdir}/.claude/state/boulder.json' ]"

  run_test "nojq: boulder-init fallback valid JSON" \
    "python3 -c \"import json; json.load(open('${nojqdir}/.claude/state/boulder.json'))\""

  # The grep-based read helpers in boulder-attempt/check/complete expect
  # compact JSON (no space after colon).  Pre-seed a compact state file so
  # the attempt/check/complete fallback paths are exercised independently of
  # boulder-init's output format.
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  cat > "${nojqdir}/.claude/state/boulder.json" <<BEOF
{"active":true,"task_slug":"nojq-test","task_file":"","goal":"nojq test task","attempts":0,"max_attempts":5,"consecutive_failures":0,"last_outcome":"working","last_failure_reason":null,"auto_resume":true,"created_at":"${now}","updated_at":"${now}"}
BEOF

  run_test "nojq: boulder-attempt fallback updates state" \
    "CLAUDE_PROJECT_DIR='${nojqdir}' PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/boulder-attempt.sh' working && \
     python3 -c \"import json; d=json.load(open('${nojqdir}/.claude/state/boulder.json')); assert d['attempts'] == 1, d\""

  run_test "nojq: boulder-check fallback reads state" \
    "CLAUDE_PROJECT_DIR='${nojqdir}' PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/boulder-check.sh'"

  run_test_output "nojq: boulder-check fallback shows task info" \
    "CLAUDE_PROJECT_DIR='${nojqdir}' PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/boulder-check.sh'" \
    "Active task"

  run_test "nojq: boulder-complete fallback marks complete" \
    "CLAUDE_PROJECT_DIR='${nojqdir}' PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/boulder-complete.sh' && \
     python3 -c \"import json; d=json.load(open('${nojqdir}/.claude/state/boulder.json')); assert d['active'] == False, d\""

  echo ""
  echo "  [boulder pretty-printed JSON lifecycle]"

  # Test that boulder-attempt/check/complete work with the pretty-printed JSON
  # that boulder-init's heredoc fallback actually produces (spaces after colons).
  # This guards against the grep-pattern regression where "key":[value] missed "key": [value].
  local ppdir="${tmpdir}/nojq-pretty"
  mkdir -p "${ppdir}/.claude/state" "${ppdir}/.omo"

  run_test "nojq: boulder-init pretty JSON creates file" \
    "CLAUDE_PROJECT_DIR='${ppdir}' PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/boulder-init.sh' 'pretty json test'"

  run_test "nojq: boulder-attempt on pretty JSON" \
    "CLAUDE_PROJECT_DIR='${ppdir}' PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/boulder-attempt.sh' working && \
     python3 -c \"import json; d=json.load(open('${ppdir}/.claude/state/boulder.json')); assert d['attempts'] == 1, d\""

  run_test "nojq: boulder-check on pretty JSON" \
    "CLAUDE_PROJECT_DIR='${ppdir}' PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/boulder-check.sh'"

  run_test "nojq: boulder-complete on pretty JSON" \
    "CLAUDE_PROJECT_DIR='${ppdir}' PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/boulder-complete.sh' && \
     python3 -c \"import json; d=json.load(open('${ppdir}/.claude/state/boulder.json')); assert d['active'] == False, d\""

  echo ""
  echo "  [check-skill-disabled fallback]"

  local nojqdir3="${tmpdir}/nojq-skill"
  mkdir -p "${nojqdir3}/.omo"
  cat > "${nojqdir3}/.omo/config.json" <<'SKEOF'
{"version":"1","categories":{"fast-search":{"model":"sonnet"}},"disabled_skills":["retro","dep-audit"]}
SKEOF

  run_test_fail "nojq: check-skill-disabled fallback" \
    "CLAUDE_PROJECT_DIR='${nojqdir3}' PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/check-skill-disabled.sh' retro"

  export PATH="${ORIG_PATH}"

  echo ""
}

# ═════════════════════════════════════════════════════════════════
# SECTION 17: Evolve pipeline scripts
# ═════════════════════════════════════════════════════════════════
run_evolve_tests() {
  echo "Evolve pipeline:"
  echo "────────────────"

  echo ""
  echo "  [collect-metrics]"

  run_test "collect-metrics: runs successfully" \
    "cd '${repo_root}' && bash scripts/collect-metrics.sh >/dev/null"

  run_test_output "collect-metrics: outputs valid JSON" \
    "cd '${repo_root}' && bash scripts/collect-metrics.sh 2>/dev/null | python3 -c 'import json,sys; json.load(sys.stdin); print(\"valid\")'" \
    "valid"

  run_test_output "collect-metrics: has timestamp key" \
    "cd '${repo_root}' && bash scripts/collect-metrics.sh 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(\"ts:\"+d[\"timestamp\"])'" \
    "ts:"

  run_test_output "collect-metrics: has tests.count" \
    "cd '${repo_root}' && bash scripts/collect-metrics.sh 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(\"tc:\"+str(d[\"tests\"][\"count\"]))'" \
    "tc:"

  run_test_output "collect-metrics: has scripts.count" \
    "cd '${repo_root}' && bash scripts/collect-metrics.sh 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(\"sc:\"+str(d[\"scripts\"][\"count\"]))'" \
    "sc:"

  run_test_output "collect-metrics: has skills.count" \
    "cd '${repo_root}' && bash scripts/collect-metrics.sh 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(\"skc:\"+str(d[\"skills\"][\"count\"]))'" \
    "skc:"

  run_test_output "collect-metrics: has agents.count" \
    "cd '${repo_root}' && bash scripts/collect-metrics.sh 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(\"ac:\"+str(d[\"agents\"][\"count\"]))'" \
    "ac:"

  # Test with no memory directory
  local evdir="${tmpdir}/evolve-nomem"
  mkdir -p "${evdir}/scripts" "${evdir}/tests"
  cp "${repo_root}/scripts/collect-metrics.sh" "${evdir}/scripts/"
  chmod +x "${evdir}/scripts/collect-metrics.sh"
  echo '#!/usr/bin/env bash' > "${evdir}/tests/backtest.sh"

  run_test_output "collect-metrics: no memory → 0 values" \
    "cd '${evdir}' && bash scripts/collect-metrics.sh 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"memory\"][\"conventions\"]==0; print(\"mem:0\")'" \
    "mem:0"

  # Test stderr summary
  run_test_output "collect-metrics: stderr has summary" \
    "cd '${repo_root}' && bash scripts/collect-metrics.sh >/dev/null" \
    "Project Metrics:"

  echo ""
  echo "  [improvement-log]"

  local logdir="${tmpdir}/evolve-log"
  mkdir -p "${logdir}"

  run_test "improvement-log: creates log entry" \
    "CLAUDE_PROJECT_DIR='${logdir}' bash '${repo_root}/scripts/improvement-log.sh' 'test-slug' 'test summary'"

  run_test "improvement-log: history.log exists" \
    "[ -f '${logdir}/.claude/state/improvements/history.log' ]"

  run_test_output "improvement-log: log contains slug" \
    "cat '${logdir}/.claude/state/improvements/history.log'" \
    "test-slug"

  run_test_output "improvement-log: log contains summary" \
    "cat '${logdir}/.claude/state/improvements/history.log'" \
    "test summary"

  run_test_fail "improvement-log: no slug → error" \
    "bash '${repo_root}/scripts/improvement-log.sh'"

  echo ""
  echo "  [validate-config: evolve section]"

  local evconfdir="${tmpdir}/evolve-config"
  mkdir -p "${evconfdir}/scripts" "${evconfdir}/.omo"
  cp "${repo_root}/scripts/validate-config.sh" "${evconfdir}/scripts/"
  chmod +x "${evconfdir}/scripts/validate-config.sh"

  # Valid evolve config
  cat > "${evconfdir}/.omo/config.json" <<'EVEOF'
{"version":"1","categories":{"fast-search":{"model":"sonnet"}},"evolve":{"max_discovery_agents":6,"auto_plan":true,"include_memory":true}}
EVEOF

  run_test "validate-config: valid evolve config → PASS" \
    "cd '${evconfdir}' && bash scripts/validate-config.sh"

  # Invalid max_discovery_agents
  cat > "${evconfdir}/.omo/config.json" <<'EVEOF'
{"version":"1","categories":{"fast-search":{"model":"sonnet"}},"evolve":{"max_discovery_agents":99}}
EVEOF

  run_test_fail "validate-config: evolve agents=99 → FAIL" \
    "cd '${evconfdir}' && bash scripts/validate-config.sh"

  # Invalid auto_plan
  cat > "${evconfdir}/.omo/config.json" <<'EVEOF'
{"version":"1","categories":{"fast-search":{"model":"sonnet"}},"evolve":{"auto_plan":"maybe"}}
EVEOF

  run_test_fail "validate-config: evolve auto_plan=maybe → FAIL" \
    "cd '${evconfdir}' && bash scripts/validate-config.sh"

  # Invalid include_memory
  cat > "${evconfdir}/.omo/config.json" <<'EVEOF'
{"version":"1","categories":{"fast-search":{"model":"sonnet"}},"evolve":{"include_memory":"yes"}}
EVEOF

  run_test_fail "validate-config: evolve include_memory=yes → FAIL" \
    "cd '${evconfdir}' && bash scripts/validate-config.sh"

  echo ""
}

# ═════════════════════════════════════════════════════════════════
# SECTION 18: Hook script JSON output validation
# ═════════════════════════════════════════════════════════════════
run_hook_json_tests() {
  echo "Hook script JSON output:"
  echo "────────────────────────"

  local hjdir="${tmpdir}/hookjson"
  mkdir -p "${hjdir}/.claude/state/briefings"

  # ── teammate-idle-hook (always produces JSON) ────────────────────
  echo ""
  echo "  [teammate-idle-hook: JSON output]"

  run_test "teammate-idle-hook: jq path → valid JSON" \
    "echo '{}' | bash '${repo_root}/scripts/teammate-idle-hook.sh' | python3 -c 'import json,sys; json.load(sys.stdin)'"

  run_test "teammate-idle-hook: has hookSpecificOutput key" \
    "echo '{}' | bash '${repo_root}/scripts/teammate-idle-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"hookSpecificOutput\" in d'"

  run_test "teammate-idle-hook: hookEventName is TeammateIdle" \
    "echo '{}' | bash '${repo_root}/scripts/teammate-idle-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"hookSpecificOutput\"][\"hookEventName\"]==\"TeammateIdle\"'"

  run_test "teammate-idle-hook: has additionalContext key" \
    "echo '{}' | bash '${repo_root}/scripts/teammate-idle-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"additionalContext\" in d[\"hookSpecificOutput\"]'"

  # ── task-completed-hook (always produces JSON) ───────────────────
  echo ""
  echo "  [task-completed-hook: JSON output]"

  run_test "task-completed-hook: jq path → valid JSON" \
    "echo '{}' | bash '${repo_root}/scripts/task-completed-hook.sh' | python3 -c 'import json,sys; json.load(sys.stdin)'"

  run_test "task-completed-hook: has hookSpecificOutput key" \
    "echo '{}' | bash '${repo_root}/scripts/task-completed-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"hookSpecificOutput\" in d'"

  run_test "task-completed-hook: hookEventName is TaskCompleted" \
    "echo '{}' | bash '${repo_root}/scripts/task-completed-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"hookSpecificOutput\"][\"hookEventName\"]==\"TaskCompleted\"'"

  run_test "task-completed-hook: has additionalContext key" \
    "echo '{}' | bash '${repo_root}/scripts/task-completed-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"additionalContext\" in d[\"hookSpecificOutput\"]'"

  # ── session-context-hook (produces JSON when boulder is active) ──
  echo ""
  echo "  [session-context-hook: JSON output with active boulder]"

  CLAUDE_PROJECT_DIR="${hjdir}" bash "${repo_root}/scripts/boulder-init.sh" "hookjson test task" >/dev/null 2>&1

  run_test "session-context-hook: active boulder → valid JSON" \
    "echo '{\"source\":\"resume\"}' | CLAUDE_PROJECT_DIR='${hjdir}' bash '${repo_root}/scripts/session-context-hook.sh' | python3 -c 'import json,sys; json.load(sys.stdin)'"

  run_test "session-context-hook: has hookSpecificOutput key" \
    "echo '{\"source\":\"resume\"}' | CLAUDE_PROJECT_DIR='${hjdir}' bash '${repo_root}/scripts/session-context-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"hookSpecificOutput\" in d'"

  run_test "session-context-hook: hookEventName is SessionStart" \
    "echo '{\"source\":\"startup\"}' | CLAUDE_PROJECT_DIR='${hjdir}' bash '${repo_root}/scripts/session-context-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"hookSpecificOutput\"][\"hookEventName\"]==\"SessionStart\"'"

  run_test "session-context-hook: has additionalContext key" \
    "echo '{\"source\":\"resume\"}' | CLAUDE_PROJECT_DIR='${hjdir}' bash '${repo_root}/scripts/session-context-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"additionalContext\" in d[\"hookSpecificOutput\"]'"

  # ── idle-resume-hook (produces JSON when boulder active + idle_prompt) ──
  echo ""
  echo "  [idle-resume-hook: JSON output with active boulder]"

  run_test "idle-resume-hook: idle_prompt + boulder → valid JSON" \
    "echo '{\"notification_type\":\"idle_prompt\"}' | CLAUDE_PROJECT_DIR='${hjdir}' bash '${repo_root}/scripts/idle-resume-hook.sh' | python3 -c 'import json,sys; json.load(sys.stdin)'"

  run_test "idle-resume-hook: has hookSpecificOutput key" \
    "echo '{\"notification_type\":\"idle_prompt\"}' | CLAUDE_PROJECT_DIR='${hjdir}' bash '${repo_root}/scripts/idle-resume-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"hookSpecificOutput\" in d'"

  run_test "idle-resume-hook: hookEventName is Notification" \
    "echo '{\"notification_type\":\"idle_prompt\"}' | CLAUDE_PROJECT_DIR='${hjdir}' bash '${repo_root}/scripts/idle-resume-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"hookSpecificOutput\"][\"hookEventName\"]==\"Notification\"'"

  run_test "idle-resume-hook: has additionalContext key" \
    "echo '{\"notification_type\":\"idle_prompt\"}' | CLAUDE_PROJECT_DIR='${hjdir}' bash '${repo_root}/scripts/idle-resume-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"additionalContext\" in d[\"hookSpecificOutput\"]'"

  # ── pre-compact-hook (produces JSON when boulder active) ─────────
  echo ""
  echo "  [pre-compact-hook: JSON output with active boulder]"

  run_test "pre-compact-hook: active boulder → valid JSON" \
    "echo '{}' | CLAUDE_PROJECT_DIR='${hjdir}' bash '${repo_root}/scripts/pre-compact-hook.sh' | python3 -c 'import json,sys; json.load(sys.stdin)'"

  run_test "pre-compact-hook: has hookSpecificOutput key" \
    "echo '{}' | CLAUDE_PROJECT_DIR='${hjdir}' bash '${repo_root}/scripts/pre-compact-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"hookSpecificOutput\" in d'"

  run_test "pre-compact-hook: hookEventName is PreCompact" \
    "echo '{}' | CLAUDE_PROJECT_DIR='${hjdir}' bash '${repo_root}/scripts/pre-compact-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"hookSpecificOutput\"][\"hookEventName\"]==\"PreCompact\"'"

  run_test "pre-compact-hook: has systemMessage key" \
    "echo '{}' | CLAUDE_PROJECT_DIR='${hjdir}' bash '${repo_root}/scripts/pre-compact-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"systemMessage\" in d[\"hookSpecificOutput\"]'"

  # ── subagent-stop-hook (produces JSON only when escalation triggered) ──
  echo ""
  echo "  [subagent-stop-hook: JSON output when escalation recommended]"

  # Seed a briefing that signals LOW confidence so escalation-check exits 2
  cat > "${hjdir}/.claude/state/briefings/test-agent-briefing.md" <<'BEOF'
# Agent Briefing

- Confidence: LOW
- Escalation: recommended
BEOF

  run_test "subagent-stop-hook: escalation recommended → valid JSON" \
    "echo '{}' | CLAUDE_PROJECT_DIR='${hjdir}' bash '${repo_root}/scripts/subagent-stop-hook.sh' | python3 -c 'import json,sys; json.load(sys.stdin)'"

  run_test "subagent-stop-hook: has hookSpecificOutput key" \
    "echo '{}' | CLAUDE_PROJECT_DIR='${hjdir}' bash '${repo_root}/scripts/subagent-stop-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"hookSpecificOutput\" in d'"

  run_test "subagent-stop-hook: hookEventName is SubagentStop" \
    "echo '{}' | CLAUDE_PROJECT_DIR='${hjdir}' bash '${repo_root}/scripts/subagent-stop-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"hookSpecificOutput\"][\"hookEventName\"]==\"SubagentStop\"'"

  run_test "subagent-stop-hook: has additionalContext key" \
    "echo '{}' | CLAUDE_PROJECT_DIR='${hjdir}' bash '${repo_root}/scripts/subagent-stop-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"additionalContext\" in d[\"hookSpecificOutput\"]'"

  # ── No-jq fallback paths for unconditional JSON hooks ────────────
  echo ""
  echo "  [no-jq fallback: JSON structure]"

  local ORIG_PATH="${PATH}"
  local jq_real
  jq_real=$(command -v jq 2>/dev/null || true)
  local NOJQ_PATH="${PATH}"
  if [ -n "${jq_real}" ]; then
    local jq_dir
    jq_dir=$(dirname "${jq_real}")
    NOJQ_PATH=$(printf '%s' "${PATH}" | tr ':' '\n' | grep -v "^${jq_dir}$" | tr '\n' ':' | sed 's/:$//')
  fi

  run_test "nojq: teammate-idle-hook fallback → valid JSON" \
    "echo '{}' | PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/teammate-idle-hook.sh' | python3 -c 'import json,sys; json.load(sys.stdin)'"

  run_test "nojq: teammate-idle-hook fallback → has hookSpecificOutput" \
    "echo '{}' | PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/teammate-idle-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"hookSpecificOutput\" in d'"

  run_test "nojq: task-completed-hook fallback → valid JSON" \
    "echo '{}' | PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/task-completed-hook.sh' | python3 -c 'import json,sys; json.load(sys.stdin)'"

  run_test "nojq: task-completed-hook fallback → has hookSpecificOutput" \
    "echo '{}' | PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/task-completed-hook.sh' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"hookSpecificOutput\" in d'"

  run_test "nojq: session-context-hook fallback → valid JSON" \
    "echo '{\"source\":\"resume\"}' | CLAUDE_PROJECT_DIR='${hjdir}' PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/session-context-hook.sh' | python3 -c 'import json,sys; json.load(sys.stdin)'"

  run_test "nojq: idle-resume-hook fallback → valid JSON" \
    "echo '{\"notification_type\":\"idle_prompt\"}' | CLAUDE_PROJECT_DIR='${hjdir}' PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/idle-resume-hook.sh' | python3 -c 'import json,sys; json.load(sys.stdin)'"

  run_test "nojq: pre-compact-hook fallback → valid JSON" \
    "echo '{}' | CLAUDE_PROJECT_DIR='${hjdir}' PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/pre-compact-hook.sh' | python3 -c 'import json,sys; json.load(sys.stdin)'"

  run_test "nojq: subagent-stop-hook fallback → valid JSON" \
    "echo '{}' | CLAUDE_PROJECT_DIR='${hjdir}' PATH='${NOJQ_PATH}' bash '${repo_root}/scripts/subagent-stop-hook.sh' | python3 -c 'import json,sys; json.load(sys.stdin)'"

  export PATH="${ORIG_PATH}"

  echo ""
}

# ═════════════════════════════════════════════════════════════════
# SECTION 19: Security hardening and integration
# ═════════════════════════════════════════════════════════════════
run_security_tests() {
  echo "Security hardening and integration:"
  echo "────────────────────────────────────"

  local sdir="${tmpdir}/security"
  mkdir -p "${sdir}/.claude/state/briefings"

  echo ""
  echo "  [write-briefing sed injection defense]"

  cd "${sdir}"

  # Agent name with sed metacharacters: / & \
  run_test "briefing: agent with slash in name" \
    "bash '${repo_root}/scripts/write-briefing.sh' 'agent/sub' 'task-a' 'test' | grep -q '.md'"

  run_test "briefing: slash agent - file contains agent name" \
    "grep -q 'agent/sub' .claude/state/briefings/task-a-*.md"

  run_test "briefing: slug with ampersand" \
    "bash '${repo_root}/scripts/write-briefing.sh' 'builder' 'fix&deploy' 'test' | grep -q '.md'"

  run_test "briefing: slug with backslash" \
    "bash '${repo_root}/scripts/write-briefing.sh' 'builder' 'path\\\\dir' 'test' | grep -q '.md'"

  echo ""
  echo "  [apply-config category validation]"

  local cdir="${tmpdir}/config-sec"
  mkdir -p "${cdir}/.omo" "${cdir}/agents" "${cdir}/scripts"

  # Copy the script so repo_root resolves to cdir
  cp "${repo_root}/scripts/apply-config.sh" "${cdir}/scripts/"

  # Create a config with valid + injected categories
  cat > "${cdir}/.omo/config.json" <<'CEOF'
{
  "version": "1",
  "categories": {
    "fast-search": { "model": "haiku" },
    "evil-injection": { "model": "opus" }
  }
}
CEOF

  # Create a mock agent with an invalid category
  cat > "${cdir}/agents/evil.md" <<'AEOF'
---
name: evil
description: test agent
model: sonnet
category: evil-injection
tools: Read
---
test
AEOF

  # Create a mock agent with a valid category
  cat > "${cdir}/agents/good.md" <<'AEOF'
---
name: good
description: test agent
model: sonnet
category: fast-search
tools: Read
---
test
AEOF

  cd "${cdir}"
  run_test_output "apply-config: rejects invalid category" \
    "bash '${cdir}/scripts/apply-config.sh' --dry-run 2>&1" \
    "SKIP"

  run_test_output "apply-config: accepts valid category" \
    "bash '${cdir}/scripts/apply-config.sh' --dry-run 2>&1" \
    "haiku"

  echo ""
  echo "  [json_escape shared function]"

  cd "${tmpdir}"

  # Source json-helpers and test json_escape
  run_test "json_escape: basic string" \
    "source '${repo_root}/scripts/json-helpers.sh' && result=\$(json_escape 'hello world') && [ \"\${result}\" = 'hello world' ]"

  run_test "json_escape: escapes double quotes" \
    "source '${repo_root}/scripts/json-helpers.sh' && result=\$(json_escape 'say \"hi\"') && echo \"\${result}\" | grep -q '\\\\\"'"

  run_test "json_escape: escapes backslash" \
    "source '${repo_root}/scripts/json-helpers.sh' && result=\$(json_escape 'path\\\\dir') && echo \"\${result}\" | grep -q '\\\\\\\\'"

  run_test "json_escape: strips newlines" \
    "source '${repo_root}/scripts/json-helpers.sh' && result=\$(json_escape \$'line1\nline2') && [ \"\$(printf '%s' \"\${result}\" | wc -l)\" -eq 0 ]"

  # Test that ralph-loop-start.sh still works after json_escape extraction
  local rdir="${tmpdir}/ralph-sec"
  mkdir -p "${rdir}/.claude/state"
  cd "${rdir}"

  run_test "ralph-loop: works with sourced json_escape" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'test task' && [ -f .claude/state/ralph-loop.json ]"

  run_test "ralph-loop: prompt with quotes in no-jq fallback" \
    "PATH='/usr/bin:/bin' bash '${repo_root}/scripts/ralph-loop-start.sh' 'say hi' && grep -q 'say hi' .claude/state/ralph-loop.json"

  echo ""
  echo "  [CLI integration]"

  cd "${repo_root}"

  run_test "plugin: plugin.json is valid JSON" \
    "cat .claude-plugin/plugin.json | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null || jq '.' .claude-plugin/plugin.json >/dev/null"

  run_test "plugin: marketplace.json is valid JSON" \
    "cat .claude-plugin/marketplace.json | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null || jq '.' .claude-plugin/marketplace.json >/dev/null"

  run_test "plugin: all scripts are executable" \
    "non_exec=\$(find scripts/ -name '*.sh' ! -perm -u+x 2>/dev/null); [ -z \"\${non_exec}\" ]"

  run_test "plugin: json-helpers.sh has all 4 functions" \
    "grep -q 'json_str' scripts/json-helpers.sh && grep -q 'json_raw' scripts/json-helpers.sh && grep -q 'json_escape' scripts/json-helpers.sh && grep -q 'json_num' scripts/json-helpers.sh"

  echo ""
  echo "  [json_num function]"

  # Create a test JSON file for json_num
  cat > "${tmpdir}/test-num.json" <<'NJSON'
{
  "attempts": 3,
  "max_attempts": 5,
  "name": "test",
  "active": true
}
NJSON

  run_test "json_num: reads numeric field" \
    "source '${repo_root}/scripts/json-helpers.sh' && [ \"\$(json_num attempts '${tmpdir}/test-num.json')\" = '3' ]"

  run_test "json_num: returns 0 for missing field" \
    "source '${repo_root}/scripts/json-helpers.sh' && [ \"\$(json_num nonexistent '${tmpdir}/test-num.json')\" = '0' ]"

  run_test "json_num: returns 0 for string field" \
    "source '${repo_root}/scripts/json-helpers.sh' && result=\$(json_num name '${tmpdir}/test-num.json') && [ \"\${result}\" = '0' ] || [ \"\${result}\" = 'test' ]"

  echo ""
  echo "  [json_raw improved fallback]"

  run_test "json_raw: reads boolean" \
    "source '${repo_root}/scripts/json-helpers.sh' && [ \"\$(json_raw active '${tmpdir}/test-num.json')\" = 'true' ]"

  run_test "json_raw: reads number" \
    "source '${repo_root}/scripts/json-helpers.sh' && [ \"\$(json_raw attempts '${tmpdir}/test-num.json')\" = '3' ]"

  echo ""
  echo "  [hook scripts source json-helpers]"

  run_test "hook: pre-compact sources json-helpers" \
    "grep -q 'source.*json-helpers' '${repo_root}/scripts/pre-compact-hook.sh'"

  run_test "hook: subagent-stop sources json-helpers" \
    "grep -q 'source.*json-helpers' '${repo_root}/scripts/subagent-stop-hook.sh'"

  run_test "hook: task-completed sources json-helpers" \
    "grep -q 'source.*json-helpers' '${repo_root}/scripts/task-completed-hook.sh'"

  run_test "hook: teammate-idle sources json-helpers" \
    "grep -q 'source.*json-helpers' '${repo_root}/scripts/teammate-idle-hook.sh'"

  run_test "hook: no inline sed escape in hooks" \
    "! grep -l 'sed.*s/\\\\\\\\/.*s/\"/.*\\\\\\\\\"' '${repo_root}/scripts/'*-hook.sh 2>/dev/null | grep -qv ralph"

  cd "${tmpdir}"
  echo ""
}

# ═════════════════════════════════════════════════════════════════
# Run requested sections
# ═════════════════════════════════════════════════════════════════
case "${section}" in
  ralph)       run_ralph_tests ;;
  briefing)    run_briefing_tests ;;
  hooks)       run_hooks_tests ;;
  tasks)       run_tasks_tests ;;
  version)     run_version_tests ;;
  schema)      run_schema_tests ;;
  marketplace) run_marketplace_tests ;;
  misc)        run_misc_tests ;;
  quality)     run_skill_quality_tests ;;
  templates)   run_template_tests ;;
  config)      run_config_tests ;;
  boulder)     run_boulder_tests ;;
  hookscripts) run_hook_script_tests ;;
  teamhooks)   run_team_hook_tests ;;
  sprint6)     run_sprint6_tests ;;
  nojq)        run_nojq_tests ;;
  evolve)      run_evolve_tests ;;
  hookjson)    run_hook_json_tests ;;
  security)    run_security_tests ;;
  all)
    run_ralph_tests
    run_briefing_tests
    run_hooks_tests
    run_tasks_tests
    run_version_tests
    run_schema_tests
    run_marketplace_tests
    run_misc_tests
    run_skill_quality_tests
    run_template_tests
    run_config_tests
    run_boulder_tests
    run_hook_script_tests
    run_team_hook_tests
    run_sprint6_tests
    run_nojq_tests
    run_evolve_tests
    run_hook_json_tests
    run_security_tests
    ;;
  *)
    echo "Unknown section: ${section}"
    echo "Available: ralph, briefing, hooks, tasks, version, schema, marketplace, misc, quality, templates, config, boulder, hookscripts, teamhooks, sprint6, nojq, evolve, hookjson, security, all"
    exit 1
    ;;
esac

# ═════════════════════════════════════════════════════════════════
# Summary
# ═════════════════════════════════════════════════════════════════
echo "===================="
echo "Total: ${total} | Pass: ${pass} | Fail: ${fail}"

if [ -n "${failures}" ]; then
  echo ""
  echo "Failures:"
  printf "${failures}\n"
fi

if [ "${fail}" -gt 0 ]; then
  echo ""
  echo "RESULT: FAIL"
  exit 1
else
  echo ""
  echo "RESULT: PASS"
  exit 0
fi
