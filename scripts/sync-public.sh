#!/usr/bin/env bash
# Brings the public repository up to date with this (private) checkout, through a pull request.
#
#   scripts/sync-public.sh <clone-of-the-public-repo> ["commit message"]
#
# The tree is built by scripts/export-public.sh (allow list and privacy checks), copied over the
# clone with rsync --delete (the clone's .git is untouched), and committed on a new branch
# `sync/<timestamp>`. Nothing is pushed: the script prints the commands to do it.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="$(pwd)"

[ $# -ge 1 ] || { echo "usage: scripts/sync-public.sh <clone-of-the-public-repo> [message]" >&2; exit 2; }
CLONE="$(cd "$1" && pwd)"
MESSAGE="${2:-sync: update from the private tree}"

git -C "$CLONE" rev-parse --git-dir >/dev/null 2>&1 || { echo "error: $CLONE is not a git clone" >&2; exit 1; }
git -C "$CLONE" remote get-url origin | grep -q "Mgt-A/stretchu\(\.git\)\?$" \
  || { echo "error: origin of $CLONE is not Mgt-A/stretchu" >&2; exit 1; }
[ -z "$(git -C "$CLONE" status --porcelain)" ] || { echo "error: $CLONE has uncommitted changes" >&2; exit 1; }

git -C "$CLONE" fetch -q origin main
git -C "$CLONE" checkout -q -B "sync/$(date +%Y%m%d-%H%M%S)" origin/main

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
scripts/export-public.sh "$TMP/export"

rsync -a --delete --exclude '.git' "$TMP/export/" "$CLONE/"
git -C "$CLONE" add -A
if [ -z "$(git -C "$CLONE" status --porcelain)" ]; then
  echo "public repository already up to date."; exit 0
fi
git -C "$CLONE" status --short
git -C "$CLONE" commit -q -m "$MESSAGE"

BRANCH="$(git -C "$CLONE" branch --show-current)"
echo
echo "committed on $BRANCH. To publish:"
echo "  git -C $CLONE push -u origin $BRANCH && gh pr create --repo Mgt-A/stretchu --head $BRANCH"
