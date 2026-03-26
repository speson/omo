---
name: tool-check
description: "Detect external tool dependencies and verify they are installed. Provide installation guidance for missing tools. Activate when #tc appears anywhere in the user message."
argument-hint: ""
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash
---

Check external tool dependencies.

Phase 1 — Detect required tools:

1. Scan the repository for tool references:
   - `package.json` scripts → node, npm/yarn/pnpm, npx
   - `Makefile` / `Taskfile` → make, task
   - `Dockerfile` / `docker-compose.yml` → docker, docker-compose
   - `*.sh` scripts → bash, jq, curl, shellcheck
   - `.github/workflows/` → gh (GitHub CLI)
   - `pyproject.toml` / `requirements.txt` → python, pip, poetry
   - `go.mod` → go
   - `Cargo.toml` → cargo, rustc

Phase 2 — Verify installation:

For each detected tool, check if it's available:
- Run `command -v <tool>` or `<tool> --version`
- Record version if available

Phase 3 — Report:

```
Tool Check
==========
| Tool | Required | Installed | Version |
|------|----------|-----------|---------|
| node | yes | yes | v20.x |
| jq | yes | no | - |
...

Missing tools:
- jq: Install with `brew install jq` (macOS) or `apt install jq` (Linux)
...

All required tools available: YES/NO
```
