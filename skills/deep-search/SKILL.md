---
name: deep-search
description: "Multi-strategy parallel search across the codebase. Combines symbol search, text patterns, file structure, imports, and git history for comprehensive results. Activate when #ds appears anywhere in the user message."
argument-hint: "[query]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Task
---

Search the codebase for: $ARGUMENTS

Execute a multi-strategy parallel search to find code comprehensively.

Step 1 — Analyze the query:

- What did the user literally ask?
- What are they actually trying to accomplish?
- What result would let them proceed immediately?

Step 2 — Launch parallel searches (at least 3 strategies simultaneously):

1. **Symbol search** — Grep for function names, class names, type definitions, variable declarations.
2. **Text search** — Grep for string literals, error messages, log output, comments.
3. **File pattern search** — Glob for file naming conventions and directory structure.
4. **Import search** — Grep for import/require/use statements to trace dependency chains.
5. **Git history search** — If git is available, search `git log` for when code was added, modified, or deleted.

Use `deepsearch` agent for parallel execution when the query is broad. Use direct `Grep` and `Glob` when the query is specific.

Step 3 — Synthesize results:

- Deduplicate findings across strategies.
- Rank by relevance: exact matches first, then partial, then contextual.
- For each result, explain WHY it is relevant to the query.
- Rate overall confidence: HIGH (exact match), MEDIUM (likely match), LOW (best guess).

Step 4 — Provide actionable output:

- If the user asked "where is X": provide the exact file and line.
- If the user asked "how does X work": trace the flow and explain it.
- If the user asked "find all X": provide a comprehensive list.

End with:

- `Files` (absolute path and relevance for each)
- `Answer` (direct answer to the actual need)
- `Confidence`
- `Alternative queries` (if confidence is not HIGH)
