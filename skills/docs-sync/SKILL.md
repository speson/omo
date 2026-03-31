---
name: docs-sync
description: "Check if README.md and user guide reflect current project state — philosophy, features, agent models, skill list. Fix any drift. Activate when #sync appears anywhere in the user message."
argument-hint: "[scope-or-empty]"
disable-model-invocation: false
allowed-tools: Read, Edit, MultiEdit, Write, Glob, Grep, Bash, Task
---

Sync documentation with current project state: $ARGUMENTS

Step 1 — Gather current truth:

Read these source-of-truth files in parallel:
- `CLAUDE.md` — philosophy, agent categories, skills, hooks, operating rules
- `.claude-plugin/plugin.json` — version, description
- `scripts/init-config.sh` — default config values (model defaults, feature flags)
- `hooks/hooks.json` — registered hook events
- Scan `skills/*/SKILL.md` for the full skill list (name, shortcut, description)
- Scan `agents/*.md` for agent list (name, model, category)

Step 2 — Diff against docs:

Read and compare:
- `README.md`
- `docs/user-guide.md` (if exists)
- `docs/config.md` (if exists)

For each doc, check:
1. **Philosophy**: Does the doc reflect the current philosophy from CLAUDE.md?
2. **Skill count and list**: Are all skills listed? Any missing or removed?
3. **Agent models**: Do listed models match agent frontmatter? (e.g., haiku vs sonnet)
4. **Agent descriptions**: Do descriptions match current behavior? (e.g., "2+ failures" vs "first failure")
5. **Feature coverage**: Are Boulder, hooks, config system, teams mentioned?
6. **Version**: Does the doc reference the current version?
7. **State directory**: Is the `.claude/state/` listing complete?
8. **Project structure**: Does the tree reflect current directories?

Step 3 — Report drift:

List each discrepancy as:
- `[file:line] WHAT_IS → WHAT_SHOULD_BE`

Categorize as:
- **STALE**: Information that was true but is now outdated
- **MISSING**: Features or sections not documented at all
- **WRONG**: Factually incorrect information

Step 4 — Fix:

1. Apply all fixes to the affected docs.
2. For large missing sections, dispatch `docs-keeper` to draft the content.
3. Preserve the existing document structure and tone — do not rewrite sections that are already correct.

Step 5 — Verify:

After edits, verify:
- No broken markdown links
- Skill count matches actual skill directories
- Agent count matches actual agent files
- Version numbers are consistent

End with:
- Files updated
- Changes made (bulleted)
- Remaining items that need manual review (if any)
