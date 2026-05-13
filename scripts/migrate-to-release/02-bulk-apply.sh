#!/bin/bash
# bulk-apply-release.sh
# Add .github/workflows/release.yml and topic:metanorma-release to all eligible repos.
#
# Usage:
#   ./bulk-apply-release.sh              # dry run
#   ./bulk-apply-release.sh --apply      # make changes
#   ./bulk-apply-release.sh --apply cc-standard-doc cc-vobject-integrity  # specific repos
#
set -euo pipefail

DRY_RUN=true
REPOS=()
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for arg in "$@"; do
  case "$arg" in
    --apply) DRY_RUN=false ;;
    --help|-h)
      echo "Usage: $0 [--apply] [repo1 repo2 ...]"
      echo "  --apply   Create files and set topics (default is dry-run)"
      exit 0
      ;;
    *) REPOS+=("$arg") ;;
  esac
done

WORKFLOW_FILE=".github/workflows/release.yml"
WORKFLOW_BASE64=$(base64 < "$SCRIPT_DIR/01-release-workflow.yml" | tr -d '\n')

# Discover eligible repos if none specified
if [ ${#REPOS[@]} -eq 0 ]; then
  echo "Discovering repos with metanorma.yml..."
  while IFS= read -r repo; do
    has_mn=$(gh api "repos/CalConnect/$repo/contents/metanorma.yml" \
      --jq '.name' 2>/dev/null || true)
    if [ "$has_mn" = "metanorma.yml" ]; then
      REPOS+=("$repo")
    fi
  done < <(gh api "orgs/CalConnect/repos?per_page=100&type=public" \
    --jq '.[] | select(.name | startswith("cc-")) | .name' 2>/dev/null)
fi

echo "Found ${#REPOS[@]} eligible repos"
echo ""

SUCCESS=0; SKIP=0; FAIL=0

for repo in "${REPOS[@]}"; do
  echo -n "[$repo] "

  # Skip if release.yml already exists
  existing=$(gh api "repos/CalConnect/$repo/contents/$WORKFLOW_FILE" \
    --jq '.sha' 2>/dev/null || true)
  if [ -n "$existing" ]; then
    echo "SKIP (release.yml exists)"
    SKIP=$((SKIP + 1))
    continue
  fi

  if [ "$DRY_RUN" = true ]; then
    echo "WOULD ADD release.yml + topic"
    SUCCESS=$((SUCCESS + 1))
    continue
  fi

  # Get current topics so we don't overwrite them
  current_topics=$(gh api "repos/CalConnect/$repo/topics" \
    --jq '.names' 2>/dev/null || echo '[]')
  merged=$(echo "$current_topics" | jq '. + ["metanorma-release"] | unique')

  # Create workflow file
  default_branch=$(gh api "repos/CalConnect/$repo" --jq '.default_branch')
  gh api "repos/CalConnect/$repo/contents/$WORKFLOW_FILE" \
    -X PUT \
    --field message="ci: add per-document release workflow (actions-mn/release)" \
    --field content="$WORKFLOW_BASE64" \
    --field branch="$default_branch" \
    --jq '.content.sha' > /dev/null 2>&1 || {
    echo "FAIL (could not create workflow)"
    FAIL=$((FAIL + 1))
    continue
  }

  # Set topics (preserving existing)
  gh api "repos/CalConnect/$repo/topics" \
    -X PUT \
    --argjson names "$merged" \
    --input <(echo "{\"names\": $merged}") \
    > /dev/null 2>&1 || true

  echo "OK"
  SUCCESS=$((SUCCESS + 1))
done

echo ""
echo "Done: $SUCCESS added, $SKIP skipped, $FAIL failed"
[ "$DRY_RUN" = true ] && echo "(dry-run — use --apply to make changes)"
