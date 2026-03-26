---
name: mcp-doctor
description: "Check whether expected MCP config exists, whether placeholders remain, and what native fallbacks to use. Activate when #mcp appears anywhere in the user message."
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash
---

Diagnose MCP availability.

1. Check the current workspace for `.mcp.json`.
2. If an example MCP config is available in this plugin, compare against it.
3. Summarize:
   - configured servers
   - placeholder or missing entries
   - which workflows can still proceed with native Claude Code tools
   - which workflows remain blocked without MCP
