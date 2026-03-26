#!/usr/bin/env bash
set -eu

workspace_root() {
  if command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
  else
    pwd
  fi
}

repo_root=$(workspace_root)
state_dir="${repo_root}/.claude/state"
current_task_file="${state_dir}/current-task.txt"
handoffs_dir="${state_dir}/handoffs"

echo "repo: ${repo_root}"

if [ -f "${current_task_file}" ] && [ -s "${current_task_file}" ]; then
  current_task=$(head -n 1 "${current_task_file}" | tr -d '\r')
  if [ -n "${current_task}" ] && [ "${current_task}" != "idle" ]; then
    echo "current-task: ${current_task}"
  else
    echo "current-task: none"
  fi
  if [ -f "${current_task}" ] && [ "${current_task}" != "idle" ]; then
    echo "task-preview:"
    sed -n '1,24p' "${current_task}"
  fi
else
  echo "current-task: none"
fi

if command -v git >/dev/null 2>&1 && git -C "${repo_root}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "git-status:"
  git -C "${repo_root}" status --short || true
  echo "git-diff-stat:"
  git -C "${repo_root}" diff --stat || true
fi

if [ -d "${handoffs_dir}" ]; then
  latest_handoff=$(find "${handoffs_dir}" -type f ! -name '.gitkeep' | sort | tail -n 1 || true)
  if [ -n "${latest_handoff}" ] && [ -f "${latest_handoff}" ]; then
    echo "latest-handoff: ${latest_handoff}"
    sed -n '1,24p' "${latest_handoff}"
  fi
fi
