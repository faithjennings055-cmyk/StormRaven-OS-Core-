#!/usr/bin/env bash
# =============================================================================
# StormRaven OS — Repository Hygiene Gate
# =============================================================================
# Fails the build when the tree carries content that cannot work for anyone who
# clones it. Currently checks dangling symlinks.
#
# Why: 25 absolute symlinks into /usr/share/live/build/hooks/ were committed on
# 2026-10-07. They only resolve on a machine with live-build installed, they are
# not referenced by any build script, and they break every tool that walks the
# tree — including the GitHub Pages/Jekyll deploy, which has been red since.
# A dangling symlink is always a defect: git records the link, never the target.
#
# Usage: hygiene-gate.sh [repo-root]
set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

fail=0

echo "==> dangling symlinks"
while IFS= read -r link; do
  [ -n "$link" ] || continue
  printf '  [FAIL] %s -> %s\n' "$link" "$(readlink "$link")"
  fail=1
done < <(find . -path ./.git -prune -o -xtype l -print 2>/dev/null)

if [ "$fail" -eq 1 ]; then
  echo "" >&2
  echo "[FAIL] repository contains dangling symlinks; a clone cannot resolve them." >&2
  echo "       Replace with real files, or delete if unused." >&2
  exit 1
fi

echo "[PASS] no dangling symlinks"

echo "==> forbidden retired tokens (#114: moov)"
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  printf '  [FAIL] retired token in %s\n' "$hit"
  fail=1
done < <(grep -ril "moov" . --exclude-dir=.git --exclude="hygiene-gate.sh" --exclude="COMPENDIUM_ACCURACY_AUDIT.md" 2>/dev/null || true)

if [ "$fail" -eq 1 ]; then
  echo "[FAIL] repository contains retired Moov references (#114)." >&2
  exit 1
fi
echo "[PASS] no retired Moov references"
