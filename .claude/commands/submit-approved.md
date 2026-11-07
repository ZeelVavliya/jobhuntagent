---
description: Submit only the applications Zeel ticked in review-queue.md, then update the tracker
---

# /submit-approved

Unattended run. Follow `CLAUDE.md`. This is the **only** command allowed to click a final Submit button,
and only for rows ticked `[x]` under `## Waiting` in `review-queue.md`. If no row is ticked, log
`submit-approved | nothing approved` and stop.

The conversation may also contain Zeel's reply "approve 3,5,7" (tracker numbers): treat those rows as ticked
and tick them in the file first.

For each ticked row, one tab at a time:
1. Open the apply URL in a new tab. Sign in with Chrome's saved password if asked.
2. Check identity: the company and role on the page must match the row and its career-ops report.
   If not, leave the row unticked, add the note `identity mismatch`, and move on.
3. If the pre-filled answers were lost (session expired), fill them again from
   `cd career-ops && node application-answers.mjs --report <report> --read`, the same way `/hunt-cycle` step 5 does.
   If a ⚠ question is still unanswered, do not submit; leave the note.
4. Click the final Submit button once. Wait for the confirmation page or email. Take the confirmation text
   (or the reference number) as evidence.
5. Record it:
   ```bash
   cd career-ops && node set-status.mjs <tracker#> Applied --note "via <channel>; confirmation: <ref or text>"
   cd career-ops && node application-answers.mjs --report <report> --input <answers.json> --state submitted
   ```
6. Move the row from `## Waiting` to `## Done` with `Applied` and today's date. Close the tab.

Then mark unticked `## Waiting` rows whose pre-filled date is more than 7 days old as `expired-unreviewed`
(move them to `## Done`; do not change the tracker).

Finish with one line in `logs/runs.log`, printed as the final output:
`<ISO time> submit-approved | submitted <n> | skipped <n> (<reasons>) | expired <n>`
