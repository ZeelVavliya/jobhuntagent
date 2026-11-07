# Job-hunt loop — Windows or Raspberry Pi 5 (Docker) + Vercel tracker

Runs by itself three times a day in Perth time. Each **hunt cycle**:
1. **finds** new roles: SEEK (Perth + all Australia) and Atlassian through career-ops' scanner, LinkedIn
   (2 searches, last 24h) and freehire through `bridge/search_boards.py`;
2. **checks, scores and tailors** each one with career-ops (liveness, A–G score, one-page CV PDF, tracker row);
3. for scores ≥ 4.0: **drafts outreach** (Gmail draft, never sent, plus the text on the tracker) and
   **pre-fills the application** in its own Chromium, stopping at the final Submit button;
4. **publishes the tracker** to Vercel (password protected). You tap **Approve** there; the next
   submit run (08:10, 13:10, 18:10) submits only what you approved.

A digest lands in Gmail drafts at 07:20. Everything except the tracker page stays on the Pi.

## Set up on Windows (Docker Desktop, ~20 min)

Same container, schedule and tracker as the Pi, run by Docker Desktop on this PC. Everything is done with
`.\jobhunt <command>` in PowerShell, from `C:\Zeel Australia\job-hunt`.

1. Install Docker Desktop: `winget install -e --id Docker.DockerDesktop`, restart, open it once and wait for
   "Engine running". In its Settings -> General, tick "Start Docker Desktop when you sign in".
2. `.\jobhunt setup` asks for two passwords (sign-in screen, tracker) and your Vercel token, generates the
   sync token, writes `.env`, builds and starts the container.
3. `.\jobhunt login-claude`: type `/login`, follow the link, then `/exit` (keeps your claude.ai Gmail connector).
4. `.\jobhunt login-sites`: a browser tab opens the loop's screen; sign in to LinkedIn and Seek, then close
   the browser window inside it. Employer portal later: `.\jobhunt login-sites -Url https://<login page>`.
5. `.\jobhunt vercel-init`, do the Blob-store step it prints, paste the tracker URL when asked.
6. `.\jobhunt selftest`, then `.\jobhunt selftest -Full` for one real cycle.
7. `.\jobhunt keep-awake` so the PC does not sleep on mains power. Runs only happen while the PC is on.

Day to day: `.\jobhunt tracker` (open the website), `status`, `logs`, `run cycle|submit|digest`, `stop`, `start`.
The Windows copy of career-ops keeps its own `node_modules`; the container's Linux ones live in a Docker volume.

## Set up on the Pi (once, ~30 min)

1. **Copy this whole `job-hunt` folder** to the Pi (USB or `scp -r`), e.g. to `~/job-hunt`. Install Docker:
   `curl -fsSL https://get.docker.com | sh && sudo usermod -aG docker $USER` (log out and back in).
2. **Fill in `.env`**: `cp .env.example .env`, then set `VNC_PASSWORD`, `VERCEL_TOKEN`
   (vercel.com → Account Settings → Tokens), `TRACKER_PASSWORD`, and `PI_SYNC_TOKEN` (`openssl rand -hex 24`).
3. **Build and start**: `docker compose up -d --build` (first build ~15 min on a Pi 5).
4. **Log in to Claude**: `docker compose run --rm hunt claude`, type `/login`, open the link on your phone or PC,
   paste the code back, then `/exit`. This uses your Claude plan and brings your claude.ai **Gmail connector**
   into the container (keep Gmail connected at claude.ai → Settings → Connectors).
5. **Sign in to LinkedIn and Seek in the loop's browser**: `docker compose exec hunt bash bin/login-browser.sh`,
   then open `http://<pi-ip>:6080/vnc.html` (password = `VNC_PASSWORD`), sign in, close the browser window.
   Add employer portals the same way when a row says `🔒 needs Zeel: sign in`:
   `docker compose exec hunt bash bin/login-browser.sh https://<portal-login-url>`.
6. **Create the tracker**: `docker compose exec hunt bash bin/vercel-init.sh`, then do the two dashboard steps it
   prints (add a Blob store, put the domain in `.env` as `TRACKER_URL`) and `docker compose up -d`.
7. **Test run**: `docker compose exec hunt bash bin/selftest.sh` checks every part. When it passes:
   `docker compose exec hunt bash bin/selftest.sh --full` runs one real cycle while you watch on noVNC.

Logs: `logs/runs.log` (one line per run) and `logs/<date>-<job>.log`. Live: `docker compose logs -f`.
Run a job now: `docker compose exec hunt bash bin/run-cycle.sh` (or `run-submit.sh`, `run-digest.sh`).

## Guardrails
- Final Submit is clicked only by `/submit-approved`, only for rows you approved (`CLAUDE.md` rule 1).
- Gmail send, reply and forward are denied in `.claude/settings.json`; drafts only.
- No invented facts: answers come only from `career-ops/cv.md`, `career-ops/config/profile.yml` and the report.
  Work-hour limits, future sponsorship and start-date questions are left for you (⚠).
- No CAPTCHAs, SMS codes, assessments, new accounts or typed passwords: those rows are flagged 🔒.
- LinkedIn: 2 searches a run. Automated LinkedIn/Seek use is against their terms and can get an account
  restricted; if you see CAPTCHAs, change `deploy/crontab` to fewer runs.
- Caps per run: 15 forwarded from LinkedIn/freehire, 8 evaluated, 5 pre-filled.

## Files
| File | Purpose |
|---|---|
| `docker-compose.yml`, `deploy/` | Container (Dockerfile, entrypoint, `crontab` schedule) — Pi |
| `docker-compose.windows.yml`, `jobhunt.cmd`, `windows/jobhunt.ps1` | Windows (Docker Desktop) version |
| `.env.example` | Secrets template (copy to `.env`) |
| `bin/run-cycle.sh`, `run-submit.sh`, `run-digest.sh` | The scheduled jobs |
| `bin/selftest.sh` | Test run |
| `bin/login-browser.sh` | Sign in to sites in the loop's browser (via noVNC) |
| `bin/vercel-init.sh`, `publish-tracker.sh`, `pull-approvals.mjs` | Tracker deploy and approvals |
| `bridge/search_boards.py` | LinkedIn + freehire search into career-ops' inbox |
| `tracker/` | Tracker website source (built to `tracker/site/`) |
| `.claude/commands/` | `/prefill`, `/submit-approved`, `/digest`, `/hunt-cycle` |
| `.mcp.json` | Playwright MCP browser for Claude Code |
| `CLAUDE.md` | Hard rules and caps |
| `review-queue.md` | Approval queue (the tracker shows it) |
| `bridge/scrape_to_pipeline.py` | Old ai-job-search `/scrape` bridge, no longer used |
