#!/bin/bash
# Usage: ./set-domain.sh https://jbtattoos.com
# Points canonical, Open Graph, JSON-LD, robots.txt and sitemap.xml at the live domain.
set -e
NEW="${1%/}"
[[ "$NEW" =~ ^https://[a-z0-9.-]+$ ]] || { echo "usage: $0 https://domain.com"; exit 1; }
cd "$(dirname "$0")"
OLD=$(grep -o '<link rel="canonical" href="[^"]*"' index.html | sed 's/.*href="//; s/\/"$//; s/"$//')
[ "$OLD" = "$NEW" ] && { echo "already $NEW"; exit 0; }
sed -i '' "s#$OLD#$NEW#g" index.html robots.txt sitemap.xml
echo "$OLD -> $NEW"; grep -c "$NEW" index.html robots.txt sitemap.xml
