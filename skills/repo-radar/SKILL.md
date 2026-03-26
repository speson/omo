---
name: repo-radar
description: "Build or refresh a concise repository map with deep scanning. Supports init-deep mode for generating hierarchical AGENTS.md files throughout the project. Activate when #rr appears anywhere in the user message."
argument-hint: "[scope-or-empty] [--deep]"
disable-model-invocation: false
allowed-tools: Read, Edit, MultiEdit, Write, Glob, Grep, Bash, Task
---

Map the repository for: $ARGUMENTS

Standard mode (default):

1. Read repo-local `CLAUDE.md` if it exists and inspect the repo roots, package manifests, test config, and major source directories.
2. Launch parallel discovery:
   - `repo-librarian` or `Explore` for broad codebase structure
   - `deepsearch` for conventions, anti-patterns, and key entry points
3. Update `.claude/state/repo-map.md` with:
   - major directories and their purposes
   - tech stack and key dependencies
   - build, lint, and test entry points
   - important conventions and code patterns
   - hotspots or risky areas
   - missing pieces or unknowns
4. Keep the map compact (50-150 lines) and durable.
5. Reply with the updated repo map path and the top 3 takeaways.

Deep mode (when `--deep` is specified or the repo is large):

In addition to the standard map, generate hierarchical knowledge base files:

6. Score each directory for complexity:
   - File count, subdirectory count, code concentration
   - Module boundaries (index files, package manifests)
   - Unique patterns or conventions
7. For directories scoring above threshold, create or update an AGENTS.md file containing:
   - Overview (1 line)
   - Structure (if >5 subdirectories)
   - Where to look (task-to-location table)
   - Conventions (only deviations from parent/root)
   - Anti-patterns specific to that area
8. Root AGENTS.md gets the full treatment: overview, structure, code map, conventions, commands.
9. Child AGENTS.md files never repeat parent content.
10. Review all generated files: remove generic advice, deduplicate across levels, trim to size limits.
11. Report: files created/updated, directory hierarchy, and key findings.
