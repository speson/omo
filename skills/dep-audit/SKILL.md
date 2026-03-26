---
name: dep-audit
description: "Dependency security audit — run ecosystem-specific audit tools and cross-verify new or updated dependencies. Activate when #da appears anywhere in the user message."
argument-hint: "[scope-or-empty]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Task
---

Audit dependencies for: $ARGUMENTS

Phase 1 — Detect ecosystem:

1. Check for `package.json` / `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml` → Node.js
2. Check for `requirements.txt` / `Pipfile` / `pyproject.toml` / `poetry.lock` → Python
3. Check for `go.mod` → Go
4. Check for `Cargo.toml` → Rust
5. Report detected ecosystems.

Phase 2 — Run audit tools:

For each detected ecosystem:
- **Node.js**: Run `npm audit --json 2>/dev/null` or `yarn audit --json 2>/dev/null`
- **Python**: Run `pip-audit 2>/dev/null` or `safety check 2>/dev/null`
- **Go**: Run `govulncheck ./... 2>/dev/null`
- **Rust**: Run `cargo audit 2>/dev/null`

If an audit tool is not installed, note it and skip.

Phase 3 — New dependency check:

1. Check `git diff HEAD` for newly added dependencies.
2. For each new dependency, note:
   - Whether it's a direct or transitive dependency
   - Its approximate download count / popularity (if determinable)
   - Any known security advisories
   - Whether it duplicates functionality already present

Phase 4 — Report:

```
Dependency Audit
================
Ecosystem: [detected]
Total dependencies: N
Vulnerabilities found: N (critical: N, high: N, medium: N, low: N)

New dependencies:
- <name>@<version>: <assessment>

Recommendations:
- [action items]
```
