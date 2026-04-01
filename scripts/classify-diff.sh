#!/usr/bin/env bash
# Classify the current git diff by size
# Usage: classify-diff.sh [diff-target]
#   diff-target: git ref or range (default: staged changes, falls back to HEAD)
# Output line 1: "small" | "medium" | "large"
# Output line 2: total changed lines (additions + deletions)
# Size thresholds:
#   small:  < 20 lines
#   medium: 20-200 lines
#   large:  > 200 lines
set -eu

target="${1:-}"

# Determine diff command based on target and staging state
if [ -n "${target}" ]; then
  line_count=$(git diff --numstat "${target}" 2>/dev/null \
    | awk '{ add += $1; del += $2 } END { print add + del + 0 }')
else
  # Check if there are staged changes
  staged=$(git diff --cached --numstat 2>/dev/null)
  if [ -n "${staged}" ]; then
    line_count=$(printf '%s\n' "${staged}" \
      | awk '{ add += $1; del += $2 } END { print add + del + 0 }')
  else
    # Fall back to HEAD (uncommitted working-tree changes vs last commit)
    line_count=$(git diff HEAD --numstat 2>/dev/null \
      | awk '{ add += $1; del += $2 } END { print add + del + 0 }')
  fi
fi

# Classify
if [ "${line_count}" -lt 20 ]; then
  size="small"
elif [ "${line_count}" -le 200 ]; then
  size="medium"
else
  size="large"
fi

printf '%s\n%s\n' "${size}" "${line_count}"
