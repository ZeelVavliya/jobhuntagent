#!/usr/bin/env bash
# Shared helpers for the job-hunt loop scripts. Sourced, not run.
export TZ="${TZ:-Australia/Perth}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
mkdir -p logs
RUNLOG="$ROOT/logs/$(date +%F)-${JOB:-run}.log"
NOW() { date -Iseconds; }

# One line per run in logs/runs.log, echoed as the script's last output.
log_line() { echo "$1" >> "$ROOT/logs/runs.log"; echo "$1"; }

# Only one loop job at a time (they share the browser profile and career-ops files).
acquire_lock() {
  exec 9>/tmp/jobhunt.lock
  if ! flock -w 2700 9; then
    log_line "$(NOW) $1 | skipped: previous run still active"
    return 1
  fi
  if [ -e /tmp/login-browser.active ]; then
    log_line "$(NOW) $1 | skipped: login browser is open (close it to resume)"
    return 1
  fi
}

# Tools Claude may use with the browser and Gmail. Sending email stays denied
# in .claude/settings.json whatever is listed here.
GMAIL_TOOLS="mcp__claude_ai_Gmail__create_draft mcp__claude_ai_Gmail__list_drafts mcp__claude_ai_Gmail__get_draft mcp__claude_ai_Gmail__search_threads mcp__claude_ai_Gmail__get_thread mcp__claude_ai_Gmail__get_message mcp__claude_ai_Gmail__list_labels mcp__claude_ai_Gmail__label_message mcp__claude_ai_Gmail__update_message_labels"
BROWSER_TOOLS="mcp__playwright"
FILE_TOOLS="Read Write Edit Glob Grep"

# run_claude <max-turns> "<allowed tools>" "<prompt>"  (runs in the current directory)
run_claude() {
  local turns="$1" tools="$2" prompt="$3"
  {
    echo "----- $(NOW) claude -p (cwd $(pwd)) -----"
    echo "$prompt" | head -c 400; echo
  } >> "$RUNLOG"
  timeout 80m claude -p "$prompt" \
    --mcp-config "$ROOT/.mcp.json" \
    --allowedTools "$tools" \
    --max-turns "$turns" \
    --output-format text 2>>"$RUNLOG" | tee -a "$RUNLOG"
  return "${PIPESTATUS[0]}"
}

publish_tracker() {
  bash "$ROOT/bin/publish-tracker.sh" >> "$RUNLOG" 2>&1 || echo "tracker-publish"
}
