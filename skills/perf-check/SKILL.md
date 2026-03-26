---
name: perf-check
description: "Performance impact analysis — detect O(n²) patterns, large bundle risks, unbounded data structures, and expensive operations in recent changes. Activate when #pc appears anywhere in the user message."
argument-hint: "[scope-or-empty]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Task
---

Analyze performance impact for: $ARGUMENTS

Phase 1 — Identify scope:

1. If a scope argument is provided, focus on those files.
2. Otherwise, inspect the current git diff (`git diff HEAD` and `git diff --cached`).
3. List all modified/added files.

Phase 2 — Pattern detection:

Use `perf-analyst` agent to analyze the code for:

1. **Algorithmic complexity**: Nested loops over collections, repeated array scans, quadratic string building.
2. **Unbounded growth**: Arrays/maps that grow without limits, missing pagination, uncapped caches.
3. **Expensive operations**: Synchronous file I/O in hot paths, unindexed database queries, N+1 query patterns.
4. **Bundle impact**: New large dependencies, unused imports, duplicated libraries.
5. **Memory leaks**: Event listeners not cleaned up, growing closures, retained references.

Phase 3 — Report:

For each finding:
```
[SEVERITY: HIGH|MEDIUM|LOW] file:line
Pattern: <description>
Impact: <what happens at scale>
Suggestion: <how to fix>
```

Phase 4 — Summary:

```
Performance Analysis
====================
Files analyzed: N
Findings: N (H high, M medium, L low)
Top risk: <one-liner>
Recommendation: <proceed / fix before merge / needs discussion>
```
