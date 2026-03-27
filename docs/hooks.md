# omo Hook System

omo uses Claude Code lifecycle hooks to enforce execution loops, restore session context, and nudge task resumption.

## Hook Registration

Hooks are registered via `hooks/hooks.json` (plugin-native). When omo is installed as a plugin, hooks are auto-registered. For manual setups, run `bash scripts/ensure-hooks.sh`.

## Hook Events

### Stop

**Script:** `scripts/ralph-loop-guard.sh`
**Matcher:** `""` (all stop events)
**Can block:** Yes (exit 2)

Intercepts agent stop attempts during Ralph Loop execution. Blocks stop if the task is in `working` or `verification_pending` phase.

### SessionStart

**Script:** `scripts/session-context-hook.sh`
**Matcher:** `"startup|resume"`
**Timeout:** 10 seconds

Injects Boulder task context on session start or resume. Skipped for `clear` source sessions. Outputs up to 5 lines of context including active task, goal, and last outcome.

### Notification

**Script:** `scripts/idle-resume-hook.sh`
**Matcher:** `"idle_prompt"`
**Timeout:** 5 seconds

Nudges the user to resume a pending Boulder task when idle. Only fires if `auto_resume` is enabled in the Boulder state.

## Hook Input/Output

All hooks receive JSON via stdin:

```json
{
  "session_id": "...",
  "cwd": "/path/to/project",
  "hook_event_name": "SessionStart",
  "source": "resume"
}
```

Hooks output JSON via stdout:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "..."
  }
}
```

For Stop hooks, exit code 2 blocks the stop. The stdout message is fed back to the agent.

## Environment Variables

| Variable | Description | Fallback |
|---|---|---|
| `CLAUDE_PLUGIN_ROOT` | Plugin installation root | Script-relative path |
| `CLAUDE_PROJECT_DIR` | Current project directory | `.` |

## Manual Hook Registration

If plugin-native hooks are not available, add to `.claude/settings.local.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash scripts/ralph-loop-guard.sh"
          }
        ]
      }
    ]
  }
}
```

## Troubleshooting

- **Hooks not firing:** Check `hooks/hooks.json` is valid JSON. Run `bash scripts/validate-schema.sh`.
- **CLAUDE_PROJECT_DIR not set:** Scripts fall back to `.` (current directory). This works for most setups.
- **Timeout errors:** SessionStart has a 10s timeout, Notification has 5s. If Boulder state is on a slow filesystem, consider increasing timeouts.
