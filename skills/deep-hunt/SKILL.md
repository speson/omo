---
name: deep-hunt
description: "Bug hunt with parallel deep search — capture symptoms, run multi-strategy search, narrow to likely causes, and choose verification. Activate when #dh appears anywhere in the user message."
argument-hint: "<symptom-or-failure>"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Task
---

Investigate this failure: $ARGUMENTS

Step 1 — Frame the problem:

- Restate the symptom as a failing expectation: "X should Y, but Z happens instead."
- If `.claude/state/memory/failures.md` exists, check for similar known failure patterns before searching.

Step 2 — Parallel investigation (launch simultaneously):

Dispatch both agents at the same time via `Task` with `run_in_background=true`:

1. **`bug-hunter`** — narrow likely causes, reproduction paths, and suspect files.
2. **`deepsearch`** — multi-strategy search: symbols, text patterns, imports, file structure, git history across all relevant code paths.

Do not wait for one before launching the other.

Step 3 — Merge findings:

- Correlate `deepsearch` results with `bug-hunter`'s likely causes.
- Identify files that appear in both agents' findings — these are the highest-confidence candidates.
- Deduplicate and rank: confirmed suspects first, then probable, then possible.

Step 4 — Narrow to reproduction:

- Identify the smallest reproduction case that triggers the failure.
- Identify the smallest verification check that can confirm the fix.
- If cause is clear, hand to `build-integrator` for implementation.
- If the first fix attempt fails, escalate to `oracle` immediately — do not retry the same approach.

Step 5 — Report:

- `Files` — absolute paths of suspect files with relevance
- `Likely causes` — ranked hypotheses
- `Reproduction` — steps to reproduce
- `Verification command` — narrowest check that proves the fix
- `Confidence` — HIGH / MEDIUM / LOW
- `Remaining uncertainty` — what is still unknown
