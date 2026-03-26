#!/usr/bin/env bash
# omo comprehensive backtest suite
# Tests all scripts with diverse input variations and edge cases
# Usage: ./tests/backtest.sh [section]
# Sections: ralph, briefing, hooks, tasks, version, schema, marketplace, misc, all
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

  run_test "start with --promise=SHIP_IT" \
    "bash '${repo_root}/scripts/ralph-loop-start.sh' 'promise test' --promise=SHIP_IT && grep -q 'SHIP_IT' .claude/state/ralph-loop.json"
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
  echo "  [Fresh install - no settings file]"

  local hdir="${tmpdir}/hooks-fresh"
  mkdir -p "${hdir}"
  cd "${hdir}"

  run_test "hooks: creates settings from scratch" \
    "bash '${repo_root}/scripts/ensure-hooks.sh' && [ -f .claude/settings.local.json ]"

  run_test "hooks: settings contains ralph-loop-guard" \
    "grep -q 'ralph-loop-guard' .claude/settings.local.json"

  run_test "hooks: settings is valid JSON" \
    "python3 -c \"import json; json.load(open('.claude/settings.local.json'))\""

  echo ""
  echo "  [Idempotent - already registered]"

  run_test "hooks: second run is no-op (idempotent)" \
    "bash '${repo_root}/scripts/ensure-hooks.sh'"

  run_test_output "hooks: second run says already registered" \
    "bash '${repo_root}/scripts/ensure-hooks.sh'" \
    "already registered"

  echo ""
  echo "  [Existing settings without hooks]"

  local hdir2="${tmpdir}/hooks-existing"
  mkdir -p "${hdir2}/.claude"
  cd "${hdir2}"

  echo '{"permissions":{"allow":["Read","Write"]}}' > .claude/settings.local.json

  if command -v jq >/dev/null 2>&1; then
    run_test "hooks: merges into existing settings (jq)" \
      "bash '${repo_root}/scripts/ensure-hooks.sh' && grep -q 'ralph-loop-guard' .claude/settings.local.json"

    run_test "hooks: preserves existing fields" \
      "grep -q 'permissions' .claude/settings.local.json"

    run_test "hooks: merged result is valid JSON" \
      "python3 -c \"import json; json.load(open('.claude/settings.local.json'))\""
  else
    run_test_output "hooks: warns about manual merge without jq" \
      "bash '${repo_root}/scripts/ensure-hooks.sh' || true" \
      "Cannot auto-merge"
  fi

  echo ""
  echo "  [Existing settings with hooks section]"

  local hdir3="${tmpdir}/hooks-has-hooks"
  mkdir -p "${hdir3}/.claude"
  cd "${hdir3}"

  echo '{"hooks":{"PreToolUse":[{"matcher":"","hooks":["echo test"]}]}}' > .claude/settings.local.json

  run_test_fail "hooks: existing hooks section without guard → exit 1" \
    "bash '${repo_root}/scripts/ensure-hooks.sh'"

  run_test_output "hooks: tells user to add manually" \
    "bash '${repo_root}/scripts/ensure-hooks.sh' 2>&1 || true" \
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
    ;;
  *)
    echo "Unknown section: ${section}"
    echo "Available: ralph, briefing, hooks, tasks, version, schema, marketplace, misc, quality, templates, all"
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
