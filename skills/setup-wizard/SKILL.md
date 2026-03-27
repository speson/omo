---
name: setup-wizard
description: "Auto-detect and configure omo prerequisites — Stop hook registration, MCP settings, statusline configuration. Activate when #sw appears anywhere in the user message."
argument-hint: "[--full]"
disable-model-invocation: false
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, Task
---

Configure omo for this workspace. Arguments: $ARGUMENTS

Phase 1 — Environment check:

1. Detect plugin installation by checking whether skills/ and agents/ directories are accessible.
2. Run `bash scripts/ensure-hooks.sh` to verify the ralph-loop Stop hook is registered. If the script registers the hook, report it. If it was already present, confirm.
3. Run `bash scripts/mcp-doctor.sh` to check MCP configuration status.
4. Check whether `.claude/state/` directory exists and is writable.
5. Check whether `.omo/config.json` exists. If not, note it for Phase 2.

Phase 2 — Auto-fix:

For each issue found in Phase 1:
- Missing Stop hook → `ensure-hooks.sh` already handled it.
- Missing `.claude/state/` directory → create it with tasks/ and handoffs/ subdirectories.
- MCP placeholders detected → list which servers have placeholders and suggest concrete replacements using the examples in `examples/`.
- Missing `.omo/config.json` → run `bash scripts/init-config.sh` to generate default config.

Phase 3 — Report:

Summarize in a table:
| Component | Status | Action taken |
|-----------|--------|-------------|

Components to check:
- Stop hook (ralph-loop-guard.sh)
- State directory (.claude/state/)
- MCP configuration
- Current task pointer
- Config file (.omo/config.json)

Phase 4 — Full mode (if `--full` flag is present):

If the user passed `--full`:
1. Run `/omo:repo-radar` to generate a repository map.
2. Initialize `.claude/state/task-history.log` if it does not exist.
3. Create a starter task note via `bash scripts/new-task-note.sh "Initial setup complete"`.

Tips:
- Do not overwrite existing configuration. Only add missing entries.
- Be explicit about every change made.
- If everything is already configured, say so and suggest next steps.
