// Cliente mínimo da API Higgsfield com teto de gasto.
// As credenciais vêm de ../.env (raiz do projeto TecTec) (HIGGSFIELD_API_KEY_ID / HIGGSFIELD_API_KEY_SECRET) e nunca são impressas.
//
//   node hf.mjs estimate <endpoint-id> <params.json>
//   node hf.mjs run <endpoint-id> <params.json> <saida-sem-extensao> --ledger <ledger.json> --cap 10 --label S1_t01
//   node hf.mjs upload <arquivo>            -> imprime a URL pública (para image_url)
//   node hf.mjs spent --ledger <ledger.json>
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { dirname, resolve, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';

const here = dirname(fileURLToPath(import.meta.url));
const env = Object.fromEntries(readFileSync(resolve(here, '../.env'), 'utf8').split('\n')
  .filter(l => /^[A-Z_]+=/.test(l)).map(l => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).trim()]));
// aceita o SECRET puro ou o par "ID:SECRET" colado inteiro no campo do secret
let secret = env.HIGGSFIELD_API_KEY_SECRET || '';
if (secret.startsWith(env.HIGGSFIELD_API_KEY_ID + ':')) secret = secret.slice(env.HIGGSFIELD_API_KEY_ID.length + 1);
const AUTH = `Key ${env.HIGGSFIELD_API_KEY_ID}:${secret}`;
const API = 'https://api.higgsfield.ai';
const [cmd, a1, a2, a3] = process.argv.slice(2);
const opt = (k, d) => { const i = process.argv.indexOf('--' + k); return i < 0 ? d : process.argv[i + 1]; };

async function call(method, path, body, extra = {}) {
  const r = await fetch(path.startsWith('http') ? path : API + path, {
    method, headers: { Authorization: AUTH, 'Content-Type': 'application/json', ...extra },
    body: body ? JSON.stringify(body) : undefined });
  const txt = await r.text(); let j; try { j = JSON.parse(txt); } catch { j = { raw: txt.slice(0, 500) }; }
  if (!r.ok) throw new Error(`HTTP ${r.status} ${path.split('?')[0]}: ${JSON.stringify(j).slice(0, 400)}`);
  return j;
}
const ledgerOf = p => existsSync(p) ? JSON.parse(readFileSync(p, 'utf8')) : { cap_usd: null, entries: [] };
const spentOf = L => L.entries.filter(e => !['failed', 'nsfw', 'canceled'].includes(e.status)).reduce((s, e) => s + (+e.usd || 0), 0);

if (cmd === 'estimate') {
  console.log(JSON.stringify(await call('POST', `/estimate/${a1}`, JSON.parse(readFileSync(a2, 'utf8')))));
} else if (cmd === 'upload') {
  const ct = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.webp': 'image/webp' }[extname(a1).toLowerCase()];
  const u = await call('POST', '/files/generate-upload-url', { content_type: ct });
  const put = await fetch(u.upload_url, { method: 'PUT', headers: u.upload_headers, body: readFileSync(a1) });
  if (!put.ok) throw new Error('upload falhou: HTTP ' + put.status);
  console.log(u.public_url);
} else if (cmd === 'spent') {
  const L = ledgerOf(opt('ledger')); console.log(`gasto US$ ${spentOf(L).toFixed(3)} de teto US$ ${L.cap_usd}`);
} else if (cmd === 'run') {
  const params = JSON.parse(readFileSync(a2, 'utf8')); const out = a3;
  const lp = opt('ledger'); const cap = +opt('cap', 10); const label = opt('label', 'x');
  const L = ledgerOf(lp); L.cap_usd = cap;
  const est = await call('POST', `/estimate/${a1}`, params);
  const spent = spentOf(L);
  if (spent + +est.usd > cap) { console.error(`RECUSADO: gasto ${spent.toFixed(3)} + estimativa ${est.usd} passa do teto ${cap}`); process.exit(2); }
  const sub = await call('POST', `/${a1}`, params, { 'Idempotency-Key': randomUUID() });
  const entry = { label, endpoint: a1, request_id: sub.request_id, usd: est.usd, credits: est.credits, status: 'queued', at: new Date().toISOString(), params };
  L.entries.push(entry); mkdirSync(dirname(resolve(lp)), { recursive: true }); writeFileSync(lp, JSON.stringify(L, null, 2));
  console.log(`${label}: enviado (estimativa US$ ${est.usd}), aguardando...`);
  let st, wait = 4000;
  for (let i = 0; i < 200; i++) {
    await new Promise(r => setTimeout(r, wait)); wait = Math.min(15000, wait * 1.3);
    st = await call('GET', sub.status_url);
    if (['completed', 'failed', 'nsfw', 'canceled'].includes(st.status)) break;
  }
  entry.status = st.status; writeFileSync(lp, JSON.stringify(L, null, 2));
  if (st.status !== 'completed') { console.error(`${label}: terminou como ${st.status}`); process.exit(3); }
  const media = st.video?.url ? [st.video.url] : (st.images || []).map(x => x.url);
  for (const [i, u] of media.entries()) {
    const ext = (new URL(u).pathname.match(/\.[a-z0-9]+$/i) || ['.bin'])[0];
    const f = media.length > 1 ? `${out}_${i}${ext}` : `${out}${ext}`;
    mkdirSync(dirname(resolve(f)), { recursive: true });
    writeFileSync(f, Buffer.from(await (await fetch(u)).arrayBuffer())); console.log('salvo', f);
  }
  console.log(`total gasto: US$ ${spentOf(L).toFixed(3)} / teto ${cap}`);
} else {
  console.log('uso: estimate | run | upload | spent');
}
