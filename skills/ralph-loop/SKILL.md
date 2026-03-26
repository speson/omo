---
name: ralph-loop
description: "System-enforced development loop with optional Oracle verification. Stop hook blocks agent from stopping until task is complete and verified. Use for tasks that must reach 100% completion. Activate when #rl appears anywhere in the user message."
argument-hint: "[goal] [--oracle]"
disable-model-invocation: false
allowed-tools: Read, Edit, MultiEdit, Write, Glob, Grep, Bash, Task
---

Execute this persistent loop for: $ARGUMENTS

Prerequisite check:

Before starting, run `bash scripts/ensure-hooks.sh` to verify the Stop hook is registered. If the script reports the hook is missing and cannot auto-register, tell the user:
- **What's wrong**: The ralph-loop Stop hook is not registered in `.claude/settings.local.json`.
- **Why it matters**: Without the hook, the loop cannot prevent premature stopping.
- **How to fix**: Run `#sw` (setup-wizard) to auto-configure, or manually add the hook from `examples/hooks.json.example`.

You are entering a Ralph Loop — a system-enforced development loop. A Stop hook will BLOCK you from stopping until the task is complete.

Step 1 — Initialize the loop:

Check if `--oracle` flag is present in the arguments. Then run the appropriate command:

- With Oracle verification: `bash scripts/ralph-loop-start.sh "<goal>" --oracle`
- Without Oracle verification: `bash scripts/ralph-loop-start.sh "<goal>"`

The Stop hook (`scripts/ralph-loop-guard.sh`) will now intercept every stop attempt.

Step 2 — Work the task:

1. Restate the goal in one sentence.
2. Create a todo list with all concrete steps needed.
3. Work through each step. Mark items complete as you finish them.
4. Use specialists when appropriate:
   - `repo-librarian` or `Explore` for codebase research
   - `build-integrator` for implementation slices
   - `bug-hunter` for debugging
   - `test-commander` for verification strategy
5. After every 3 completed items, reassess the remaining plan.

Step 3 — Signal completion:

When ALL todos are complete AND you have run your own verification:

Run: `bash scripts/ralph-loop-done.sh`

What happens next depends on the mode:

**Standard mode** (no `--oracle`):
- The done script transitions to `verified` phase.
- The Stop hook will allow you to stop on your next attempt.

**Oracle mode** (`--oracle`):
- The done script transitions to `verification_pending` phase.
- The Stop hook will block you and instruct you to call Oracle.
- You MUST call Oracle for independent verification:
  ```
  task(subagent_type="oracle", prompt="Review this work skeptically...")
  ```
- Based on Oracle's response:
  - Oracle approves → run `bash scripts/ralph-loop-verified.sh` → loop ends
  - Oracle finds issues → run `bash scripts/ralph-loop-reject.sh` → back to working, fix the issues
- This cycle repeats until Oracle is satisfied.

State machine:

```
[working] ──done.sh──→ [verification_pending] ──verified.sh──→ [verified] → stop allowed
                              ↑          │
                              └──reject.sh──┘
                           (Oracle rejected, fix & retry)
```

Cancellation:

The user can cancel at any time: `bash scripts/ralph-loop-cancel.sh`

Rules:

- Do not run `ralph-loop-done.sh` until the task is truly complete and self-verified.
- Do not run `ralph-loop-verified.sh` without actually calling Oracle and getting approval.
- Do not expand scope beyond the original goal.
- If stuck on a step for 2+ attempts, try a different approach or consult `oracle`.
- If context limit approaches, run `/omo:handoff` before the system compacts.

Hook setup required:

The Stop hook must be registered. Add to `.claude/settings.local.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": ["bash scripts/ralph-loop-guard.sh"]
      }
    ]
  }
}
```
