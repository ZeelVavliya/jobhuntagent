# Scheduled tasks (Claude Code CLI, Windows Task Scheduler)

Run once: `powershell -ExecutionPolicy Bypass -File windowsegister-tasks.ps1`
(remove with `-Remove`). Output goes to `logs	ask.log`. Each task runs `claude --chrome -p "<command>"` in this folder.
Needs: Chrome open and signed in with the Claude extension, `claude` logged in with your claude.ai account (brings the Gmail
connector), PC awake and you logged in. Test first: `claude --chrome -p "/digest"`.

---
(Original desktop-app notes below, for reference.)

# Scheduled tasks (Claude desktop app)

Create these in the Claude desktop app → **Scheduled** (or type `/schedule` in a session opened on
`C:\Zeel Australia\job-hunt`). For each one: folder = `C:\Zeel Australia\job-hunt`, permission mode = **Auto**
(or "Accept edits"), and tick the Claude in Chrome and Gmail connectors.
Times are Perth time (AWST). They are spread off the hour to avoid busy slots.

| Name | When | Prompt |
|---|---|---|
| Job hunt cycle | Daily 07:40, 12:40, 17:40 | `/hunt-cycle` |
| Submit approved | Daily 08:10, 13:10, 18:10 | `/submit-approved` |
| Job digest | Daily 07:20 | `/digest` |

The PC must be awake with the desktop app open: Settings → System → Power → "When plugged in, put my device to sleep after" → **Never**.
Chrome must be open with the Claude extension signed in.

## Approving from your phone
- Open the digest draft in Gmail to see what's waiting.
- In the Claude app, open the latest **Submit approved** conversation (Remote Control) and type `approve 3,5,7`
  (tracker numbers), or tick `[x]` in `review-queue.md`. The next **Submit approved** run submits them.

## First week checklist
- Day 1: run each task once with **Run now** while you watch. Approve any prompts it shows (Chrome site access,
  connector first use). After that, runs should go through without asking.
- Day 2–3: read every CV and answer before approving. Correct `config/profile.yml` wherever an answer was wrong.
- If LinkedIn or Seek start showing CAPTCHAs, change **Job hunt cycle** to twice a day.
