---
name: ship-check
description: "Review the current diff, run the narrowest useful verification, and summarize remaining release risk. Activate when #sc appears anywhere in the user message."
argument-hint: "[scope-or-empty]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Task
---

Perform a final check for: $ARGUMENTS

1. Inspect the current diff or the scope the user provided.
2. Ask `test-commander` for the smallest verification set that still proves confidence.
3. Run those commands if possible.
4. Review the diff for:
   - accidental scope expansion
   - placeholder text
   - stale comments or docs
   - missing tests or verification
5. Recommend `comment-check` or `docs-keeper` if the diff is prose-heavy.
6. Summarize:
   - verification run
   - not run
   - top risks
   - ship readiness
