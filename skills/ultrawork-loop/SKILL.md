---
name: ultrawork-loop
description: "Ultrawork with Ralph Loop enforcement — persistent execution that does not stop until the task is complete and verified. Activate when #uwl appears anywhere in the user message."
argument-hint: "[goal] [--oracle]"
disable-model-invocation: false
allowed-tools: Read, Edit, MultiEdit, Write, Glob, Grep, Bash, Task
---

Execute this persistent ultrawork loop for: $ARGUMENTS

Phase 0 — Intent gate:

- If the user only asked a question, answer directly and do not force the full workflow.
- If the task is trivial (single file, obvious fix), execute directly without ceremony.
- For everything else, proceed.

Phase 1 — Initialize loop and gather context:

1. Run `bash scripts/ensure-hooks.sh` to verify the Stop hook is registered. If missing and cannot auto-register, tell the user to run `#sw` or manually add the hook from `examples/hooks.json.example`.
2. Check if `--oracle` flag is present in the arguments, then initialize the loop:
   - With Oracle: `bash scripts/ralph-loop-start.sh "<goal>" --oracle`
   - Without Oracle: `bash scripts/ralph-loop-start.sh "<goal>"`
3. Initialize Boulder: `bash scripts/boulder-init.sh "<goal>"`
4. Restate the goal in one sentence.
5. Read repo-local `CLAUDE.md` if it exists, `.claude/state/` if it exists, and the minimal repo files needed to discover canonical commands.
   - If `.claude/state/memory/index.md` exists, read it for project knowledge from past sessions.
   - If `.claude/state/briefings/` has recent entries, read them for continuity.
6. Create a todo list with all concrete steps before editing.
7. **Parallel discovery**: Run `deepsearch` + `repo-librarian` simultaneously for broad context. Use `planner-sisyphus` if the task is still fuzzy after discovery.
8. If the plan has 3+ steps, run `critic` to verify executability before starting.

Phase 2 — Execution (parallelize aggressively):

9. If the task is a bug, bring in `bug-hunter` + `deepsearch` in parallel before editing. If verification is expensive or unclear, bring in `test-commander`.
10. If the work splits cleanly into independent slices, delegate up to 5 slices in parallel via `Task` with `run_in_background=true`.
    - Each slice: ≤3 files or ≤3 edit sites. Never paste file contents into Task prompts.
    - Docs (`.md`, guides, READMEs) → `docs-keeper`. Code files → `build-integrator`.
11. Implement the smallest coherent slice first. Re-plan after the first slice if reality changed.
12. After every 3 completed todo items, reassess the remaining plan.
13. After each meaningful edit cluster, run targeted verification immediately.

Phase 3 — Verification and completion:

14. Run `/omo:ship-check` AND `/omo:diff-review` together in parallel for final verification.
15. If verification fails, fix and re-verify. Escalate to `oracle` after the first failed fix attempt.
16. If context limit approaches, run `/omo:handoff` before compaction.
17. When ALL todos are complete and self-verified, signal completion:
    - `bash scripts/ralph-loop-done.sh`
    - `bash scripts/boulder-complete.sh`

What happens next depends on mode:

**Standard mode** (no `--oracle`):
- Transitions to `verified` phase. Stop hook allows you to stop.

**Oracle mode** (`--oracle`):
- Transitions to `verification_pending`. Stop hook blocks and instructs you to call Oracle.
- Call Oracle for independent verification: `task(subagent_type="oracle", prompt="Review this work skeptically...")`
- Oracle approves → `bash scripts/ralph-loop-verified.sh` → loop ends
- Oracle rejects → `bash scripts/ralph-loop-reject.sh` → fix issues and retry

State machine:

```
[working] ──done.sh──→ [verification_pending] ──verified.sh──→ [verified] → stop allowed
                              ↑          │
                              └──reject.sh──┘
                           (Oracle rejected, fix & retry)
```

18. On completion, report: outcome, files changed, verification results, remaining risks.

Guardrails:

- Do not run `ralph-loop-done.sh` until the task is truly complete and self-verified.
- Do not run `ralph-loop-verified.sh` without actually calling Oracle and getting approval.
- Do not expand scope beyond the original goal without explicit user approval.
- If stuck on a step for 2+ attempts, try a different approach or consult `oracle`.
- If an MCP server is missing, continue with native tools rather than blocking.
