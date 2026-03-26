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
3. Ask `bug-hunter` to narrow likely causes and reproduction paths.
4. Ask `test-commander` for the smallest verification loop that can validate the hypothesis.
5. Read only the most relevant files and logs before editing.
6. If the cause becomes clear, either fix it directly or hand implementation to `build-integrator`.
7. End with:
   - reproduction
   - root-cause hypothesis
   - fix status
   - verification
   - remaining uncertainty
