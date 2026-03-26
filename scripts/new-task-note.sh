#!/usr/bin/env bash
set -eu

if [ "$#" -lt 1 ]; then
  echo "usage: $0 \"task title\"" >&2
  exit 1
fi

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
state_dir="${repo_root}/.claude/state"
tasks_dir="${state_dir}/tasks"
template_file="${plugin_root}/templates/task-note.md"
current_task_file="${state_dir}/current-task.txt"

mkdir -p "${tasks_dir}"

slug=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | tr -s '-' | sed 's/^-//; s/-$//')
if [ -z "${slug}" ]; then
  slug="task"
fi

timestamp=$(date '+%Y%m%d-%H%M%S')
task_file="${tasks_dir}/${timestamp}-${slug}.md"

if [ -f "${template_file}" ]; then
  cp "${template_file}" "${task_file}"
else
  printf '# Task\n\n## Goal\n\n## Assumptions\n\n## Areas\n\n## Verification\n\n## Next actions\n' > "${task_file}"
fi

printf '%s\n' "${task_file}" > "${current_task_file}"
printf '%s\n' "${task_file}"
