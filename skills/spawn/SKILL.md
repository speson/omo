---
name: spawn
description: "Dispatch multiple agents in parallel for independent tasks. Use when work splits cleanly into non-overlapping units that can execute simultaneously. Activate when #sp appears anywhere in the user message."
argument-hint: "[goal]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Task
---

Parallel dispatch for: $ARGUMENTS

Orchestrate multiple agents working simultaneously on independent tasks.

Step 1 — Decompose the goal:

- Break the goal into independent units that do not overlap.
- Each unit must be self-contained: clear input, clear output, no dependency on other units.
- If units have dependencies, identify the execution order and parallelize only the independent ones.

Step 2 — Select agents for each unit:

- Match each unit to the most appropriate specialist:
  - `repo-librarian` or `deepsearch` for research tasks
  - `build-integrator` for implementation tasks
  - `bug-hunter` for debugging tasks
  - `test-commander` for verification tasks
  - `oracle` for analysis tasks
  - `docs-keeper` for documentation tasks
  - `Explore` for codebase exploration

Step 3 — Launch agents in parallel:

- Dispatch all independent units simultaneously using `Task` with `run_in_background=true`.
- Maximum 5 parallel agents to prevent resource contention.
- Each agent prompt must include:
  - Exact task description
  - Expected output format
  - Scope boundaries (what NOT to touch)

Step 4 — Collect and integrate results:

- Wait for all agents to complete.
- Merge results, checking for conflicts or contradictions.
- If any agent failed, decide: retry, reassign, or skip.

Step 5 — Report:

- Summarize what each agent accomplished.
- Flag any conflicts between agent outputs.
- Identify remaining work that could not be parallelized.

Rules:

- Do not spawn agents for trivial tasks. If the total work is < 3 steps, do it directly.
- Do not spawn more agents than there are independent units.
- If an agent's output affects another agent's work, they cannot be parallel.
- Prefer `/batch` for git-based parallel work on separate branches.

End with:

- `Agents dispatched` (agent name, task, status for each)
- `Results` (merged summary)
- `Conflicts` (if any)
- `Remaining work` (if any)
