# omo Development Manual

This repository is a Claude Code plugin source tree.

Core plugin assets live at the repository root:

- `.claude-plugin/plugin.json`
- `skills/`
- `agents/`
- `scripts/`
- `templates/`
- `examples/`

Primary workflows during plugin development

- Run `claude --plugin-dir .` to load the plugin directly from this repository.
- Run `/reload-plugins` after edits to pick up Skill and agent changes.
- Run `claude plugin validate .` before shipping structural changes.
- When testing the marketplace install path, prefer `claude plugin install -s local ...` and `claude plugin update -s local ...` so plugin state stays in the project's `.claude/settings.local.json`.

Skill commands and shortcuts

All skills support auto-intercept via `#shortcut` patterns. Type `#ulw auth 구현` instead of `/omo:ultrawork auth 구현`.

| Shortcut | Command | Purpose |
|----------|---------|---------|
| `#ulw` | `/omo:ultrawork <goal>` | Large execution and multi-step delivery |
| `#kit` | `/omo:kickoff-task <goal>` | Task-note bootstrapping with interview-mode scoping |
| `#rl` | `/omo:ralph-loop <goal>` | Persistent execution loops that do not stop until done |
| `#rr` | `/omo:repo-radar [scope]` | Repository mapping. Add `--deep` for hierarchical AGENTS.md |
| `#rw` | `/omo:resume-work [goal]` | Continue after a pause or switching devices |
| `#bh` | `/omo:bug-hunt <symptom>` | Regressions, flaky behavior, unclear failures |
| `#sc` | `/omo:ship-check [scope]` | Final check before shipping |
| `#dr` | `/omo:diff-review [scope]` | Multi-perspective code review on current diff |
| `#qa` | `/omo:qa-loop [test-command]` | Automated test-fix-retest cycles |
| `#ds` | `/omo:deep-search <query>` | Multi-strategy parallel codebase search |
| `#sp` | `/omo:spawn <goal>` | Dispatch multiple agents in parallel |
| `#ho` | `/omo:handoff [next-step]` | Handoff note when stopping mid-task |
| `#cc` | `/omo:comment-check [scope]` | Audit comments, docs, and prompts |
| `#mcp` | `/omo:mcp-doctor` | Diagnose MCP availability |
| `#sw` | `/omo:setup-wizard [--full]` | Auto-detect and configure omo prerequisites |
| `#st` | `/omo:self-test` | Plugin structure and version integrity check |
| `#re` | `/omo:retro` | Post-session retrospective analysis |
| `#pc` | `/omo:perf-check [scope]` | Performance impact analysis |
| `#da` | `/omo:dep-audit [scope]` | Dependency security audit |
| `#mg` | `/omo:migrate <target>` | Framework/API/language migration orchestration |
| `#pr` | `/omo:pr-review [pr-number]` | Comprehensive GitHub PR review |
| `#ob` | `/omo:onboard [focus]` | Project onboarding guide generation |
| `#tc` | `/omo:tool-check` | External tool dependency verification |

Preferred specialists

- `repo-librarian` for repo reconnaissance and convention lookup
- `planner-sisyphus` for execution planning with interview-mode scoping
- `build-integrator` for autonomous multi-file implementation
- `bug-hunter` for debugging and narrowing reproduction paths
- `test-commander` for targeted verification strategy
- `docs-keeper` for docs, prompt, and comment hygiene
- `oracle` for architecture decisions and hard debugging (use after 2+ failed attempts)
- `critic` for plan review before execution (verify executability)
- `atlas` for master orchestration of complex multi-step plans
- `vision` for screenshot, PDF, and image analysis
- `deepsearch` for multi-strategy parallel codebase search
- `perf-analyst` for performance impact analysis
- `memory-keeper` for cross-session memory management
- `security-auditor` for OWASP Top 10 and secret detection
- `test-generator` for edge-case test generation from diffs
- `migration-specialist` for pattern-based bulk transformations
- `critic-lite` for lightweight plan review (simple plans)
- `oracle-lite` for quick first-pass technical advice
- `build-integrator-heavy` for complex changes (after 2+ failures)
- `repo-librarian-deep` for deep feature tracing

Repo-local state created by the plugin

- Current task pointer: `.claude/state/current-task.txt`
- Active task notes: `.claude/state/tasks/`
- Handoffs: `.claude/state/handoffs/`
- Repo map: `.claude/state/repo-map.md`
- Task history: `.claude/state/task-history.log`
- Briefings: `.claude/state/briefings/`
- Cross-session memory: `.claude/state/memory/` (conventions, decisions, failures)

Operating rules

- Maintain a todo list for tasks with more than 3 concrete steps.
- Prefer subagents over stuffing more instructions into one prompt.
- Prefer built-in `Explore` for broad search and `repo-librarian` for repo-aware summaries.
- Prefer built-in `/batch` when the work splits into many independent units in a git repo.
- Prefer `test-commander` before broad test runs.
- Use `oracle` after 2+ failed fix attempts or for complex architecture decisions.
- Use `critic` to verify plans are executable before starting large implementations.
- Use `atlas` when coordinating 3+ specialist agents on a single plan.
- If MCP is unavailable, fall back to native tools and note the gap instead of blocking.
- Update task notes and handoffs when context would otherwise be lost.
- Report what verification ran, what did not run, and why.
