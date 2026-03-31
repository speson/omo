---
name: status
description: "Show unified omo status dashboard — boulder, ralph-loop, tasks, teams, and memory state at a glance. Activate when #ss appears anywhere in the user message."
argument-hint: ""
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash
---

Show the current omo status dashboard.

1. Run `bash scripts/status-dashboard.sh` and display the output to the user.
2. If any system shows an active state, provide a brief recommendation:
   - Boulder active → suggest `#rw` to resume or `#ho` to handoff
   - Ralph Loop active → note the current phase and what's needed next
   - No current task → suggest `#kit` to start one
3. If everything is inactive, say "All clear — ready for new work."
