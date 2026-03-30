---
name: self-test
description: "Validate omo plugin integrity — structure, frontmatter, script permissions, version consistency. Activate when #st appears anywhere in the user message."
argument-hint: ""
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash
---

Run omo plugin self-test.

Phase 1 — Structure check:

1. Verify `.claude-plugin/plugin.json` exists and is valid JSON.
2. Verify `.claude-plugin/marketplace.json` exists and is valid JSON.
3. Check that `skills/`, `agents/`, `scripts/`, `templates/`, `examples/` directories exist.

Phase 2 — Version consistency:

1. Extract version from `plugin.json`.
2. Extract version(s) from `marketplace.json` (metadata.version and plugins[0].version).
3. If any versions differ, report as FAIL with details.
4. If `scripts/check-version.sh` exists, run it and report the result.

Phase 3 — Skill validation:

For each directory in `skills/`:
1. Check that `SKILL.md` exists.
2. Verify the frontmatter has required fields: `name`, `description`, `allowed-tools`.
3. Verify the `name` field matches the directory name.

Phase 4 — Agent validation:

For each `.md` file in `agents/`:
1. Verify the frontmatter has required fields: `name`, `description`, `tools`, `model`, `maxTurns`.
2. Verify `model` is one of: `haiku`, `sonnet`, `opus`.

Phase 5 — Script validation:

For each `.sh` file in `scripts/`:
1. Check the file has a shebang line (`#!/usr/bin/env bash` or `#!/bin/bash`).
2. Check the file has execute permission.
3. If `shellcheck` is available, run it on each script and report warnings.

Phase 5.5 — Hooks validation:

1. Check if `hooks/hooks.json` exists.
2. If it exists, verify it is valid JSON.
3. Check that it defines `Stop`, `SessionStart`, `Notification`, `SubagentStop`, `TeammateIdle`, `TaskCompleted`, and `PreCompact` hook events.
4. Verify each hook command references a script that exists in `scripts/`.

Phase 5.6 — Config validation:

1. If `.omo/config.json` exists, run `bash scripts/validate-config.sh` and report the result.
2. If `.omo/config.json` does not exist, report as SKIP (config is optional).
3. If config exists, verify that every agent's `category:` field matches a category defined in the config.

Phase 6 — Report:

Summarize results:
```
omo self-test results
=====================
Plugin version: X.Y.Z
Structure:      PASS/FAIL
Versions:       PASS/FAIL (details if fail)
Skills (N):     PASS/FAIL (details if fail)
Agents (N):     PASS/FAIL (details if fail)
Scripts (N):    PASS/FAIL (details if fail)
Hooks:          PASS/FAIL/SKIP (details if fail)
Config:         PASS/FAIL/SKIP (details if fail)

Overall: PASS / FAIL (N issues)
```

If any check fails, list each failure with enough detail to fix it.
