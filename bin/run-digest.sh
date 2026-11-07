#!/usr/bin/env bash
# Daily digest as a Gmail draft to Zeel (never sent), then refresh the tracker.
set -uo pipefail
JOB=digest
source "$(dirname "$0")/lib.sh"
acquire_lock digest || exit 0
out=$(run_claude 40 "Bash(node *) Bash(cd *) Bash(tail *) $FILE_TOOLS $GMAIL_TOOLS" "/digest TRACKER_URL=${TRACKER_URL:-not set}") || true
e=$(publish_tracker)
line=$(grep -o 'digest | .*' <<<"$out" | tail -1)
log_line "$(NOW) ${line:-digest | result not reported}${e:+ | errors: $e}"
