#!/usr/bin/env node
// Prints tracker rows as JSON, read straight from applications.md.
// node bin/tracker-rows.mjs [--status Evaluated] [--since YYYY-MM-DD] [--min-score 4] [--count]
import { applications } from '../tracker/lib.mjs';
const arg = (k) => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : undefined; };
let rows = applications();
const status = arg('--status'), since = arg('--since'), min = arg('--min-score');
if (status) rows = rows.filter((r) => r.status.toLowerCase() === status.toLowerCase());
if (since) rows = rows.filter((r) => r.date >= since);
if (min) rows = rows.filter((r) => r.score !== null && r.score >= Number(min));
if (process.argv.includes('--count')) console.log(rows.length);
else console.log(JSON.stringify(rows.map((r) => ({ num: r.num, company: r.company, role: r.role, score: r.score,
  url: r.report.url || '', report: r.report.file ? `career-ops/${r.report.file}` : '', pdf: r.pdf ? `career-ops/${r.pdf}` : '' }))));
