---
name: diff-review
description: "Multi-perspective code review on the current diff or specified files. Examines correctness, security, performance, maintainability, and scope creep. Activate when #dr appears anywhere in the user message."
argument-hint: "[scope-or-empty]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Task
---

Review the current changes: $ARGUMENTS

Perform a multi-perspective code review on the current diff.

Step 1 — Gather the diff:

- If git is available, run `git diff` and `git diff --cached` to see all changes.
- If scope is specified, limit review to those files.
- If no git, review recently modified files.

Step 2 — Review from 5 perspectives (ALWAYS run in parallel — dispatch as simultaneous agents):

1. **Correctness** — Does the code do what it claims? Logic errors, off-by-ones, null handling, edge cases, race conditions.
2. **Security** — OWASP top 10 risks: injection, XSS, auth bypass, secrets in code, unsafe deserialization, missing input validation.
3. **Performance** — N+1 queries, unnecessary re-renders, missing indexes, unbounded loops, memory leaks, large payload risks.
4. **Maintainability** — Naming clarity, dead code, stale comments, code duplication, overly complex logic, missing error handling.
5. **Scope** — Does the diff contain accidental scope expansion, unrelated changes, debug leftovers, placeholder text, or TODO items?

Dispatch specialists in parallel for deeper analysis:

- `security-auditor` for perspective 2 (always, not just for security-heavy diffs).
- `deepsearch` to trace how changed code is used elsewhere.
- `test-commander` to identify what tests should cover the changes.
- `oracle` for complex architectural concerns.

Do not do shallow inline analysis when a specialist can go deeper. The goal is thoroughness, not token savings.

Step 3 — Compile findings:

- Categorize each issue as BLOCKING (must fix before merge), WARNING (should fix), or NOTE (consider for future).
- Provide specific file paths and line numbers for each issue.
- Suggest concrete fixes, not vague recommendations.

End with:

- `Summary` (1-2 sentences overall assessment)
- `Blocking issues` (must fix)
- `Warnings` (should fix)
- `Notes` (optional improvements)
- `Missing tests` (what the diff should have tested)
