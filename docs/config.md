# omo Configuration System

omo uses a project-level configuration file at `.omo/config.json` to customize agent model routing, execution parameters, and feature flags.

## Quick Start

```bash
# Generate default config
bash scripts/init-config.sh

# Validate config
bash scripts/validate-config.sh

# Preview model changes
bash scripts/apply-config.sh --dry-run

# Apply model changes to agent frontmatter
bash scripts/apply-config.sh
```

## Config File Location

- Path: `.omo/config.json` (project root)
- Format: Plain JSON (not JSONC)
- Committable: Yes — share config across the team

The `.omo/` directory is separate from `.claude/state/` which holds runtime state.

## Schema

```json
{
  "version": "1",
  "categories": {
    "fast-search":    { "model": "haiku" },
    "verification":   { "model": "sonnet" },
    "implementation": { "model": "sonnet" },
    "planning":       { "model": "sonnet" },
    "deep-reasoning": { "model": "opus" },
    "research":       { "model": "sonnet" },
    "media":          { "model": "sonnet" }
  },
  "ralph-loop": {
    "max_iterations": 100,
    "oracle_default": false
  },
  "spawn": {
    "max_concurrent_agents": 5
  },
  "boulder": {
    "enabled": true,
    "max_attempts": 5,
    "auto_resume": true
  },
  "teams": {
    "enabled": true,
    "max_teammates": 8,
    "auto_escalation": true,
    "notify_on_completion": true
  },
  "evolve": {
    "max_discovery_agents": 6,
    "auto_plan": true,
    "include_memory": true
  },
  "disabled_skills": []
}
```

### version

Schema version. Currently `"1"`.

### categories

Maps agent categories to models. Each agent belongs to exactly one category. Changing a category model affects all agents in that category when `apply-config.sh` runs.

| Category | Default Model | Agents |
|---|---|---|
| `fast-search` | haiku | repo-librarian, deepsearch, memory-keeper |
| `verification` | sonnet | test-commander, security-auditor, perf-analyst |
| `implementation` | sonnet | build-integrator, test-generator, migration-specialist, docs-keeper |
| `planning` | sonnet | planner-sisyphus, atlas, critic-lite, oracle-lite |
| `deep-reasoning` | opus | oracle, critic, build-integrator-heavy |
| `research` | sonnet | repo-librarian-deep, bug-hunter |
| `media` | sonnet | vision |

Valid models: `haiku`, `sonnet`, `opus`.

### ralph-loop

| Field | Type | Default | Description |
|---|---|---|---|
| `max_iterations` | integer | 100 | Maximum loop iterations before force-stop |
| `oracle_default` | boolean | false | Enable Oracle verification by default |

### spawn

| Field | Type | Default | Description |
|---|---|---|---|
| `max_concurrent_agents` | integer | 5 | Maximum parallel agents (1-20) |

### boulder

| Field | Type | Default | Description |
|---|---|---|---|
| `enabled` | boolean | true | Enable Boulder persistent task tracking |
| `max_attempts` | integer | 5 | Maximum attempts before Boulder gives up |
| `auto_resume` | boolean | true | Automatically nudge task resume on session start and idle |

Boulder provides cross-session task persistence. When enabled, tasks initialized with `boulder-init.sh` survive session restarts and are automatically restored via SessionStart and Notification hooks.

### teams

| Field | Type | Default | Description |
|---|---|---|---|
| `enabled` | boolean | true | Enable agent-team coordination features |
| `max_teammates` | integer | 8 | Maximum teammates per team (1-20) |
| `auto_escalation` | boolean | true | Auto-escalate to oracle after repeated subagent failures |
| `notify_on_completion` | boolean | true | Send OS notification when team tasks complete |

Teams enables multi-agent coordination via Claude Code's TeamCreate/SendMessage API. When enabled, Atlas and Spawn skills use persistent teams with shared task lists instead of fire-and-forget subagents.

### evolve

| Field | Type | Default | Description |
|---|---|---|---|
| `max_discovery_agents` | integer | 6 | Parallel discovery agents (1-6) |
| `auto_plan` | boolean | true | Auto-generate sprint plan after synthesis |
| `include_memory` | boolean | true | Include memory-keeper in discovery phase |

The evolve skill (`#ev`) runs an automated self-improvement pipeline that collects project metrics, dispatches up to 6 analysis agents in parallel, synthesizes findings into an IMPACT x EFFORT matrix, generates a validated sprint plan, and saves the report to `.claude/state/improvements/`.

### disabled_skills

Array of skill names to disable. Example: `["retro", "dep-audit"]`.

## Scripts

### read-config.sh

Read a single config value with dot-notation path and optional default.

```bash
bash scripts/read-config.sh categories.fast-search.model haiku
bash scripts/read-config.sh ralph-loop.max_iterations 100
bash scripts/read-config.sh spawn.max_concurrent_agents 5
```

### validate-config.sh

Validate config file structure and values. Exits 0 on pass, 1 on fail. Prints warnings for model hierarchy issues.

```bash
bash scripts/validate-config.sh
```

### init-config.sh

Generate default config file. Use `--force` to overwrite existing.

```bash
bash scripts/init-config.sh
bash scripts/init-config.sh --force
```

### apply-config.sh

Apply category model assignments to agent frontmatter. Use `--dry-run` to preview.

```bash
bash scripts/apply-config.sh --dry-run
bash scripts/apply-config.sh
```

### list-agents-by-category.sh

List agents grouped by category, or filter to a specific category.

```bash
bash scripts/list-agents-by-category.sh
bash scripts/list-agents-by-category.sh planning
```

## How Model Routing Works

Agent models are set in frontmatter at define-time, not at runtime. The workflow is:

1. Edit `.omo/config.json` to change category models
2. Run `bash scripts/apply-config.sh` to rewrite agent frontmatter
3. Run `/reload-plugins` to pick up changes

This means model changes require an explicit apply step. There is no dynamic runtime override.

## Model Hierarchy Warning

The validate script warns if `deep-reasoning` uses a model ranked lower than `planning`. The hierarchy is: haiku < sonnet < opus. This matters because escalation workflows (e.g., oracle after failed attempts) expect deep-reasoning agents to use more capable models.

## Dependencies

- **jq** (recommended): Used for JSON parsing. Install via `brew install jq` or your package manager.
- **python3** (fallback): Used when jq is not available.
- If neither is available, scripts fall back to defaults and print a warning.
