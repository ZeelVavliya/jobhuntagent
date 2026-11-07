#!/usr/bin/env bash
# Rebuild the tracker site and deploy it to Vercel (production).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node "$ROOT/tracker/build.mjs"
if [ -z "${VERCEL_TOKEN:-}" ] || [ ! -f "$ROOT/tracker/site/.vercel/project.json" ]; then
  echo "tracker built locally only (run bin/vercel-init.sh once to link Vercel)"
  exit 0
fi
cd "$ROOT/tracker/site"
vercel deploy --prod --yes --token "$VERCEL_TOKEN" >/dev/null
echo "tracker published"
