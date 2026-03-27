---
name: resume-work
description: "Recover session context quickly from the current repo state, pending changes, and recent commands. Use when the user says continue, resume, or asks what was in progress. Activate when #rw appears anywhere in the user message."
argument-hint: "[goal-or-empty]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Task
---

Recover context for: $ARGUMENTS

1. Check Boulder state first: run `bash scripts/boulder-check.sh`. If an active Boulder task exists, prioritize its context for recovery.
2. Read repo-local `CLAUDE.md` if it exists and `.claude/state/current-task.txt`.
3. Inspect the current working tree if git is available:
   - `git status --short`
   - `git diff --stat`
   - `git diff --name-only`
4. If there is no git metadata, inspect recently modified files in the working directory instead.
5. Read the latest task note and the latest handoff if they exist.
6. Read recent briefings from `.claude/state/briefings/` if they exist.
7. If `.claude/state/memory/index.md` exists, read it for project knowledge context.
8. Use `repo-librarian` if you need to reconstruct feature intent from file names or docs.
9. Summarize:
   - likely task in progress
   - touched files
   - unfinished work
   - next 3 actions
   - best verification command
   - Boulder status (if active)
10. If the user supplied new instructions in `$ARGUMENTS`, merge them into the next-step proposal.
