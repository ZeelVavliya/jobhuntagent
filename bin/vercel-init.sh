#!/usr/bin/env bash
# One-time: create and link the Vercel project, set its secrets, first deploy.
# Needs VERCEL_TOKEN, TRACKER_PASSWORD and PI_SYNC_TOKEN in .env.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${VERCEL_TOKEN:?set VERCEL_TOKEN in .env}" "${TRACKER_PASSWORD:?set TRACKER_PASSWORD in .env}" "${PI_SYNC_TOKEN:?set PI_SYNC_TOKEN in .env}"
PROJECT="${VERCEL_PROJECT_NAME:-zeel-jobhunt-tracker}"
node "$ROOT/tracker/build.mjs" >/dev/null
cd "$ROOT/tracker/site"
vercel project add "$PROJECT" --token "$VERCEL_TOKEN" 2>/dev/null || echo "project $PROJECT exists, linking it"
vercel link --yes --project "$PROJECT" --token "$VERCEL_TOKEN"
for name in TRACKER_PASSWORD PI_SYNC_TOKEN; do
  vercel env rm "$name" production --yes --token "$VERCEL_TOKEN" >/dev/null 2>&1 || true
  printf '%s' "${!name}" | vercel env add "$name" production --token "$VERCEL_TOKEN"
done
url=$(vercel deploy --prod --yes --token "$VERCEL_TOKEN")
cat <<MSG

Deployed: $url
Next, once:
  1. In the Vercel dashboard open project "$PROJECT" -> Storage -> Create -> Blob,
     and connect it to the project (this adds BLOB_READ_WRITE_TOKEN; Approve buttons need it).
  2. Note the project's production domain (Settings -> Domains, e.g. https://$PROJECT.vercel.app)
     and put it in .env as TRACKER_URL=...
  3. Restart:  docker compose up -d
MSG
