---
name: ultrawork
description: "Orchestrate large Claude Code tasks with planning, todo discipline, subagent delegation, parallel execution, and targeted verification. Does not stop until the task is done or explicitly blocked. Activate when #ulw appears anywhere in the user message."
argument-hint: "[goal]"
disable-model-invocation: false
allowed-tools: Read, Edit, MultiEdit, Write, Glob, Grep, Bash, Task
---

Execute this workflow for: $ARGUMENTS

Use this when the task is larger than a quick edit or when the user wants rigorous execution.

Phase 0 — Intent gate:

- If the user only asked a question, answer directly and do not force the full workflow.
- If the task is trivial (single file, obvious fix), execute directly without ceremony.
- For everything else, proceed to phase 1.

Phase 1 — Context and planning:

1. Restate the goal in one sentence.
2. Read repo-local `CLAUDE.md` if it exists, `.claude/state/` if it exists, and the minimal repo files needed to discover canonical commands.
3. If `.claude/state/current-task.txt` is empty or stale, create or refresh a task note with `/omo:kickoff-task`.
4. Create a todo list before editing. Keep it updated as work progresses.
5. Use `repo-librarian` or built-in `Explore` for read-heavy discovery. Use `planner-sisyphus` when the task is still fuzzy after initial discovery.
6. If the plan is complex (5+ steps), run `critic` to verify the plan is executable before starting.

Phase 2 — Execution:

7. If the task is a bug, bring in `bug-hunter` before editing. If verification is expensive or unclear, bring in `test-commander`.
8. If the work splits cleanly into independent slices, use `/omo:spawn` or delegate at most 3 slices in parallel via `Task` with `run_in_background=true`. If the repo is a git repo and the change is much larger, suggest built-in `/batch` instead.
9. Implement the smallest coherent slice first. Re-plan after the first slice if reality changed.
10. After each meaningful edit cluster, run targeted verification immediately.

Phase 3 — Verification and completion:

11. Run `/omo:ship-check` or the best final verification available.
12. If verification fails, fix and re-verify. Do not stop at partial completion.
13. If the task pauses before completion (context limit approaching), run `/omo:handoff`.
14. Before finishing, provide:
    - outcome
    - files changed
    - verification results
    - remaining risks

Specialist delegation:

- `oracle` for architecture decisions or after 2+ failed fix attempts.
- `bug-hunter` for debugging and failure triage.
- `test-commander` for verification strategy.
- `build-integrator` for implementation slices.
- `deepsearch` for comprehensive codebase search.
- `critic` for plan review before execution.
- `vision` for screenshot or image analysis.
- `docs-keeper` for documentation cleanup.

Guardrails:

- Do not spend turns building abstractions for the workflow itself.
- Prefer repo-local skills and agents over user-global ones.
- If an MCP server is missing, continue with native tools rather than blocking.
- Do not stop until all todos are complete and verified, or a hard blocker is found.
- Do not expand scope beyond the original goal without explicit user approval.
