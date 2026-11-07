#!/usr/bin/env bash
# Pull approvals from the tracker website, tick them in review-queue.md, submit only those.
set -uo pipefail
JOB=submit-approved
source "$(dirname "$0")/lib.sh"
acquire_lock submit-approved || exit 0
errs=()
node bin/pull-approvals.mjs >> "$RUNLOG" 2>&1 || errs+=("pull-approvals")
ticked=$(grep -cE '^\| *\[[xX]\] *\|' review-queue.md 2>/dev/null || true)
if [ "${ticked:-0}" -eq 0 ]; then
  log_line "$(NOW) submit-approved | nothing approved"
  exit 0
fi
out=$(run_claude 150 "Bash(node *) Bash(cd *) $FILE_TOOLS $BROWSER_TOOLS mcp__claude_ai_Gmail__search_threads mcp__claude_ai_Gmail__get_thread mcp__claude_ai_Gmail__get_message" \
  "/submit-approved") || errs+=("claude")
(cd career-ops && node tracker.mjs sync) >> "$RUNLOG" 2>&1 || true
e=$(publish_tracker); [ -n "$e" ] && errs+=("$e")
line=$(grep -o 'submit-approved | .*' <<<"$out" | tail -1)
err_txt="none"; [ "${#errs[@]}" -gt 0 ] && err_txt="$(IFS=,; echo "${errs[*]}")"
log_line "$(NOW) ${line:-submit-approved | result not reported} | errors: $err_txt"
