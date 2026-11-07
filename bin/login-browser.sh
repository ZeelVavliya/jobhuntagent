#!/usr/bin/env bash
# Opens the loop's own Chromium profile on the Pi's virtual screen so you can sign in once to
# LinkedIn, Seek and any employer portal. Watch and type at http://<pi-ip>:6080/vnc.html
# Close the browser window when done. Usage: docker compose exec hunt bin/login-browser.sh [extra URLs]
set -euo pipefail
exec 9>/tmp/jobhunt.lock
flock -n 9 || { echo "A loop run is active right now; try again when it finishes."; exit 1; }
touch /tmp/login-browser.active
trap 'rm -f /tmp/login-browser.active' EXIT
MCP_DIR="$(npm root -g)/@playwright/mcp"
node - "$MCP_DIR" "$@" <<'JS'
const { createRequire } = require('module');
const req = createRequire(process.argv[2] + '/package.json');
let pw; try { pw = req('playwright'); } catch { pw = req('playwright-core'); }
const extra = process.argv.slice(3);
(async () => {
  const ctx = await pw.chromium.launchPersistentContext(process.env.HOME + '/browser-profile', { headless: false, viewport: null });
  const urls = ['https://www.linkedin.com/login', 'https://www.seek.com.au/', ...extra];
  const first = ctx.pages()[0] || await ctx.newPage();
  await first.goto(urls[0]);
  for (const u of urls.slice(1)) { const p = await ctx.newPage(); await p.goto(u).catch(() => {}); }
  console.log('Browser open on the Pi screen: http://<pi-ip>:6080/vnc.html  - sign in, then close the browser window.');
  await new Promise((r) => ctx.on('close', r));
  console.log('Saved. The loop will use these sessions.');
})().catch((e) => { console.error(e.message); process.exit(1); });
JS
