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

Phase 1 — Context and planning (invest tokens here to save rework later):

1. Restate the goal in one sentence.
2. Read repo-local `CLAUDE.md` if it exists, `.claude/state/` if it exists, and the minimal repo files needed to discover canonical commands.
   - If `.claude/state/memory/index.md` exists, read it to leverage project knowledge from past sessions.
   - If `.claude/state/briefings/` has recent entries, read them for continuity.
3. If `.claude/state/current-task.txt` is empty or stale, create or refresh a task note with `/omo:kickoff-task`.
4. Initialize Boulder for cross-session persistence: `bash scripts/boulder-init.sh "<goal>"`
5. Create a todo list before editing. Keep it updated as work progresses.
6. **Parallel discovery**: Run `deepsearch` + `repo-librarian` (or `Explore`) simultaneously for broad context. Use `planner-sisyphus` when the task is still fuzzy after initial discovery.
7. If the plan has 3+ steps, run `critic` to verify the plan is executable before starting. Do not skip this — catching plan flaws now is cheaper than fixing them mid-execution.

Phase 2 — Execution (parallelize aggressively):

8. If the task is a bug, bring in `bug-hunter` + `deepsearch` in parallel before editing. If verification is expensive or unclear, bring in `test-commander`.
9. If the work splits cleanly into independent slices, use `/omo:spawn` or delegate up to 5 slices in parallel via `Task` with `run_in_background=true`. If the repo is a git repo and the change is much larger, suggest built-in `/batch` instead.
   - **Slice size limit**: Each delegated slice should target ≤3 files or ≤3 edit sites per file. Never paste entire file contents into a Task prompt — let the agent read files itself.
   - **Docs vs code**: Documentation files (`.md`, guides, READMEs) should be delegated to `docs-keeper` or edited directly, not to `build-integrator`. Reserve `build-integrator` for code files only.
   - **Prefer parallel over sequential**: When slices are independent, always dispatch simultaneously. Two agents in parallel > one agent doing both sequentially.
10. Implement the smallest coherent slice first. Re-plan after the first slice if reality changed.
11. After each meaningful edit cluster, run targeted verification immediately.

Phase 3 — Verification and completion (multi-perspective, never single-angle):

12. Run `/omo:ship-check` AND `/omo:diff-review` together — dispatch both in parallel for comprehensive final verification.
13. If verification fails, fix and re-verify. Do not stop at partial completion. Escalate to `oracle` after the first failed fix attempt.
14. If the task pauses before completion (context limit approaching), run `/omo:handoff`.
15. On successful completion, finalize Boulder: `bash scripts/boulder-complete.sh`
16. Before finishing, provide:
    - outcome
    - files changed
    - verification results
    - remaining risks

Specialist delegation (prefer specialists over inline analysis — they are deeper and can run in parallel):

- `oracle` for architecture decisions or after the first failed fix attempt.
- `bug-hunter` + `deepsearch` in parallel for debugging and failure triage.
- `test-commander` for verification strategy.
- `build-integrator` for code implementation slices (not docs).
- `deepsearch` for comprehensive codebase search (run alongside other specialists).
- `critic` for plan review before execution (mandatory for 3+ step plans).
- `security-auditor` for any changes touching auth, input handling, or external APIs.
- `vision` for screenshot or image analysis.
- `docs-keeper` for documentation and guide file changes (including new content, not just cleanup).

Guardrails:

- Do not spend turns building abstractions for the workflow itself.
- Prefer repo-local skills and agents over user-global ones.
- If an MCP server is missing, continue with native tools rather than blocking.
- Do not stop until all todos are complete and verified, or a hard blocker is found.
- Do not expand scope beyond the original goal without explicit user approval.
