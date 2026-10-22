#!/bin/bash
# Deploy JB Tattoos to SiteGround (jayb.tattoo).
#
#   ./deploy.sh          dry run: lists what would change, touches nothing
#   ./deploy.sh --live   uploads it
#
# Only what is committed in git goes live, so half-finished edits never ship.
# Needs the "jbtattoos-sg" host in ~/.ssh/config (SiteGround deploy key).
set -euo pipefail

HOST="jbtattoos-sg"
REMOTE="www/jayb.tattoo/public_html/"
cd "$(dirname "$0")"

if [ -n "$(git status --porcelain)" ]; then
  echo "✋ Uncommitted changes — commit them first (only committed code is deployed):"
  git status --short
  exit 1
fi

BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
git archive HEAD | tar -x -C "$BUILD"

# Never upload repo tooling or docs.
RSYNC_OPTS=(-rlptz --delete
  --exclude='.git*' --exclude='.impeccable/' --exclude='.vercel/'
  --exclude='deploy.sh' --exclude='set-domain.sh' --exclude='*.md'
  --filter='P .well-known/'    # SiteGround's SSL verification files
  --filter='P php_errorlog')   # server-written error logs

echo "Deploying $(git log -1 --format='%h %s') → $HOST:$REMOTE"
if [ "${1:-}" = "--live" ]; then
  rsync "${RSYNC_OPTS[@]}" --itemize-changes "$BUILD/" "$HOST:$REMOTE"
  echo "✅ Live. Commit: $(git rev-parse --short HEAD)"
else
  rsync "${RSYNC_OPTS[@]}" --dry-run --itemize-changes "$BUILD/" "$HOST:$REMOTE"
  echo "— dry run only. Run ./deploy.sh --live to upload. —"
fi
