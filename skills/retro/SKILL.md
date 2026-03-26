---
name: retro
description: "Retrospective analysis after ultrawork or ralph-loop sessions — agent usage patterns, bottlenecks, and improvement suggestions. Activate when #re appears anywhere in the user message."
argument-hint: ""
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Task
---

Run a retrospective analysis of the most recent work session.

Phase 1 — Gather evidence:

1. Read `.claude/state/task-history.log` for recent task events.
2. Read `.claude/state/current-task.txt` and the corresponding task note in `.claude/state/tasks/`.
3. Read recent handoff notes in `.claude/state/handoffs/`.
4. Check if `.claude/state/ralph-loop.json` exists (indicates ralph-loop was used).
5. Read recent briefings from `.claude/state/briefings/` if they exist.

Phase 2 — Analyze patterns:

1. Which agents were used and how often (estimate from task notes and briefings).
2. Were there repeated failures or retries.
3. How many iterations did ralph-loop take (if used).
4. Were there scope changes or blockers.
5. Did the task complete successfully or was it handed off.

Phase 3 — Generate retrospective:

```
Session Retrospective
=====================
Task: [task name]
Duration: [estimated from timestamps]
Agents used: [list]

What went well:
- [bullet points]

What could improve:
- [bullet points]

Bottlenecks:
- [bullet points]

Recommendations for next time:
- [bullet points]

Patterns to remember:
- [items worth saving to .claude/state/memory/ for future sessions]
```

Phase 4 — Memory update:

If `.claude/state/memory/` exists, suggest specific entries to add based on the retrospective findings. Do not auto-write — present suggestions and ask before writing.
