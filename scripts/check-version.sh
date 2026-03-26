#!/usr/bin/env bash
# Check version consistency across plugin.json and marketplace.json
# plugin.json is the single source of truth.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "${script_dir}/.." && pwd)

plugin_json="${repo_root}/.claude-plugin/plugin.json"
marketplace_json="${repo_root}/.claude-plugin/marketplace.json"

errors=0

# Extract version from plugin.json (single source of truth)
if command -v jq >/dev/null 2>&1; then
  plugin_version=$(jq -r '.version' "${plugin_json}")
else
  plugin_version=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "${plugin_json}" | head -1 | cut -d'"' -f4)
fi

echo "plugin.json version: ${plugin_version}"

if [ ! -f "${marketplace_json}" ]; then
  echo "WARN: marketplace.json not found"
  exit 0
fi

# Check marketplace.json versions
if command -v jq >/dev/null 2>&1; then
  mp_meta_version=$(jq -r '.metadata.version' "${marketplace_json}")
  mp_plugin_version=$(jq -r '.plugins[0].version' "${marketplace_json}")
else
  mp_meta_version=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "${marketplace_json}" | head -1 | cut -d'"' -f4)
  mp_plugin_version=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "${marketplace_json}" | tail -1 | cut -d'"' -f4)
fi

echo "marketplace.json metadata.version: ${mp_meta_version}"
echo "marketplace.json plugins[0].version: ${mp_plugin_version}"

if [ "${plugin_version}" != "${mp_meta_version}" ]; then
  echo "FAIL: marketplace.json metadata.version (${mp_meta_version}) != plugin.json (${plugin_version})"
  errors=$((errors + 1))
fi

if [ "${plugin_version}" != "${mp_plugin_version}" ]; then
  echo "FAIL: marketplace.json plugins[0].version (${mp_plugin_version}) != plugin.json (${plugin_version})"
  errors=$((errors + 1))
fi

if [ "${errors}" -eq 0 ]; then
  echo "PASS: All versions consistent at ${plugin_version}"
else
  echo "FAIL: ${errors} version mismatch(es) found"
  exit 1
fi
