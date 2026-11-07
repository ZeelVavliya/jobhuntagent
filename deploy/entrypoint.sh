#!/usr/bin/env bash
# Starts the virtual screen (+ password-protected noVNC on :6080), prepares /work, then runs the scheduler
# (default) or the command given, e.g. `docker compose run --rm hunt claude`.
set -euo pipefail
export DISPLAY=:99
rm -f /tmp/.X99-lock /tmp/login-browser.active
Xvfb :99 -screen 0 1440x900x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
sleep 1
fluxbox >/tmp/fluxbox.log 2>&1 &
if [ -n "${VNC_PASSWORD:-}" ]; then
  mkdir -p "$HOME/.vnc"
  x11vnc -storepasswd "$VNC_PASSWORD" "$HOME/.vnc/passwd" >/dev/null 2>&1
  x11vnc -display :99 -forever -shared -localhost -rfbport 5900 -rfbauth "$HOME/.vnc/passwd" -quiet >/tmp/x11vnc.log 2>&1 &
  websockify --web /usr/share/novnc 6080 localhost:5900 >/tmp/novnc.log 2>&1 &
fi
bash /work/bin/bootstrap.sh || echo "bootstrap: see messages above"
if [ "${1:-scheduler}" = "scheduler" ]; then
  echo "Scheduler started ($(date)). Jobs: /work/deploy/crontab"
  exec supercronic -passthrough-logs /work/deploy/crontab
fi
exec "$@"
