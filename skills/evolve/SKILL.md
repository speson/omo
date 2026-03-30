---
name: evolve
description: "Automated self-improvement pipeline — collect metrics, run parallel multi-agent analysis, synthesize findings, generate validated sprint plan. Activate when #ev appears anywhere in the user message."
argument-hint: "[focus-or-empty]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Task
---

Run the automated self-improvement pipeline for: $ARGUMENTS

Step 1 — Check disabled:

Run `bash scripts/check-skill-disabled.sh evolve`. If disabled, inform the user and stop.

Phase 1 — Baseline:

Run `bash scripts/collect-metrics.sh` to collect project metrics. Parse the JSON output and store it as the baseline for this run.

Phase 2 — Discovery:

Read `.omo/config.json` for evolve settings. Use `bash scripts/read-config.sh evolve.max_discovery_agents 6` and `bash scripts/read-config.sh evolve.include_memory true` to get config values.

If `$ARGUMENTS` contains a focus area, instruct each agent to focus on that area only.

Dispatch up to `max_discovery_agents` agents in parallel using `Task` with `run_in_background=true`:

1. **security-auditor** (subagent_type: `omo:security-auditor`):
   "Analyze the project for security improvement opportunities — hardening, missing best practices, proactive defenses. Do NOT modify any files. Output: severity-tagged findings as a bullet list."

2. **perf-analyst** (subagent_type: `omo:perf-analyst`):
   "Analyze the project for performance improvement opportunities — algorithmic inefficiency, script optimization, unnecessary work. Do NOT modify any files. Output: impact-tagged findings as a bullet list."

3. **test-commander** (subagent_type: `omo:test-commander`):
   "Analyze test coverage gaps — untested paths, missing edge cases, low-confidence areas. Current baseline metrics: {insert baseline metrics}. Do NOT run or modify tests. Output: gap analysis as a bullet list."

4. **repo-librarian** (subagent_type: `omo:repo-librarian`):
   "Analyze for convention inconsistencies — naming patterns, file organization, structural inconsistencies across the codebase. Do NOT modify any files. Output: inconsistency findings as a bullet list."

5. **deepsearch** (subagent_type: `omo:deepsearch`):
   "Search for code duplication, dead code, unused patterns, and copy-paste opportunities to consolidate. Do NOT modify any files. Output: findings as a bullet list."

6. **memory-keeper** (subagent_type: `omo:memory-keeper`) — skip if `include_memory` is false:
   "Analyze .claude/state/memory/ for recurring failures, stale decisions, unaddressed improvements from past sessions. Do NOT modify any files. Output: findings as a bullet list."

Wait for all agents to complete and collect their results.

Phase 3 — Synthesis:

Dispatch `oracle` (subagent_type: `omo:oracle`) with all discovery results:

"You are synthesizing findings from 6 parallel analysis agents. Here are their reports:

{insert all agent reports}

Create an IMPACT x EFFORT matrix:
- IMPACT levels: HIGH / MEDIUM / LOW
- EFFORT levels: Quick (< 1hr) / Short (1-4hr) / Medium (4-8hr) / Large (> 8hr)

Group the top 3-5 improvement items into a prioritized sprint backlog. Prioritize HIGH-IMPACT + Quick/Short items first. For each item include:
1. Title
2. Impact level and reasoning
3. Effort level and reasoning
4. Which agent(s) identified it
5. Specific files/areas affected
6. Suggested agent for implementation"

Phase 4 — Planning:

Read `bash scripts/read-config.sh evolve.auto_plan true`. If `auto_plan` is true, dispatch `planner-sisyphus` (subagent_type: `omo:planner-sisyphus`) with the oracle's prioritized sprint:

"Create an executable sprint plan from this prioritized backlog:

{insert oracle synthesis}

For each item, provide:
1. Numbered step-by-step implementation instructions
2. Agent assignment (which omo agent should execute each step)
3. Parallelization opportunities (which steps can run simultaneously)
4. Verification strategy (how to confirm each step succeeded)
5. Estimated metric impact (which baseline metrics should improve)"

If `auto_plan` is false, skip this phase and proceed to output with just the synthesis.

Phase 5 — Validation:

Dispatch `critic` (subagent_type: `omo:critic`) with the sprint plan:

"Validate this sprint plan for executability:

{insert sprint plan}

Check:
1. All file references exist in the repository
2. Agent assignments match available agents (20 agents listed in CLAUDE.md)
3. Steps are specific enough to execute without ambiguity
4. Parallelization claims are valid (no hidden dependencies)
5. Verification strategies will actually catch regressions
6. Estimate metric deltas (e.g., test count +12, shellcheck issues -3)

Output: validated plan with any corrections, plus a confidence score (HIGH/MEDIUM/LOW)."

Output:

1. Generate a timestamp slug: `YYYYMMDD-HHMMSS-{focus-or-general}`
2. Save the full report to `.claude/state/improvements/{slug}.md` with sections:
   - Baseline Metrics
   - Discovery Findings (per agent)
   - Synthesis (IMPACT x EFFORT matrix)
   - Sprint Plan (if auto_plan was true)
   - Validation Results
3. Run `bash scripts/improvement-log.sh "{slug}" "{one-line summary}"`
4. Present a concise summary to the user:
   - Key findings count per category
   - Top 3-5 improvements with impact/effort
   - Suggested next command: `#ulw {sprint description}` or `#rl {sprint description}`
