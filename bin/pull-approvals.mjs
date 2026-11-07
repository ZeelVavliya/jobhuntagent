#!/usr/bin/env node
// Fetches approvals from the tracker site and ticks those rows [x] in review-queue.md.
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { ROOT } from '../tracker/lib.mjs';

const url = (process.env.TRACKER_URL || '').replace(/\/$/, '');
const token = process.env.PI_SYNC_TOKEN || '';
if (!url || !token) { console.log('pull-approvals: TRACKER_URL or PI_SYNC_TOKEN not set, skipped'); process.exit(0); }
const r = await fetch(`${url}/api/approvals`, { headers: { authorization: `Bearer ${token}` } });
if (!r.ok) { console.error(`pull-approvals: HTTP ${r.status}`); process.exit(1); }
const { approved = [] } = await r.json();
const p = join(ROOT, 'review-queue.md');
if (!existsSync(p)) process.exit(0);
const lines = readFileSync(p, 'utf-8').split('\n');
let inWaiting = false, ticked = [];
for (let i = 0; i < lines.length; i++) {
  if (/^##\s/.test(lines[i])) inWaiting = /^##\s+Waiting/i.test(lines[i]);
  if (!inWaiting) continue;
  const m = lines[i].match(/^\|\s*\[\s\]\s*\|\s*(\d+)\s*\|/);
  if (m && approved.includes(Number(m[1])) && !/⚠|🔒/.test(lines[i])) {
    lines[i] = lines[i].replace(/^\|\s*\[\s\]/, '| [x]');
    ticked.push(Number(m[1]));
  }
}
if (ticked.length) writeFileSync(p, lines.join('\n'));
console.log(JSON.stringify({ approved, ticked }));
