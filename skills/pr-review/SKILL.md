---
name: pr-review
description: "Comprehensive GitHub PR review — diff analysis, CI status check, multi-perspective code review, and actionable feedback. Activate when #pr appears anywhere in the user message."
argument-hint: "[pr-number-or-url]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Task
---

Review pull request: $ARGUMENTS

Prerequisite check:

1. Verify `gh` CLI is available by running `command -v gh`. If missing:
   - **What's wrong**: GitHub CLI (`gh`) is not installed.
   - **How to fix**: Install with `brew install gh` (macOS) or see https://cli.github.com/
2. If a PR number is provided, verify the current directory is a git repo with a GitHub remote.
3. If `gh` is not available, fall back to `git diff` for local-only review.

Phase 1 — PR context:

1. If a PR number or URL is provided, fetch PR details using `gh pr view`.
2. If no PR specified, check current branch against base branch.
3. Gather:
   - PR title and description
   - Changed files list (`gh pr diff --stat` or `git diff --stat`)
   - CI status (`gh pr checks` if available)
   - Number of commits

Phase 2 — Diff analysis:

1. Read the full diff.
2. Categorize changes: new features, bug fixes, refactoring, tests, docs, config.
3. Identify scope — is the PR focused or does it mix concerns?

Phase 3 — Multi-perspective review (run in parallel if possible):

1. **Correctness**: Logic errors, edge cases, off-by-one, null handling.
2. **Security**: OWASP Top 10, secret exposure, injection risks, auth bypasses.
3. **Performance**: O(n²) patterns, unnecessary allocations, missing indexes.
4. **Maintainability**: Code clarity, naming, duplication, test coverage.
5. **Scope**: Does the PR do what it claims? Any scope creep?

Phase 4 — Report:

```
PR Review: #<number> — <title>
================================
CI Status: passing/failing/pending
Files changed: N (+additions, -deletions)

Verdict: APPROVE / REQUEST_CHANGES / COMMENT

Critical issues:
- [list if any]

Suggestions:
- [list if any]

Highlights:
- [good things worth noting]
```
