---
description: For today's qualifying tracker rows - draft recruiter outreach (Gmail drafts only) and pre-fill each application up to the final Submit page
---

# /prefill

Unattended run, called by `bin/run-cycle.sh` with a JSON list of qualifying rows (score >= 4.0, status
Evaluated) as `$ARGUMENTS`: `[{"num","company","role","score","url","report","pdf"}, ...]`.
Follow every hard rule in `CLAUDE.md`. Never ask a question. Never click a final Submit button.
Work from the job-hunt root. Handle at most 5 rows, strictly one after another.

## A. Outreach (drafts only)
For each row:
1. Draft the message with career-ops' own modes:
   `cd career-ops` and follow `modes/contacto.md` to find the recruiter or hiring manager from **public pages only**
   (the job ad, the company site, a public LinkedIn page you can read without signing in), then `modes/email.md`
   for a short outreach email. Facts only from `cv.md`, `config/profile.yml` and the report.
2. If you found a real address on a public page: create a Gmail draft with `mcp__claude_ai_Gmail__create_draft`
   (to = that address, the subject and body you wrote; end the body with the tailored CV file name for Zeel to attach).
   Then try to label it `JobHunt/Outreach`; if labelling fails, carry on.
3. Always also write the text to `career-ops/output/outreach-<num>.md` (first line `To: <address or LinkedIn URL>`),
   so it shows on the tracker website.
4. If the Gmail tools are not available in this session, do step 3 only and count it as a draft.
Never call any send, reply or forward tool.

## B. Pre-fill (Playwright browser, one tab at a time)
Use only the `mcp__playwright__*` browser tools. The browser profile is already signed in to LinkedIn and Seek
(and any employer portal Zeel signed in to through the login browser).

For each row:
1. Open the posting URL in a new tab (`browser_tab_new` / `browser_navigate`). Find where Apply leads:
   - LinkedIn **Easy Apply** -> channel `LinkedIn Easy Apply`; LinkedIn **Apply** (external) -> follow it.
   - Seek **Quick apply** -> `Seek Quick Apply`; **Apply on employer site** -> follow it.
   - Anything else -> `cd career-ops && node --input-type=module -e "import {atsVendorOf} from './ats-vendor.mjs'; console.log(atsVendorOf(process.argv[1]))" "<url>"`.
   - "Email your CV to ..." -> Gmail draft to that address with the career-ops cover letter text; channel `Email`.
   - Signed out of LinkedIn/Seek, or the portal needs a **new account** -> do not sign up. Mark `🔒 needs Zeel: sign in via login browser` and move on.
2. Answers before typing:
   - Greenhouse / Lever / Ashby: `cd career-ops && node prepare-application.mjs --url "<apply url>" --pdf "<pdf path>"`.
   - Every portal: draft free-text answers from the report under career-ops `modes/apply.md` rules (no invented facts).
     Save them: `cd career-ops && node application-answers.mjs --report <report> --input <answers.json> --state filled`.
3. Fill the form: upload the tailored CV PDF (`browser_file_upload`, path from the row), cover letter if there is a field,
   contact/education/work history from `cv.md`.
   - Demographic / diversity questions: "Prefer not to say" unless `config/profile.yml` says otherwise.
   - Work rights: only `config/profile.yml` `location.visa_status`. Work-hour limits while studying, sponsorship
     in future / after the 485, start date, notice period, salary if the form wants a single number outside the
     profile range, "applied before": leave unanswered and mark ⚠ with the exact question text.
4. Stop on the final review page (the page whose button submits the application). Do not click it.
5. Add a row under `## Waiting` in `review-queue.md`:
   `| [ ] | <num> | <company> | <role> | <score> | <channel> | <apply URL> | <pdf file name> | <YYYY-MM-DD HH:MM> | <notes> |`
   Notes: ⚠ + the unanswered question, or 🔒 + the reason (CAPTCHA, SMS/OTP code, assessment, video step, sign-in).
6. Close the tab.

## Finish
Print exactly one final line, nothing after it:
`PREFILL_RESULT {"drafts": <n>, "prefilled": <n>, "warn": <n>, "locked": <n>}`
