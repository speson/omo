---
name: bug-hunt
description: "Triage a failure by capturing symptoms, narrowing reproduction, isolating likely files, and choosing the smallest useful verification loop. Activate when #bh appears anywhere in the user message."
argument-hint: "[symptom]"
disable-model-invocation: false
allowed-tools: Read, Edit, MultiEdit, Write, Glob, Grep, Bash, Task
---

Investigate this bug or symptom: $ARGUMENTS

1. Restate the bug as a failing expectation.
2. If `.claude/state/memory/failures.md` exists, check for similar known failure patterns.
3. **Parallel investigation** — dispatch simultaneously:
   - `bug-hunter` to narrow likely causes and reproduction paths.
   - `deepsearch` to trace all usages of the suspected code path.
   - `test-commander` for the smallest verification loop that can validate the hypothesis.
4. Synthesize findings from all three specialists before editing.
5. If the cause becomes clear, either fix it directly or hand implementation to `build-integrator`.
6. If the first fix attempt fails, escalate to `oracle` immediately — do not retry the same approach.
7. End with:
   - reproduction
   - root-cause hypothesis
   - fix status
   - verification
   - remaining uncertainty
