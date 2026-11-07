// Read-only approvals feed for the Raspberry Pi (Authorization: Bearer <PI_SYNC_TOKEN>).
import { loadApprovals } from './_store.js';

export default async function handler(req, res) {
  const token = process.env.PI_SYNC_TOKEN || '';
  const auth = req.headers.authorization || '';
  if (!token || auth !== `Bearer ${token}`) return res.status(401).json({ error: 'unauthorized' });
  try {
    const data = await loadApprovals();
    return res.status(200).json({ approved: Object.keys(data.approved || {}).map(Number), updated: data.updated || null });
  } catch (e) {
    return res.status(500).json({ error: String(e && e.message || e) });
  }
}
