#!/usr/bin/env bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "${script_dir}/.." && pwd)

dist_root="${repo_root}/dist/omo-marketplace"
marketplace_root="${dist_root}"
plugin_root="${marketplace_root}/plugins/omo"

rm -rf "${dist_root}"
mkdir -p "${marketplace_root}/.claude-plugin"
mkdir -p "${plugin_root}"

cat > "${marketplace_root}/.claude-plugin/marketplace.json" <<'EOF'
{
  "name": "omo",
  "owner": {
    "name": "MarkNCompany"
  },
  "metadata": {
    "description": "Local marketplace bundle for the omo Claude Code plugin.",
    "version": "0.1.0"
  },
  "plugins": [
    {
      "name": "omo",
      "source": "./plugins/omo",
      "description": "Reusable Claude Code operating workflows for task kickoff, session recovery, repo mapping, debugging, and ship checks.",
      "version": "0.1.0",
      "author": {
        "name": "MarkNCompany"
      }
    }
  ]
}
EOF

copy_path() {
  src="${repo_root}/$1"
  dst="${plugin_root}/$1"

  if [ -d "${src}" ]; then
    mkdir -p "$(dirname "${dst}")"
    cp -R "${src}" "${dst}"
  elif [ -f "${src}" ]; then
    mkdir -p "$(dirname "${dst}")"
    cp "${src}" "${dst}"
  else
    echo "missing source path: ${src}" >&2
    exit 1
  fi
}

copy_path ".claude-plugin"
copy_path "agents"
copy_path "skills"
copy_path "scripts"
copy_path "templates"
copy_path "examples"
copy_path "CLAUDE.md"
copy_path "README.md"

echo "Built marketplace at ${marketplace_root}"
echo "Plugin bundle at ${plugin_root}"
