---
description: Daily digest of the job hunt as a Gmail draft to Zeel (never sent)
---

# /digest

Unattended run. Build one email and save it with `mcp__Gmail__create_draft`, addressed to zeelvavliya@gmail.com,
subject `Job hunt digest - <date>`. Then label it `JobHunt/Digest`. Never send it.

Body, plain text, short:
1. **Waiting for your OK** - every `## Waiting` row in `review-queue.md`: #, company, role, score, channel,
   the two best "why it fits" points and the main gap from the career-ops report, and the ⚠/🔒 note.
   End with: "Reply in the desktop app: approve 3,5,7 - or tick [x] in review-queue.md."
2. **Outreach drafts** - Gmail drafts labelled `JobHunt/Outreach` created in the last 24h
   (`mcp__Gmail__search_threads` is not for drafts; use `mcp__Gmail__list_drafts`) plus any `career-ops/output/outreach-*.md` LinkedIn notes.
3. **Employer replies** - threads from the last 24h that look like interview invites, assessments or rejections
   (`mcp__Gmail__search_threads` with `newer_than:1d` and words like interview, assessment, unfortunately, application).
   List them only; do not change the tracker from here.
4. **Totals** - `cd career-ops && node stats.mjs` summary line, and the last 3 lines of `logs/runs.log`.

Finish with one line in `logs/runs.log`: `<ISO time> digest | waiting <n> | drafts <n> | replies <n>`.
