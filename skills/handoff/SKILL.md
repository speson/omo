---
name: handoff
description: "Write a structured handoff note and refresh current task state so work can resume cleanly later. Activate when #ho appears anywhere in the user message."
argument-hint: "[next-step-or-empty]"
disable-model-invocation: false
allowed-tools: Read, Edit, MultiEdit, Write, Glob, Grep, Bash
---

Prepare a handoff for: $ARGUMENTS

1. Read `.claude/state/current-task.txt` and the current task note if they exist.
2. Inspect the current diff or recently touched files.
3. Create or refresh a handoff note under `.claude/state/handoffs/`.
4. Include:
   - current objective
   - status
   - touched files
   - verification run
   - blockers and risks
   - exact next step
5. If `$ARGUMENTS` is present, use it as the preferred next step.
6. Reply with the handoff path and the single best resume command or prompt.
