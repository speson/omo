---
name: verify-all
description: "Composite verification — run ship-check and diff-review in parallel for maximum coverage. Activate when #va appears anywhere in the user message."
argument-hint: "[scope-or-empty]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Task
---

Run comprehensive verification for: $ARGUMENTS

This is a composite skill that runs ship-check and diff-review simultaneously for thorough multi-perspective verification.

Step 1 — Check disabled:

Run `bash scripts/check-skill-disabled.sh verify-all`. If disabled, inform the user and stop.

Step 2 — Dispatch both verifications in parallel:

Launch simultaneously:

1. **ship-check** — dispatch as a Task agent:
   - `test-commander` for narrowest verification set
   - `security-auditor` for OWASP checks
   - `deepsearch` to trace usage of changed functions
   - Run recommended verification commands

2. **diff-review** — dispatch as a Task agent:
   - 5-perspective review: correctness, security, performance, maintainability, scope
   - `security-auditor` for deep security analysis
   - `deepsearch` for cross-codebase impact
   - `test-commander` for test coverage gaps

Step 3 — Synthesize results:

Merge findings from both verifications. Deduplicate issues found by both. Categorize:
- **BLOCKING** — must fix before merge/ship
- **WARNING** — should fix
- **NOTE** — consider for future

Step 4 — Summary:

End with a unified report:
- Verification commands run
- Verification commands NOT run (and why)
- Security findings
- Performance findings
- Blocking issues
- Warnings
- Missing tests
- Ship readiness: READY / NOT READY / CONDITIONAL
