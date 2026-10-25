import { readFile, writeFile } from 'node:fs/promises';
const value = process.argv[2];
let url;
try { url = new URL(value); } catch { throw Error('Usage: npm run configure-client -- https://YOUR-WORKER.YOUR-SUBDOMAIN.workers.dev'); }
if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash || url.pathname !== '/') {
  throw Error('Use the HTTPS server origin only, without credentials, paths or query strings.');
}
const file = new URL('../../js/cardduel/config.js', import.meta.url);
const source = await readFile(file, 'utf8');
const next = source.replace(/^const CARD_DUEL_PRODUCTION_SERVER = .*;$/m, `const CARD_DUEL_PRODUCTION_SERVER = ${JSON.stringify(url.origin)};`);
if (next === source && !source.includes(JSON.stringify(url.origin))) throw Error('Client config marker was not found.');
await writeFile(file, next);
console.log('Godot web client now uses:', url.origin);
console.log('Publish cardduel.html, cardduel/web/ and js/cardduel/config.js with your static site.');
