---
name: kickoff-task
description: "Initialize or refresh a task note with interview-mode scoping. Questions ambiguities before planning. Defines execution and verification strategy. Activate when #kit appears anywhere in the user message."
argument-hint: "[goal]"
disable-model-invocation: false
allowed-tools: Read, Edit, MultiEdit, Write, Glob, Grep, Bash, Task
---

Initialize task context for: $ARGUMENTS

Phase 1 — Discovery:

1. Read repo-local `CLAUDE.md` if it exists, plus the nearest build or test scripts.
2. If `.claude/state/memory/index.md` exists, read project knowledge for context on conventions and past decisions.
3. Use `Explore` or `repo-librarian` to quickly understand the relevant parts of the codebase.
4. Check for existing test infrastructure (test frameworks, test commands, CI config).

Phase 2 — Scope interview (for ambiguous or complex goals):

4. Before creating the plan, assess complexity:
   - Trivial (single file, obvious fix) — skip interview, proceed directly.
   - Simple (1-2 files, clear scope) — 1-2 targeted questions.
   - Complex (3+ files, multiple interpretations) — full scoping interview.
5. For complex goals, clarify:
   - What should explicitly NOT be included? (scope boundaries)
   - What constraints exist? (do not touch X, do not change Y)
   - What does "done" look like? (acceptance criteria)

Phase 3 — Task note creation:

6. Ensure `.claude/state/tasks/` exists in the current workspace.
7. Create or refresh a task note under `.claude/state/tasks/` and point `.claude/state/current-task.txt` at it.
8. Fill the note with:
   - goal
   - assumptions
   - scope boundaries (what is included AND what is excluded)
   - likely files or areas
   - open questions
   - test strategy (existing tests to run, new tests needed)
   - planned verification
   - next actions
9. If the goal is vague, ask `planner-sisyphus` for a short plan before filling the note.
10. Reply with the task note path and the next concrete action.
