// Landing demo proxy: GET /go?u=<url> fetches a page and drops the headers that stop it being framed.
// ponytail: HTML only, GET only, iframe requests only, sandboxed frame, no cookies either way; no rewriting beyond <base> and link capture. Add rate limiting if abused.
const CAPTURE = `<script>addEventListener('click',e=>{const a=e.target.closest&&e.target.closest('a[href]');if(!a||e.defaultPrevented)return;e.preventDefault();parent.postMessage({blackcomb:a.href},'*')},true);addEventListener('submit',e=>{const f=e.target;if((f.method||'get').toLowerCase()!=='get')return;e.preventDefault();const u=new URL(f.action||location.href);new FormData(f).forEach((v,k)=>u.searchParams.set(k,v));parent.postMessage({blackcomb:u.href},'*')},true)</script>`;

const PRIVATE = /^(localhost|.*\.local|.*\.internal|\[.*\]|\d+\.\d+\.\d+\.\d+)$/i;

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (url.pathname === '/api/search') return search(url.searchParams.get('q'));
    if (url.pathname !== '/go') return env.ASSETS.fetch(req);
    if (req.method !== 'GET' || req.headers.get('Sec-Fetch-Dest') !== 'iframe') return new Response('iframe only', { status: 403 });
    let target;
    try { target = new URL(url.searchParams.get('u')); } catch { return new Response('bad url', { status: 400 }); }
    if (!/^https?:$/.test(target.protocol) || PRIVATE.test(target.hostname)) return new Response('bad url', { status: 400 });
    let r;
    try {
      r = await fetch(target, { redirect: 'follow', headers: { 'User-Agent': 'Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 Safari/605.1.15', Accept: 'text/html' } });
    } catch { return new Response('could not load ' + target.host, { status: 502 }); }
    if (!(r.headers.get('content-type') || '').includes('text/html')) return new Response('not a page', { status: 415 });
    const html = (await r.text()).replace(/<head[^>]*>/i, m => `${m}<base href="${r.url}">${CAPTURE}`);
    return new Response(html, { headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' } });
  },
};

// Blackcomb Search: answers, not a web index. Wikipedia titles plus DuckDuckGo's instant answer, both keyless.
// ponytail: two free sources and a 5 minute edge cache; a real index needs a paid API key (Brave Search), add when wanted.
const UA = 'Blackcomb/1.0 (https://blackcomb.jaybulb.com)';
async function search(q) {
  q = (q || '').trim().slice(0, 200);
  const json = body => new Response(JSON.stringify(body), { headers: { 'content-type': 'application/json', 'cache-control': 'public, max-age=300' } });
  if (!q) return json({ q, answer: null, pages: [] });
  const get = async u => { try { const r = await fetch(u, { headers: { 'User-Agent': UA } }); return r.ok ? await r.json() : null; } catch { return null; } };
  const enc = encodeURIComponent(q);
  const [wiki, ddg] = await Promise.all([
    get(`https://en.wikipedia.org/w/rest.php/v1/search/page?q=${enc}&limit=8`),
    get(`https://api.duckduckgo.com/?q=${enc}&format=json&no_html=1&skip_disambig=1`),
  ]);
  const pages = (wiki?.pages || []).map(p => ({ title: p.title, description: p.description || '', url: 'https://en.wikipedia.org/wiki/' + encodeURIComponent(p.key) }));
  const text = ddg?.Answer || ddg?.AbstractText || '';
  const answer = text ? { text: String(text).slice(0, 600), url: ddg.AbstractURL || '', source: ddg.AbstractSource || 'DuckDuckGo' } : null;
  return json({ q, answer, pages });
}
