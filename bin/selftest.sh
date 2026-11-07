#!/usr/bin/env bash
# Test run on the Pi: checks every part of the loop, then (with --full) runs one real cycle.
# Usage: docker compose exec hunt bin/selftest.sh [--full]
set -uo pipefail
cd /work || exit 1
pass=0; fail=0
ok()  { echo "  ✓ $1"; pass=$((pass+1)); }
bad() { echo "  ✗ $1"; fail=$((fail+1)); }
check() { local name="$1"; shift; if out=$("$@" 2>&1); then ok "$name"; else bad "$name: $(echo "$out" | tail -2 | tr '\n' ' ')"; fi; }

echo "1. Tools"
check "claude $(claude --version 2>/dev/null | head -1)" claude --version
check "node $(node --version)" node --version
check "bun" bun --version
check "python3 + yaml" python3 -c "import yaml"
check "playwright MCP" which mcp-server-playwright
check "vercel CLI" vercel --version
check "career-ops doctor (profile, cv, portals)" bash -c "cd career-ops && node doctor.mjs --json | jq -e '.onboardingNeeded == false' >/dev/null"

echo "2. Claude login"
r=$(timeout 120 claude -p "Reply with the single word READY." --max-turns 1 2>&1)
grep -q READY <<<"$r" && ok "Claude Code answers" || bad "Claude Code: $r (Windows: .\\jobhunt login-claude, Pi: docker compose run --rm hunt claude, then /login)"

echo "3. Gmail connector (drafts)"
r=$(timeout 180 claude -p "Do you have a tool named mcp__claude_ai_Gmail__create_draft available right now? Answer only YES or NO." --max-turns 2 2>&1)
grep -q YES <<<"$r" && ok "claude.ai Gmail connector visible" || bad "Gmail connector not visible to Claude Code here ($r). Outreach still goes to the tracker site."

echo "4. Job sources (dry run, nothing written)"
r=$(cd career-ops && timeout 170 node scan.mjs --dry-run --json --quiet --since 3 2>/dev/null)
added=$(jq -r '.added // empty' <<<"$r" 2>/dev/null)
[ -n "$added" ] && ok "SEEK + Atlassian scan: $added new postings would be added" || bad "career-ops scan failed (see: cd career-ops && node scan.mjs --dry-run)"
r=$(timeout 170 python3 bridge/search_boards.py --dry-run 2>&1)
if jq -e . >/dev/null 2>&1 <<<"$r"; then
  ok "LinkedIn + freehire: found $(jq .found <<<"$r"), would forward $(jq .would_forward <<<"$r")"
  jq -r '.errors[]? | "    ! " + .' <<<"$r"
else bad "search_boards: $(tail -2 <<<"$r")"; fi

echo "5. Browser profile (signed in?)"
r=$(timeout 300 claude -p "Using only the playwright browser tools: open https://www.linkedin.com/feed/ and then https://www.seek.com.au/ in one tab. For each, say whether the page shows you as signed in. Reply exactly: LINKEDIN=<yes|no> SEEK=<yes|no>. Close the tab." \
  --mcp-config /work/.mcp.json --allowedTools mcp__playwright --max-turns 15 2>&1 | tail -3)
echo "    $r"
grep -q "LINKEDIN=yes" <<<"$r" && ok "LinkedIn signed in" || bad "LinkedIn not signed in: login-browser (Windows: .\\jobhunt login-sites, Pi: docker compose exec hunt bash bin/login-browser.sh)"
grep -q "SEEK=yes" <<<"$r" && ok "Seek signed in" || bad "Seek not signed in: login-browser (Windows: .\\jobhunt login-sites, Pi: docker compose exec hunt bash bin/login-browser.sh)"

echo "6. Tracker website"
check "tracker builds" node tracker/build.mjs
if [ -n "${VERCEL_TOKEN:-}" ] && [ -f tracker/site/.vercel/project.json ]; then
  check "tracker deploys to Vercel" bash bin/publish-tracker.sh
  if [ -n "${TRACKER_URL:-}" ]; then
    code=$(curl -s -o /dev/null -w '%{http_code}' "$TRACKER_URL/")
    [ "$code" = 401 ] && ok "tracker asks for a password ($TRACKER_URL)" || bad "tracker returned HTTP $code without a password (expected 401)"
    check "approvals feed reachable" node bin/pull-approvals.mjs
  else bad "TRACKER_URL not set in .env"; fi
else bad "Vercel not linked yet: Windows: .\\jobhunt vercel-init, Pi: docker compose exec hunt bash bin/vercel-init.sh"; fi

echo; echo "Passed $pass, failed $fail."
if [ "${1:-}" = "--full" ]; then
  echo; echo "Running one real hunt cycle (stops before every Submit button)..."
  bash bin/run-cycle.sh
fi
