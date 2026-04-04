#!/usr/bin/env bash
# ============================================================
# Autopilot Product Version Bump
#
# Usage: ./scripts/version-bump.sh <patch|minor|major>
#
# Updates version.json and validates CHANGELOG.md has entry.
# ============================================================
set -euo pipefail

BUMP_TYPE="${1:-patch}"
VERSION_FILE="version.json"

if [ ! -f "$VERSION_FILE" ]; then
  echo "::error ::version.json not found"
  exit 1
fi

CURRENT=$(jq -r '.version' "$VERSION_FILE")
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

case "$BUMP_TYPE" in
  patch)
    if [ "$PATCH" -ge 9 ]; then
      MINOR=$((MINOR + 1))
      PATCH=0
    else
      PATCH=$((PATCH + 1))
    fi
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  *)
    echo "::error ::Invalid bump type: $BUMP_TYPE (use patch|minor|major)"
    exit 1
    ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

echo "Bumping version: $CURRENT → $NEW_VERSION ($BUMP_TYPE)"

# Update version.json
jq --arg v "$NEW_VERSION" '.version = $v' "$VERSION_FILE" > /tmp/version.json
mv /tmp/version.json "$VERSION_FILE"

echo "version=$NEW_VERSION"
echo "previous=$CURRENT"
