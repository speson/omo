---
name: release
description: "Full release pipeline — commit, push, tag, GitHub release, marketplace version sync. Activate when #rel appears anywhere in the user message."
argument-hint: "<version>"
disable-model-invocation: false
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, Task
---

Execute a full release for version: $ARGUMENTS

Step 1 — Version validation:

1. Read `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` to get the current version.
2. If a version argument was given, verify it follows semver (e.g., `1.7.0`).
3. If no version was given, read the current version and ask what the new version should be.
4. If the version files don't already match the target version, bump them now:
   - `.claude-plugin/plugin.json` → `version` field
   - `.claude-plugin/marketplace.json` → `metadata.version` AND `plugins[0].version`

Step 2 — Pre-flight checks:

1. Run `bash tests/backtest.sh all` — abort if any test fails.
2. Run `bash scripts/validate-schema.sh` — abort if validation fails.
3. Check `git status` for uncommitted changes.

Step 3 — Commit and push:

1. If there are uncommitted changes (including the version bump from Step 1):
   - Stage all relevant files.
   - Commit with message: `v{VERSION}: {summary}`. Ask the user for a one-line summary if not obvious from the diff.
   - Push to `origin main`.
2. If already committed, just push if needed.

Step 4 — Tag:

1. Check if tag `v{VERSION}` already exists: `git tag -l v{VERSION}`.
2. If not, create it: `git tag v{VERSION}`.
3. Push the tag: `git push origin v{VERSION}`.

Step 5 — GitHub Release:

1. Check if release exists: `gh release view v{VERSION}`.
2. If not, create it with `gh release create v{VERSION}`.
3. Generate release notes from the commit message and recent changes.
4. Include: summary, key changes (bulleted), test results, files changed count.

Step 6 — Summary:

Report:
- Version: v{VERSION}
- Commit: {hash}
- Tag: v{VERSION}
- Release URL: {url}
- Marketplace version: {VERSION}
