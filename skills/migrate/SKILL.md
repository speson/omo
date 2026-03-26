---
name: migrate
description: "Orchestrate framework, API, or language version migration — analyze impact, plan changes, execute in slices, verify each step. Activate when #mg appears anywhere in the user message."
argument-hint: "<target>"
disable-model-invocation: false
allowed-tools: Read, Edit, MultiEdit, Write, Glob, Grep, Bash, Task
---

Orchestrate migration for: $ARGUMENTS

Prerequisite check:

1. Verify the migration target is specified. If `$ARGUMENTS` is empty:
   - **What's wrong**: No migration target specified.
   - **How to fix**: Provide a target, e.g., `#mg React 18 to 19` or `#mg Python 3.11 to 3.12`.
2. Verify the project has a recognizable dependency file (package.json, pyproject.toml, go.mod, etc.). If not found:
   - **What's wrong**: Cannot determine project dependencies.
   - **How to fix**: Ensure you're in the correct project directory.

Phase 1 — Impact analysis:

1. Identify the migration target (framework version, API change, language upgrade).
2. Use `migration-specialist` to scan the codebase for affected patterns.
3. Use `repo-librarian` to map the current architecture and dependencies.
4. Produce an impact report:
   - Files affected (count and list)
   - Breaking changes detected
   - Deprecated APIs in use
   - Test coverage of affected areas

Phase 2 — Migration plan:

1. Use `planner-sisyphus` to create a phased migration plan.
2. Group changes into independent slices that can be verified separately.
3. Identify rollback points between slices.
4. Run `critic` to verify the plan is executable.

Phase 3 — Execution:

1. Execute one slice at a time using `build-integrator`.
2. After each slice, run targeted verification.
3. If a slice fails verification, diagnose with `bug-hunter` before proceeding.
4. Track progress in the todo list.

Phase 4 — Verification:

1. Run full test suite after all slices complete.
2. Check for remaining deprecated API usage.
3. Verify no regressions in functionality.
4. End with:
   - Migration summary
   - Files changed
   - Breaking changes resolved
   - Remaining manual steps (if any)
   - Verification results
