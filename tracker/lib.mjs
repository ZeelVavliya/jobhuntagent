// Reads the loop's state straight from markdown, so nothing depends on
// career-ops' SQLite index: career-ops/data/applications.md (tracker),
// career-ops/reports/*.md, review-queue.md, career-ops/output/outreach-*.md.
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join, resolve, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const CO = join(ROOT, 'career-ops');

const cells = (line) => line.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').map((c) => c.trim());
const isSep = (line) => /^\|?\s*:?-{2,}/.test(line.trim());

// Parse every markdown table under a "## <heading>" (or the whole file when heading is null).
export function tables(text, heading = null) {
  let lines = text.split(/\r?\n/);
  if (heading) {
    const i = lines.findIndex((l) => l.trim().toLowerCase() === `## ${heading}`.toLowerCase());
    if (i < 0) return [];
    const rest = lines.slice(i + 1);
    const j = rest.findIndex((l) => /^##\s/.test(l));
    lines = j < 0 ? rest : rest.slice(0, j);
  }
  const out = [];
  for (let i = 0; i < lines.length - 1; i++) {
    if (lines[i].trim().startsWith('|') && isSep(lines[i + 1])) {
      const head = cells(lines[i]).map((h) => h.toLowerCase());
      const rows = [];
      let k = i + 2;
      for (; k < lines.length && lines[k].trim().startsWith('|'); k++) {
        const c = cells(lines[k]);
        const row = {};
        head.forEach((h, idx) => { row[h] = c[idx] ?? ''; });
        rows.push(row);
      }
      out.push(rows);
      i = k;
    }
  }
  return out;
}

const linkTarget = (cell) => (cell.match(/\]\(([^)]+)\)/) || [])[1] || '';
const scoreNum = (s) => { const m = String(s).match(/(\d+(?:\.\d+)?)/); return m ? Number(m[1]) : null; };

export function readReport(rel) {
  if (!rel) return {};
  const p = resolve(CO, 'data', rel);
  const p2 = resolve(CO, rel.replace(/^\.\.\//, ''));
  const file = existsSync(p) ? p : existsSync(p2) ? p2 : null;
  if (!file) return {};
  const t = readFileSync(file, 'utf-8');
  const field = (name) => (t.match(new RegExp(`^\\*\\*${name}:\\*\\*\\s*(.+)$`, 'mi')) || [])[1]?.trim() || '';
  const verdict = (t.split(/\r?\n/).find((l) => /^\*\*[A-Z][^*]*\.\*\*/.test(l)) || '').replace(/\*\*/g, '').trim();
  const tldr = (t.match(/\|\s*\*\*TL;DR\*\*\s*\|\s*(.+?)\s*\|/) || [])[1] || '';
  return {
    file: file.slice(CO.length + 1), url: field('URL'), decision: field('Decision'), archetype: field('Archetype'),
    legitimacy: field('Legitimacy'), workAuth: field('Work Auth'), pdf: field('PDF'), verdict, tldr,
  };
}

export function applications() {
  const p = join(CO, 'data', 'applications.md');
  if (!existsSync(p)) return [];
  const rows = tables(readFileSync(p, 'utf-8')).flat();
  return rows.filter((r) => /^\d+$/.test(r['#'] || '')).map((r) => {
    const reportRel = linkTarget(r.report || '');
    const rep = readReport(reportRel);
    const pdfCell = r.pdf || '';
    const repPdf = /\.pdf$/i.test(rep.pdf || '') ? rep.pdf : '';
    const pdf = linkTarget(pdfCell) || (/\.pdf/i.test(pdfCell) ? pdfCell : '') || repPdf;
    return {
      num: Number(r['#']), date: r.date || '', company: r.company || '', role: r.role || '',
      score: scoreNum(r.score), status: r.status || '', notes: r.notes || '',
      pdf: pdf.replace(/^\.\.\//, '').replace(/^\.\//, ''), report: rep,
    };
  });
}

export function reviewQueue() {
  const p = join(ROOT, 'review-queue.md');
  if (!existsSync(p)) return { waiting: [], done: [] };
  const t = readFileSync(p, 'utf-8');
  const waiting = (tables(t, 'Waiting')[0] || []).filter((r) => /\d/.test(r['#'] || '')).map((r) => ({
    approved: /\[[xX]\]/.test(r.ok || ''), num: Number(String(r['#']).replace(/\D/g, '')), company: r.company,
    role: r.role, score: r.score, channel: r.channel, applyUrl: linkTarget(r['apply url']) || r['apply url'] || '',
    cv: r.cv, prefilled: r['pre-filled'], notes: r.notes,
  }));
  const done = (tables(t, 'Done')[0] || []).filter((r) => /\d/.test(r['#'] || ''));
  return { waiting, done };
}

export function outreachNotes() {
  const dir = join(CO, 'output');
  if (!existsSync(dir)) return {};
  const out = {};
  for (const f of readdirSync(dir)) {
    const m = f.match(/^outreach-(\d+)\.md$/);
    if (m) out[Number(m[1])] = readFileSync(join(dir, f), 'utf-8');
  }
  return out;
}

export function runLog(n = 15) {
  const p = join(ROOT, 'logs', 'runs.log');
  return existsSync(p) ? readFileSync(p, 'utf-8').trim().split(/\r?\n/).slice(-n).reverse() : [];
}

export { basename };
