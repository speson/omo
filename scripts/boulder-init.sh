#!/usr/bin/env bash
# Initialize a Boulder persistent task
# Usage: boulder-init.sh "goal" [--task-file=PATH]
set -eu

project_dir="${CLAUDE_PROJECT_DIR:-.}"
state_dir="${project_dir}/.claude/state"
boulder_file="${state_dir}/boulder.json"

if [ $# -lt 1 ] || [ -z "$1" ]; then
  echo "Usage: boulder-init.sh \"goal\" [--task-file=PATH]" >&2
  exit 1
fi

goal="$1"
shift

task_file=""
for arg in "$@"; do
  case "${arg}" in
    --task-file=*) task_file="${arg#--task-file=}" ;;
  esac
done

# Read config for defaults
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/.." && pwd)
max_attempts=5
auto_resume=true

# Config lookup: project dir first, then plugin repo root
config_file=""
if [ -f "${project_dir}/.omo/config.json" ]; then
  config_file="${project_dir}/.omo/config.json"
elif [ -f "${repo_root}/.omo/config.json" ]; then
  config_file="${repo_root}/.omo/config.json"
fi

if [ -n "${config_file}" ]; then
  if command -v jq >/dev/null 2>&1; then
    cfg_max=$(jq -r '.boulder.max_attempts // empty' "${config_file}" 2>/dev/null || true)
    cfg_auto=$(jq -r '.boulder.auto_resume // empty' "${config_file}" 2>/dev/null || true)
    [ -n "${cfg_max}" ] && max_attempts="${cfg_max}"
    [ -n "${cfg_auto}" ] && auto_resume="${cfg_auto}"
  fi
fi

# Generate slug from goal
slug=$(echo "${goal}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9가-힣]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//' | cut -c1-40)
[ -z "${slug}" ] && slug="task"

# Determine task file
if [ -z "${task_file}" ] && [ -f "${state_dir}/current-task.txt" ]; then
  task_file=$(cat "${state_dir}/current-task.txt" 2>/dev/null || true)
fi

mkdir -p "${state_dir}"

now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if command -v jq >/dev/null 2>&1; then
  jq -n \
    --argjson active true \
    --arg task_slug "${slug}" \
    --arg task_file "${task_file}" \
    --arg goal "${goal}" \
    --argjson attempts 0 \
    --argjson max_attempts "${max_attempts}" \
    --argjson consecutive_failures 0 \
    --arg last_outcome "working" \
    --argjson last_failure_reason null \
    --argjson auto_resume "${auto_resume}" \
    --arg created_at "${now}" \
    --arg updated_at "${now}" \
    '{
      active: $active,
      task_slug: $task_slug,
      task_file: $task_file,
      goal: $goal,
      attempts: $attempts,
      max_attempts: $max_attempts,
      consecutive_failures: $consecutive_failures,
      last_outcome: $last_outcome,
      last_failure_reason: $last_failure_reason,
      auto_resume: $auto_resume,
      created_at: $created_at,
      updated_at: $updated_at
    }' > "${boulder_file}"
else
  # JSON-escape the goal
  escaped_goal=$(printf '%s' "${goal}" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g')
  cat > "${boulder_file}" <<BEOF
{
  "active": true,
  "task_slug": "${slug}",
  "task_file": "${task_file}",
  "goal": "${escaped_goal}",
  "attempts": 0,
  "max_attempts": ${max_attempts},
  "consecutive_failures": 0,
  "last_outcome": "working",
  "last_failure_reason": null,
  "auto_resume": ${auto_resume},
  "created_at": "${now}",
  "updated_at": "${now}"
}
BEOF
fi

echo "[Boulder] Initialized: ${slug} (max ${max_attempts} attempts)"
echo "  Goal: ${goal}"
echo "  State: ${boulder_file}"
