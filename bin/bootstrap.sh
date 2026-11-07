#!/usr/bin/env bash
# Idempotent container start-up checks for /work. Safe to run any time.
set -uo pipefail
cd /work || exit 1
mkdir -p logs
for d in career-ops ai-job-search; do
  [ -d "$d" ] || echo "bootstrap: $d/ is missing in /work (copy the whole job-hunt folder to the Pi)"
done
# career-ops node_modules may have been copied from Windows: reinstall once for this platform.
marker="career-ops/node_modules/.installed-$(uname -m)"
if [ -d career-ops ] && [ ! -f "$marker" ]; then
  echo "bootstrap: installing career-ops dependencies for $(uname -m)"
  # On Windows node_modules is a Docker volume (a mount point npm ci cannot delete), so use npm install there.
  if mountpoint -q career-ops/node_modules 2>/dev/null; then npm_cmd="npm install"; else npm_cmd="npm ci"; fi
  (cd career-ops && $npm_cmd --no-audit --no-fund >/dev/null 2>&1) && touch "$marker" || echo "bootstrap: $npm_cmd failed"
fi
[ -f career-ops/.env ] || touch career-ops/.env
grep -q '^CAREER_OPS_CLI=' career-ops/.env || echo 'CAREER_OPS_CLI=claude' >> career-ops/.env
mkdir -p "$HOME/browser-profile"
if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ ! -f "$HOME/.claude/.credentials.json" ]; then
  echo "bootstrap: Claude is not logged in yet (Windows: .\\jobhunt login-claude, Pi: docker compose run --rm hunt claude, then /login)"
fi
exit 0
