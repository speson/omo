#!/usr/bin/env bash
# List agents grouped by category (reads frontmatter from agents/*.md)
# Usage: list-agents-by-category.sh [category]
set -eu

filter_category="${1:-}"

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/.." && pwd)
agents_dir="${repo_root}/agents"

# ─── Collect agent data ───────────────────────────────────────────────────────
# Build sorted list of "category model agent-name" entries
entries=""

for agent_file in "${agents_dir}"/*.md; do
  [ -f "${agent_file}" ] || continue
  agent_name=$(basename "${agent_file}" .md)

  category=$(grep '^category:' "${agent_file}" 2>/dev/null | head -1 | sed 's/^category:[[:space:]]*//' || true)
  [ -z "${category}" ] && continue

  model=$(grep '^model:' "${agent_file}" 2>/dev/null | head -1 | sed 's/^model:[[:space:]]*//' || true)
  [ -z "${model}" ] && model="unknown"

  if [ -n "${entries}" ]; then
    entries="${entries}
${category} ${model} ${agent_name}"
  else
    entries="${category} ${model} ${agent_name}"
  fi
done

# ─── Filter if category argument given ───────────────────────────────────────
if [ -n "${filter_category}" ]; then
  filtered=""
  while IFS= read -r line; do
    [ -z "${line}" ] && continue
    line_cat="${line%% *}"
    if [ "${line_cat}" = "${filter_category}" ]; then
      if [ -n "${filtered}" ]; then
        filtered="${filtered}
${line}"
      else
        filtered="${line}"
      fi
    fi
  done <<EOF
${entries}
EOF
  if [ -z "${filtered}" ]; then
    echo "No agents in category: ${filter_category}"
    exit 1
  fi
  entries="${filtered}"
fi

# ─── Group and print ──────────────────────────────────────────────────────────
# Collect unique categories in the order we encounter them
seen_cats=""
sorted_entries=$(printf '%s\n' "${entries}" | sort)

while IFS= read -r line; do
  [ -z "${line}" ] && continue
  cat="${line%% *}"

  already_seen=0
  for sc in ${seen_cats}; do
    if [ "${sc}" = "${cat}" ]; then
      already_seen=1
      break
    fi
  done
  [ "${already_seen}" -eq 1 ] && continue

  if [ -n "${seen_cats}" ]; then
    seen_cats="${seen_cats} ${cat}"
  else
    seen_cats="${cat}"
  fi
done <<EOF
${sorted_entries}
EOF

for cat in ${seen_cats}; do
  # Collect model and agent names for this category
  cat_model=""
  agent_list=""

  while IFS= read -r line; do
    [ -z "${line}" ] && continue
    line_cat="${line%% *}"
    [ "${line_cat}" != "${cat}" ] && continue
    rest="${line#* }"
    line_model="${rest%% *}"
    line_agent="${rest#* }"
    [ -z "${cat_model}" ] && cat_model="${line_model}"
    if [ -n "${agent_list}" ]; then
      agent_list="${agent_list}, ${line_agent}"
    else
      agent_list="${line_agent}"
    fi
  done <<EOF
${sorted_entries}
EOF

  echo "${cat} (${cat_model}):"
  echo "  ${agent_list}"
done
