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
INDEXNOW_KEY="83d3b317099449e687adf8ac26f44776"   # must match <key>.txt in the repo root
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
  --exclude='vercel.json'      # old Vercel host just redirects to jayb.tattoo
  --exclude='assets/*.pdf'     # print files (business card, logo art) — not linked on the site
  --filter='P .well-known/'    # SiteGround's SSL verification files
  --filter='P php_errorlog')   # server-written error logs

echo "Deploying $(git log -1 --format='%h %s') → $HOST:$REMOTE"
if [ "${1:-}" = "--live" ]; then
  rsync "${RSYNC_OPTS[@]}" --itemize-changes "$BUILD/" "$HOST:$REMOTE"
  # SiteGround's dynamic cache keeps serving old files until it is flushed.
  ssh "$HOST" 'site-tools-client domain update id=1 flush_cache=1' >/dev/null
  # Tell Bing/Yandex/etc. (IndexNow) the sitemap's pages changed; the key file sits in the repo root.
  URLS=$(grep -o '<loc>https://jayb.tattoo/[^<]*</loc>' sitemap.xml | sed 's#</*loc>##g; s/.*/"&"/' | paste -sd, -)
  curl -s -o /dev/null -w "IndexNow: %{http_code}\n" -H 'Content-Type: application/json' \
    -d "{\"host\":\"jayb.tattoo\",\"key\":\"$INDEXNOW_KEY\",\"urlList\":[$URLS]}" \
    https://api.indexnow.org/indexnow || true
  echo "✅ Live. Commit: $(git rev-parse --short HEAD)"
else
  rsync "${RSYNC_OPTS[@]}" --dry-run --itemize-changes "$BUILD/" "$HOST:$REMOTE"
  echo "— dry run only. Run ./deploy.sh --live to upload. —"
fi
