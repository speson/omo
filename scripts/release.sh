#!/usr/bin/env bash
# Release automation for omo plugin
# Usage: ./scripts/release.sh [--dry-run]
#
# Steps:
#   1. Run tests
#   2. Check version consistency
#   3. Build marketplace bundle
#   4. Create git tag
#   5. Push tag (triggers GitHub Release workflow)
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/.." && pwd)
cd "${repo_root}"

dry_run=false
for arg in "$@"; do
  case "${arg}" in
    --dry-run) dry_run=true ;;
  esac
done

# Extract version
if command -v jq >/dev/null 2>&1; then
  version=$(jq -r '.version' .claude-plugin/plugin.json)
else
  version=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' .claude-plugin/plugin.json | head -1 | cut -d'"' -f4)
fi

tag="v${version}"

echo "omo release: ${tag}"
echo "===================="

# Step 1: Run tests
echo ""
echo "Step 1: Running tests..."
if ! bash tests/run-tests.sh; then
  echo "ABORT: Tests failed. Fix issues before releasing."
  exit 1
fi

# Step 2: Version consistency
echo ""
echo "Step 2: Checking version consistency..."
if ! bash scripts/check-version.sh; then
  echo "ABORT: Version mismatch. Run check-version.sh for details."
  exit 1
fi

# Step 3: Build marketplace
echo ""
echo "Step 3: Building marketplace bundle..."
if ! bash scripts/build-marketplace.sh; then
  echo "ABORT: Marketplace build failed."
  exit 1
fi

# Step 4: Check for uncommitted changes
echo ""
echo "Step 4: Checking working tree..."
if [ -n "$(git status --porcelain)" ]; then
  echo "WARN: Uncommitted changes detected. Commit before releasing."
  git status --short
  if [ "${dry_run}" = "false" ]; then
    echo "ABORT: Clean working tree required for release."
    exit 1
  fi
fi

# Step 5: Check if tag already exists
if git tag -l "${tag}" | grep -q "${tag}"; then
  echo "ABORT: Tag ${tag} already exists."
  exit 1
fi

if [ "${dry_run}" = "true" ]; then
  echo ""
  echo "DRY RUN: Would create tag ${tag} and push to origin."
  echo "DRY RUN: All checks passed."
  exit 0
fi

# Step 6: Create and push tag
echo ""
echo "Step 5: Creating tag ${tag}..."
git tag -a "${tag}" -m "Release ${tag}"

echo "Step 6: Pushing tag to origin..."
git push origin "${tag}"

echo ""
echo "Release ${tag} complete!"
echo "GitHub Actions will create the GitHub Release automatically."
