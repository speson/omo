---
name: qa-loop
description: "Automated test-fix-retest cycle. Runs tests, fixes failures, and re-runs until all pass or a maximum retry count is reached. Activate when #qa appears anywhere in the user message."
argument-hint: "[test-command-or-scope]"
disable-model-invocation: false
allowed-tools: Read, Edit, MultiEdit, Write, Glob, Grep, Bash, Task
---

Run QA loop for: $ARGUMENTS

Execute an automated test → fix → retest cycle.

Step 1 — Identify the test command:

- If the user specified a command, use it.
- Otherwise, ask `test-commander` for the narrowest useful verification.
- If no test infrastructure exists, report what manual checks are needed and stop.

Step 2 — Run the initial test:

- Execute the test command.
- Capture full output including error messages, stack traces, and exit code.

Step 3 — Analyze failures:

- For each failure, identify:
  - Which test failed and what it expected.
  - The likely root cause (use `bug-hunter` if unclear).
  - The minimal fix needed.

Step 4 — Fix and retest:

- Apply the smallest fix for each failure.
- Re-run the test command.
- If new failures appear, analyze and fix those too.
- Maximum 5 fix-retest cycles to prevent infinite loops.

Step 5 — Report results:

- Track: iteration number, tests run, passed, failed, fixed.
- If all tests pass, report success.
- If failures remain after max cycles, report what is still broken and why.

Escalation:

- After 2 consecutive failures on the same test, bring in `bug-hunter` for deeper analysis.
- After 3 cycles with no progress, bring in `oracle` for architectural guidance.
- If a fix would require scope expansion beyond the original change, stop and report.

End with:

- `Test command`
- `Iterations` (number of cycles run)
- `Result` (all pass, partial, or blocked)
- `Fixes applied` (file and description for each)
- `Remaining failures` (if any, with analysis)
