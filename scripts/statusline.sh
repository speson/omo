#!/usr/bin/env bash
set -eu

cwd_name=$(basename "${PWD}")
git_segment=""
task_segment=""

current_task_file=".claude/state/current-task.txt"
if [ -f "${current_task_file}" ] && [ -s "${current_task_file}" ]; then
  current_task=$(head -n 1 "${current_task_file}" | tr -d '\r')
  if [ -n "${current_task}" ] && [ "${current_task}" != "idle" ]; then
    task_segment=" task:$(basename "${current_task}")"
  fi
fi

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git branch --show-current 2>/dev/null || true)
  dirty_count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ -n "${branch}" ]; then
    git_segment=" git:${branch}"
  else
    git_segment=" git:detached"
  fi
  git_segment="${git_segment} dirty:${dirty_count}"
fi

echo "cc:${cwd_name}${git_segment}${task_segment}"
