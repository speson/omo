#!/usr/bin/env bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
plugin_root=$(CDPATH= cd -- "${script_dir}/.." && pwd)

workspace_root() {
  if command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
  else
    pwd
  fi
}

repo_root=$(workspace_root)
config_file="${repo_root}/.mcp.json"
example_file="${plugin_root}/examples/mcp.json.example"

if [ -f "${config_file}" ]; then
  target_file="${config_file}"
  echo "status: found"
  echo "scope: workspace"
elif [ -f "${example_file}" ]; then
  target_file="${example_file}"
  echo "status: missing-workspace-config"
  echo "scope: example"
else
  echo "status: missing"
  echo "detail: no workspace .mcp.json or plugin example found"
  exit 0
fi

echo "file: ${target_file}"
echo "servers:"
grep -E '^[[:space:]]+"[^"]+": \{$' "${target_file}" | sed 's/[",:{]//g' | sed 's/^ *//' | grep -Ev '^mcpServers *$' || true

if grep -q 'REPLACE_WITH_' "${target_file}"; then
  echo "placeholders: yes"
else
  echo "placeholders: no"
fi
