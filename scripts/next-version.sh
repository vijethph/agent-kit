#!/usr/bin/env bash
# Computes the next version from git history.
# Outputs KEY=VALUE lines suitable for $GITHUB_OUTPUT.
#
# Usage: next-version.sh [--mode auto|major|minor|patch] [--channel rc|ga]
set -euo pipefail

MODE="auto"
CHANNEL="rc"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)    MODE="$2"; shift 2 ;;
    --channel) CHANNEL="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Latest GA tag (pre-releases excluded by the match pattern + sort).
LAST_GA=$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' \
          | grep -Ev '\-' \
          | sort -V | tail -n1 || true)
LAST_GA="${LAST_GA:-v0.0.0}"
BASE="${LAST_GA#v}"
IFS='.' read -r MAJOR MINOR PATCH <<< "$BASE"

# Commits since the last GA tag.
if git rev-parse "$LAST_GA" >/dev/null 2>&1; then
  RANGE="${LAST_GA}..HEAD"
else
  RANGE="HEAD"
fi
SUBJECTS=$(git log --format='%s' "$RANGE")
BODIES=$(git log --format='%b' "$RANGE")

HAS_BREAKING=false
HAS_FEAT=false
HAS_FIX=false
grep -qE '^[a-z]+(\([^)]*\))?!:' <<<"$SUBJECTS" && HAS_BREAKING=true
grep -qE '^BREAKING[ -]CHANGE:' <<<"$BODIES"    && HAS_BREAKING=true
grep -qE '^feat(\([^)]*\))?!?:' <<<"$SUBJECTS"   && HAS_FEAT=true
grep -qE '^(fix|perf|refactor|revert)(\([^)]*\))?!?:' <<<"$SUBJECTS" && HAS_FIX=true

case "$MODE" in
  major) BUMP=major ;;
  minor) BUMP=minor ;;
  patch) BUMP=patch ;;
  auto)
    if $HAS_BREAKING; then
      # Policy: majors are cut manually. Flag loudly, bump minor.
      echo "::warning::Breaking change detected since ${LAST_GA}. Auto path will bump MINOR; cut the major via release-manual.yml."
      BUMP=minor
    elif $HAS_FEAT; then BUMP=minor
    elif $HAS_FIX;  then BUMP=patch
    else                 BUMP=patch
    fi ;;
esac

case "$BUMP" in
  major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR+1)); PATCH=0 ;;
  patch) PATCH=$((PATCH+1)) ;;
esac
TARGET="${MAJOR}.${MINOR}.${PATCH}"

if [[ "$CHANNEL" == "rc" ]]; then
  # Next rc number for this target version.
  N=$(git tag --list "v${TARGET}-rc.*" | sed -E 's/.*-rc\.([0-9]+)$/\1/' | sort -n | tail -n1)
  N=$(( ${N:-0} + 1 ))
  VERSION="${TARGET}-rc.${N}"
else
  VERSION="${TARGET}"
fi

{
  echo "last-ga=${LAST_GA}"
  echo "bump=${BUMP}"
  echo "version=${VERSION}"
  echo "tag=v${VERSION}"
  echo "target=${TARGET}"
  echo "breaking=${HAS_BREAKING}"
} | tee -a "${GITHUB_OUTPUT:-/dev/stdout}"
