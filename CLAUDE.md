# omo Development Manual

Philosophy

omo prioritizes result quality and delivery speed over token efficiency. Spend more tokens to get better, faster outcomes:

- **Parallelize aggressively** — spawn multiple specialists simultaneously rather than running them sequentially. Two agents working in parallel finish faster than one agent doing both tasks.
- **Investigate deeply before acting** — run `deepsearch` + `repo-librarian` in parallel to build context. Understanding the problem thoroughly up front prevents costly rework.
- **Verify from multiple angles** — use `diff-review` (5-perspective parallel review) + `ship-check` + `test-commander` together, not just one.
- **Escalate early** — use `oracle` after the first failed attempt, not the second. Use `critic` for any plan with 3+ steps.
- **Prefer specialists over generalists** — delegate to purpose-built agents (`bug-hunter`, `security-auditor`, `perf-analyst`) rather than doing shallow analysis inline.
- **Redundancy is acceptable** — if two agents examine the same code from different angles and both find no issues, that is higher confidence, not wasted tokens.

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

Configuration

omo uses `.omo/config.json` for project-level configuration. See `docs/config.md` for full documentation.

```bash
bash scripts/init-config.sh          # Generate default config
bash scripts/validate-config.sh      # Validate config
bash scripts/apply-config.sh --dry-run  # Preview model changes
bash scripts/apply-config.sh         # Apply model changes
```

Agent categories

| Category | Default Model | Agents |
|---|---|---|
| `fast-search` | haiku | repo-librarian, deepsearch, memory-keeper |
| `verification` | sonnet | test-commander, security-auditor, perf-analyst |
| `implementation` | sonnet | build-integrator, test-generator, migration-specialist, docs-keeper |
| `planning` | sonnet | planner-sisyphus, atlas, critic-lite, oracle-lite |
| `deep-reasoning` | opus | oracle, critic, build-integrator-heavy |
| `research` | sonnet | repo-librarian-deep, bug-hunter |
| `media` | sonnet | vision |

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

Hooks

omo registers lifecycle hooks via `hooks/hooks.json` (plugin-native). The hooks are auto-registered when the plugin is loaded.

| Hook Event | Trigger | Script | Purpose |
|---|---|---|---|
| `Stop` | Every stop attempt | `ralph-loop-guard.sh` | Block premature stop during Ralph Loop |
| `SessionStart` | Session start/resume | `session-context-hook.sh` | Inject Boulder task context |
| `Notification` | Idle prompt | `idle-resume-hook.sh` | Nudge Boulder task resume |
| `SubagentStop` | Subagent completes | `subagent-stop-hook.sh` | Auto-escalation on low confidence |
| `TeammateIdle` | Teammate goes idle | `teammate-idle-hook.sh` | Suggest pending task assignment |
| `TaskCompleted` | Task marked done | `task-completed-hook.sh` | OS notification + unblock check |
| `PreCompact` | Before compaction | `pre-compact-hook.sh` | Preserve critical state in system message |

For manual hook registration (without plugin install), run `bash scripts/ensure-hooks.sh`.

Boulder (Cross-Session Task Persistence)

Boulder tracks task state across sessions. When a task is initialized with `boulder-init.sh`, it persists in `.claude/state/boulder.json` and is automatically restored on session restart.

| Script | Purpose |
|---|---|
| `boulder-init.sh "goal"` | Initialize a persistent task |
| `boulder-attempt.sh <outcome>` | Record attempt (working/interrupted/failed/completed) |
| `boulder-check.sh` | Check if a task can be resumed (exit 0 = yes) |
| `boulder-complete.sh` | Mark task as completed |
| `boulder-status.sh` | Show human-readable status |

Boulder is integrated into `#ulw`, `#rl`, `#rw`, and `#ho` skills. Configure via `.omo/config.json` boulder section. See `docs/config.md`.

Agent Teams

Atlas and Spawn support multi-agent coordination via Claude Code's TeamCreate/SendMessage API. When `teams.enabled` is true in `.omo/config.json`:

- Atlas creates persistent teams for plans with 3+ tasks, using shared task lists for progress tracking.
- Spawn uses team-based dispatch instead of fire-and-forget background agents.
- `teams.auto_escalation` triggers oracle escalation after repeated subagent failures.
- `teams.notify_on_completion` sends OS notifications when team tasks complete.

Configure via `.omo/config.json` teams section. See `docs/config.md`.

Repo-local state created by the plugin

- Current task pointer: `.claude/state/current-task.txt`
- Active task notes: `.claude/state/tasks/`
- Handoffs: `.claude/state/handoffs/`
- Repo map: `.claude/state/repo-map.md`
- Task history: `.claude/state/task-history.log`
- Briefings: `.claude/state/briefings/`
- Cross-session memory: `.claude/state/memory/` (conventions, decisions, failures)
- Boulder state: `.claude/state/boulder.json`

Operating rules

- Maintain a todo list for tasks with more than 3 concrete steps.
- Prefer subagents over stuffing more instructions into one prompt.
- Parallelize by default: when 2+ independent tasks exist, run them simultaneously via `spawn` or `Task` with `run_in_background=true`.
- Run `deepsearch` + `repo-librarian` in parallel for context gathering before implementation.
- Use `critic` for any plan with 3+ steps. Use `oracle` after the first failed attempt, not the second.
- Use `atlas` when coordinating 3+ specialist agents on a single plan.
- Always run `diff-review` + `ship-check` together for final verification — never skip multi-perspective review.
- Prefer built-in `/batch` when the work splits into many independent units in a git repo.
- If MCP is unavailable, fall back to native tools and note the gap instead of blocking.
- Update task notes and handoffs when context would otherwise be lost.
- Report what verification ran, what did not run, and why.
