---
name: comment-check
description: "Review new or edited comments, docs, and prompts for generic AI wording, stale claims, or low-signal narration. Activate when #cc appears anywhere in the user message."
argument-hint: "[paths-or-scope]"
disable-model-invocation: false
allowed-tools: Read, Edit, MultiEdit, Write, Glob, Grep, Bash, Task
---

Audit comments and prose in: $ARGUMENTS

Focus on:

- comments that restate obvious code
- generic AI filler
- comments that can drift out of date
- docs that mention commands or paths no longer present
- long explanations that should become code or tests

Process:

1. Prefer changed files if no path was given.
2. If git is available, inspect only modified files first.
3. Delegate broad prose-heavy cleanup to `docs-keeper` when that is faster than editing inline.
4. Rewrite comments to be shorter and more durable.
5. Delete comments that add no value.
6. Report the files touched and the style issues removed.
