---
name: ship-check
description: "Review the current diff, run the narrowest useful verification, and summarize remaining release risk. Activate when #sc appears anywhere in the user message."
argument-hint: "[scope-or-empty]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Task
---

Perform a final check for: $ARGUMENTS

1. Inspect the current diff or the scope the user provided.
2. Dispatch in parallel:
   - `test-commander` for the narrowest verification set that still proves confidence.
   - `security-auditor` for OWASP checks on changed code.
   - `deepsearch` to trace usage of changed functions/APIs elsewhere.
3. Run the verification commands recommended by test-commander.
4. Review the diff for:
   - accidental scope expansion
   - placeholder text
   - stale comments or docs
   - missing tests or verification
5. Recommend `docs-keeper` if the diff is prose-heavy.
6. Summarize:
   - verification run
   - not run
   - security findings
   - top risks
   - ship readiness
