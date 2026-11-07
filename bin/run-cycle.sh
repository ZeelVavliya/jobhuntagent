#!/usr/bin/env bash
# One unattended hunt cycle: search -> evaluate/tailor -> outreach drafts -> pre-fill -> tracker.
# Scheduled by deploy/crontab. Run by hand: docker compose exec hunt bin/run-cycle.sh
set -uo pipefail
JOB=hunt-cycle
source "$(dirname "$0")/lib.sh"
acquire_lock hunt-cycle || exit 0
errs=()
found=0; forwarded=0; evaluated=0; good=0; drafts=0; prefilled=0; warn=0; locked=0

pending() { grep -c '^- \[ \]' career-ops/data/pipeline.md 2>/dev/null || true; }

# 1a. Seek + Atlassian through career-ops' own scanner (no model tokens)
scan=$(cd career-ops && node scan.mjs --json --quiet --since 3 2>>"$RUNLOG"); rc=$?
[ "$rc" -eq 0 ] || errs+=("scan(rc=$rc)")
n=$(jq -r '.added // 0' <<<"$scan" 2>/dev/null || echo 0); forwarded=$((forwarded + ${n:-0}))
n=$(jq -r '.found // .total_found // 0' <<<"$scan" 2>/dev/null || echo 0); found=$((found + ${n:-0}))

# 1b. LinkedIn (2 queries, last 24h) + freehire, filtered by portals.yml title_filter
sb=$(python3 bridge/search_boards.py --limit 15 2>>"$RUNLOG") || errs+=("search_boards")
echo "$sb" >> "$RUNLOG"
n=$(jq -r '.forwarded // 0' <<<"$sb" 2>/dev/null || echo 0); forwarded=$((forwarded + ${n:-0}))
n=$(jq -r '.found // 0' <<<"$sb" 2>/dev/null || echo 0); found=$((found + ${n:-0}))
while IFS= read -r e; do [ -n "$e" ] && errs+=("${e:0:60}"); done < <(jq -r '.errors[]?' <<<"$sb" 2>/dev/null)

# 2. Evaluate, tailor, track (career-ops pipeline, at most 8)
before=$(node bin/tracker-rows.mjs --count 2>>"$RUNLOG" || echo 0)
if [ "$(pending)" -gt 0 ]; then
  (cd career-ops && run_claude 120 "Bash(node *) Bash(npx playwright *) $FILE_TOOLS WebFetch WebSearch $BROWSER_TOOLS" \
    "/career-ops pipeline - unattended run. Process at most 8 pending URLs. Run the liveness sweep first. Generate the tailored one-page CV PDF for every posting scoring 4.0 or higher. Write the tracker rows. Never ask a question." >/dev/null) \
    || errs+=("pipeline")
fi
(cd career-ops && node merge-tracker.mjs) >> "$RUNLOG" 2>&1 || errs+=("merge")
(cd career-ops && node tracker.mjs sync) >> "$RUNLOG" 2>&1 || true
after=$(node bin/tracker-rows.mjs --count 2>>"$RUNLOG" || echo 0)
evaluated=$(( ${after:-0} - ${before:-0} )); [ "$evaluated" -lt 0 ] && evaluated=0

rows=$(node bin/tracker-rows.mjs --status Evaluated --since "$(date +%F)" --min-score 4 2>>"$RUNLOG") || rows='[]'
good=$(jq 'length' <<<"$rows" 2>/dev/null || echo 0)

# 3. Outreach drafts (Gmail, drafts only) + pre-fill applications (browser, stop before Submit)
if [ "${good:-0}" -gt 0 ]; then
  out=$(run_claude 200 "Bash(node *) Bash(cd *) $FILE_TOOLS WebFetch WebSearch $BROWSER_TOOLS $GMAIL_TOOLS" \
    "/prefill $(jq -c '.[:5]' <<<"$rows")") || errs+=("prefill")
  res=$(grep -o 'PREFILL_RESULT {.*}' <<<"$out" | tail -1 | sed 's/^PREFILL_RESULT //')
  drafts=$(jq -r '.drafts // 0' <<<"$res" 2>/dev/null || echo 0)
  prefilled=$(jq -r '.prefilled // 0' <<<"$res" 2>/dev/null || echo 0)
  warn=$(jq -r '.warn // 0' <<<"$res" 2>/dev/null || echo 0)
  locked=$(jq -r '.locked // 0' <<<"$res" 2>/dev/null || echo 0)
fi

# 4. Tracker sync + publish
(cd career-ops && node verify-pipeline.mjs --no-hints) >> "$RUNLOG" 2>&1 || true
e=$(publish_tracker); [ -n "$e" ] && errs+=("$e")

err_txt="none"; [ "${#errs[@]}" -gt 0 ] && err_txt="$(IFS=,; echo "${errs[*]}")"
log_line "$(NOW) hunt-cycle | found $found | forwarded $forwarded | evaluated $evaluated | >=4.0 $good | drafts $drafts | prefilled $prefilled | ⚠ $warn | 🔒 $locked | errors: $err_txt"
