// Password gate for the whole tracker (pages, PDFs, /api/approve).
// /api/approvals is left out: the Pi reads it with its own bearer token.
import { next } from '@vercel/functions';

export const config = { matcher: '/((?!api/approvals).*)' };

function safeEqual(a, b) {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

export default function middleware(request) {
  const password = process.env.TRACKER_PASSWORD;
  if (!password) return new Response('TRACKER_PASSWORD is not set in Vercel.', { status: 503 });
  const header = request.headers.get('authorization') || '';
  if (header.startsWith('Basic ')) {
    let decoded = '';
    try { decoded = atob(header.slice(6)); } catch { decoded = ''; }
    const supplied = decoded.slice(decoded.indexOf(':') + 1);
    if (safeEqual(supplied, password)) return next();
  }
  return new Response('Password required.', {
    status: 401,
    headers: { 'WWW-Authenticate': 'Basic realm="Job hunt tracker", charset="UTF-8"' },
  });
}
