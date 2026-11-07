---
description: One unattended job-hunt cycle - search, forward, evaluate, tailor, draft outreach, pre-fill applications, sync tracker
---

# /hunt-cycle

Unattended run. Follow `CLAUDE.md` hard rules. Never ask a question; never click a final Submit.
Work from the job-hunt root. Keep a counter for each step for the closing summary.
If a step fails, note the error, skip what depends on it, and carry on with the rest.

## 1. Search (ai-job-search)
Run the scrape headless inside its own checkout so its CLAUDE.md, skills and settings load:

```bash
cd ai-job-search && claude -p "/scrape Perth, Western Australia and remote Australia. Roles: data scientist, data analyst, software engineer, machine learning engineer - intern, graduate, junior. Portals: linkedin-search (at most 2 queries, posted in the last 24 hours), seek-search, freehire-search. Unattended run: do not ask questions, store results and print the Step 5 summary." --allowedTools "Bash(bun run .agents/skills/*) Bash(python tools/*) Bash(python3 tools/*) Bash(bun --version) Read Write Edit Glob Grep WebFetch WebSearch Agent" --max-turns 60
```

## 2. Forward to career-ops

```bash
python bridge/scrape_to_pipeline.py --limit 15 --min-fit medium
```
Record `forwarded`. If it is 0 and `career-ops/data/pipeline.md` has no `- [ ]` lines, skip to step 6.

## 3. Evaluate, tailor, track (career-ops)

```bash
cd career-ops && claude -p "/career-ops pipeline - unattended run. Process at most 8 pending URLs. Run the liveness sweep first. Generate the tailored CV PDF for every posting scoring 4.0 or higher. Write the tracker rows." --allowedTools "Bash(node *) Bash(npx playwright *) Read Write Edit Glob Grep WebFetch WebSearch" --max-turns 120
```
Then read the new rows: `cd career-ops && node tracker.mjs sync && node tracker.mjs query --status Evaluated --since <today YYYY-MM-DD> --min-score 4 --json`. Keep, for each new row: tracker #, company, role, score, URL, report path, PDF path.
Only rows with score >= 4.0 and status `Evaluated` go on to steps 4 and 5.

## 4. Outreach drafts (Gmail, drafts only)
For each qualifying row:
1. Draft the message with career-ops' own modes, headless:
   ```bash
   cd career-ops && claude -p "Unattended run. For report <report path>: run contacto mode to find the recruiter or hiring manager (public sources only), then email mode to draft a short application/outreach email. Print JSON only: {\"to\": \"address or empty\", \"to_name\": \"\", \"linkedin_url\": \"\", \"subject\": \"\", \"body\": \"\"}. Never send anything." --allowedTools "Bash(node *) Read Glob Grep WebFetch WebSearch" --max-turns 40
   ```
2. If `to` is a real address found on a public page (company site, job ad, LinkedIn): call `mcp__Gmail__create_draft`
   with that subject and body, mention the tailored CV PDF file name at the end of the body for Zeel to attach,
   then add the `JobHunt/Outreach` label to the draft's message.
3. If no address: save the note to `career-ops/output/outreach-<tracker#>.md` with the `linkedin_url`, for Zeel to send as a LinkedIn message.
Never call `send_message`, `reply` or `forward`.

## 5. Pre-fill applications (Claude in Chrome, one tab at a time)
Load the Chrome tools (read the `anthropic-skills:chrome-browser` skill first). For each qualifying row, up to 5, **one after another**:

1. Open the posting URL in a new tab. Find where its Apply button leads and set the channel:
   - LinkedIn page with **Easy Apply** → channel `LinkedIn Easy Apply`.
   - LinkedIn page with **Apply** (external) → follow it; channel = the employer portal.
   - Seek page with **Quick apply** → `Seek Quick Apply`; with **Apply on employer site** → follow it.
   - Anything else → identify the portal: `cd career-ops && node --input-type=module -e "import {atsVendorOf} from './ats-vendor.mjs'; console.log(atsVendorOf(process.argv[1]))" "<url>"`
     (prints greenhouse, lever, ashby, workday, icims, successfactors, … or the hostname for a custom career page; PageUp shows as its hostname).
   - "Email your CV to …" → create a Gmail draft to that address with the career-ops cover letter text; channel `Email`.
2. Get the answers before typing anything:
   - Greenhouse / Lever / Ashby: `cd career-ops && node prepare-application.mjs --url "<apply url>" --pdf "<pdf path>"`.
   - Every portal: draft the free-text answers from the report (career-ops `apply` mode rules: no invented facts, voice-dna if present).
     Save them with `node application-answers.mjs --report <report> --input <answers.json> --state filled`.
3. Fill the form in Chrome:
   - Sign in if Chrome is already signed in or has a saved password. If the portal needs a new account, sign up with
     zeelvavliya@gmail.com and let Chrome suggest and save the password. For the verification email, use
     `mcp__Gmail__search_threads` with `newer_than:1h` and the portal's sender, open the link in the same tab.
   - Upload the tailored CV PDF (and cover letter if there is a field). Fill contact, education, work history from `cv.md`.
   - Demographic / diversity questions: "Prefer not to say" unless `config/profile.yml` says otherwise.
   - Work rights, sponsorship, salary, notice period, "applied before": only from `config/profile.yml`. Missing → stop, ⚠.
4. Stop on the final review page (the page whose button submits the application). Do not click it.
5. Add a row under `## Waiting` in `review-queue.md`:
   `| [ ] | <tracker#> | <company> | <role> | <score> | <channel> | <apply URL> | <pdf file> | <date time> | <notes> |`
   Mark ⚠ with the exact unanswered question, or 🔒 for CAPTCHA / SMS code / assessment / video step.
6. Close the tab.

## 6. Tracker sync

```bash
cd career-ops && node merge-tracker.mjs && node verify-pipeline.mjs --no-hints && node build-dashboard.mjs
```

## 7. Close
Append one line to `logs/runs.log` and print the same line as the final output, nothing after it:
`<ISO time> hunt-cycle | found <n> | forwarded <n> | evaluated <n> | >=4.0 <n> | drafts <n> | prefilled <n> | ⚠ <n> | 🔒 <n> | errors: <short list or none>`
