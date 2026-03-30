---
name: spawn
description: "Dispatch multiple agents in parallel for independent tasks. Use when work splits cleanly into non-overlapping units that can execute simultaneously. Activate when #sp appears anywhere in the user message."
argument-hint: "[goal]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Task, TeamCreate, SendMessage, TaskCreate, TaskUpdate, TaskList
---

Parallel dispatch for: $ARGUMENTS

Orchestrate multiple agents working simultaneously on independent tasks.

Step 0 — Check team mode:

- Read team config: `bash scripts/read-config.sh teams.enabled true`
- If teams are enabled AND the goal decomposes into 3+ units, use team-based dispatch (Step 3a).
- If teams are disabled OR fewer than 3 units, use direct dispatch (Step 3b, current behavior).
- Read max teammates: `bash scripts/read-config.sh teams.max_teammates 8`

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

Step 3a — Team-based dispatch:

- Create a team with TeamCreate: name it based on the goal slug.
- Register each unit as a task via TaskCreate with clear descriptions.
- Set up task dependencies via TaskUpdate (addBlockedBy) for units that depend on others.
- Dispatch agents as teammates using Task with `team_name` parameter and `run_in_background=true`.
- Assign each task to its teammate via TaskUpdate with `owner` parameter.
- Maximum concurrent teammates from config (default 8, max 20).

Step 3b — Direct dispatch (no team):

- Dispatch all independent units simultaneously using `Task` with `run_in_background=true`.
- Maximum parallel agents is configured in `.omo/config.json` under `spawn.max_concurrent_agents` (default: 5). Read the limit with: `bash scripts/read-config.sh spawn.max_concurrent_agents 5`.
- Each agent prompt must include:
  - Exact task description
  - Expected output format
  - Scope boundaries (what NOT to touch)

Step 4 — Collect and integrate results:

- **Team mode:** Use TaskList to monitor progress. Wait for all tasks to reach `completed` status. Send messages via SendMessage if teammates need guidance.
- **Direct mode:** Wait for all background agents to complete.
- Merge results, checking for conflicts or contradictions.
- If any agent failed, decide: retry, reassign, or skip.

Step 5 — Report:

- Summarize what each agent accomplished.
- Flag any conflicts between agent outputs.
- Identify remaining work that could not be parallelized.
- **Team mode:** Use SendMessage with type "shutdown_request" to gracefully terminate all teammates after reporting.

Rules:

- Only skip spawning if the total work is a single step. For 2+ independent steps, always parallelize.
- Do not spawn more agents than there are independent units.
- If an agent's output affects another agent's work, they cannot be parallel.
- Prefer `/batch` for git-based parallel work on separate branches.
- When in doubt, spawn. Parallel execution that finishes faster is worth the extra tokens.

End with:

- `Agents dispatched` (agent name, task, status for each)
- `Results` (merged summary)
- `Conflicts` (if any)
- `Remaining work` (if any)
