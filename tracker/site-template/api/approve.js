// GET: current approvals. POST {num, approved}: tick or untick one row.
// Behind the password gate in middleware.js.
import { loadApprovals, saveApprovals } from './_store.js';

export default async function handler(req, res) {
  try {
    if (req.method === 'GET') return res.status(200).json(await loadApprovals());
    if (req.method !== 'POST') return res.status(405).json({ error: 'method not allowed' });
    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : (req.body || {});
    const num = Number(body.num);
    if (!Number.isInteger(num) || num <= 0) return res.status(400).json({ error: 'bad tracker number' });
    const data = await loadApprovals();
    if (body.approved) data.approved[String(num)] = new Date().toISOString();
    else delete data.approved[String(num)];
    data.updated = new Date().toISOString();
    await saveApprovals(data);
    return res.status(200).json(data);
  } catch (e) {
    return res.status(500).json({ error: String(e && e.message || e) });
  }
}
