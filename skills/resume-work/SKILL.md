---
name: resume-work
description: "Recover session context quickly from the current repo state, pending changes, and recent commands. Use when the user says continue, resume, or asks what was in progress. Activate when #rw appears anywhere in the user message."
argument-hint: "[goal-or-empty]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Task
---

Recover context for: $ARGUMENTS

1. Read repo-local `CLAUDE.md` if it exists and `.claude/state/current-task.txt`.
2. Inspect the current working tree if git is available:
   - `git status --short`
   - `git diff --stat`
   - `git diff --name-only`
3. If there is no git metadata, inspect recently modified files in the working directory instead.
4. Read the latest task note and the latest handoff if they exist.
5. Read recent briefings from `.claude/state/briefings/` if they exist.
6. If `.claude/state/memory/index.md` exists, read it for project knowledge context.
7. Use `repo-librarian` if you need to reconstruct feature intent from file names or docs.
8. Summarize:
   - likely task in progress
   - touched files
   - unfinished work
   - next 3 actions
   - best verification command
9. If the user supplied new instructions in `$ARGUMENTS`, merge them into the next-step proposal.
