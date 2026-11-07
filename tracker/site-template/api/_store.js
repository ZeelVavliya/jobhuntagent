// Approvals live in one small JSON blob: { approved: { "<tracker#>": "<ISO time>" } }.
// It holds tracker numbers only, no personal data.
import { put, list } from '@vercel/blob';

const KEY = 'approvals.json';

export async function loadApprovals() {
  const { blobs } = await list({ prefix: KEY, limit: 1 });
  if (!blobs.length) return { approved: {} };
  const r = await fetch(`${blobs[0].url}?t=${Date.now()}`, { cache: 'no-store' });
  if (!r.ok) return { approved: {} };
  const data = await r.json();
  return data && typeof data.approved === 'object' ? data : { approved: {} };
}

export async function saveApprovals(data) {
  await put(KEY, JSON.stringify(data), {
    access: 'public', addRandomSuffix: false, allowOverwrite: true,
    contentType: 'application/json', cacheControlMaxAge: 60,
  });
}
