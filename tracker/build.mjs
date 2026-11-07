#!/usr/bin/env node
// Builds the Vercel tracker site into tracker/site/ from the loop's markdown state.
// Keeps tracker/site/.vercel (project link) between builds.
import { cpSync, existsSync, mkdirSync, readFileSync, writeFileSync, copyFileSync } from 'node:fs';
import { join, basename } from 'node:path';
import { ROOT, CO, applications, reviewQueue, outreachNotes, runLog } from './lib.mjs';

const T = join(ROOT, 'tracker');
const SITE = join(T, 'site');
const PUB = join(SITE, 'public');
mkdirSync(SITE, { recursive: true });
// Overwrite in place (no deletes): works on folders where deleting is not allowed.
cpSync(join(T, 'site-template'), SITE, { recursive: true, force: true });
mkdirSync(join(PUB, 'pdf'), { recursive: true });

const outreach = outreachNotes();
const apps = applications().map((a) => {
  let pdfHref = null;
  const pdfPath = a.pdf ? join(CO, a.pdf) : null;
  if (pdfPath && existsSync(pdfPath)) {
    const name = `${a.num}-${basename(pdfPath)}`.replace(/[^\w.\-]/g, '_');
    copyFileSync(pdfPath, join(PUB, 'pdf', name));
    pdfHref = `/pdf/${name}`;
  }
  let reportText = '';
  if (a.report.file && existsSync(join(CO, a.report.file))) reportText = readFileSync(join(CO, a.report.file), 'utf-8');
  return { num: a.num, date: a.date, company: a.company, role: a.role, score: a.score, status: a.status, notes: a.notes,
    url: a.report.url || '', pdfHref, report: { verdict: a.report.verdict, decision: a.report.decision,
      archetype: a.report.archetype, workAuth: a.report.workAuth }, reportText, outreach: outreach[a.num] || '' };
});
const q = reviewQueue();
const data = { generated: new Date().toISOString(), apps, waiting: q.waiting, done: q.done, log: runLog(20) };
const json = JSON.stringify(data).replace(/</g, '\\u003c');
const html = readFileSync(join(T, 'index.template.html'), 'utf-8').replace('/*__DATA__*/', () => json);
writeFileSync(join(PUB, 'index.html'), html);
console.log(JSON.stringify({ built: PUB, apps: apps.length, waiting: q.waiting.length }));
