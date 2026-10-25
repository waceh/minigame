import test from 'node:test';
import assert from 'node:assert/strict';
const base = process.env.CARD_DUEL_SERVER || 'http://127.0.0.1:8787';
const sockets = [];
async function post(path, body, origin) {
  const response = await fetch(base + path, { method: 'POST', headers: { 'Content-Type': 'application/json', ...(origin ? { Origin: origin } : {}) }, body: JSON.stringify(body) });
  return { status: response.status, body: await response.json() };
}
class Client {
  constructor(session) {
    this.messages = []; this.state = null;
    this.ws = new WebSocket(base.replace(/^http/, 'ws') + `/api/rooms/${session.room}/socket`);
    sockets.push(this.ws);
    this.ws.addEventListener('open', () => this.ws.send(JSON.stringify({ type: 'auth', token: session.token })));
    this.ws.addEventListener('message', event => {
      const data = event.data === 'pong' ? { type: 'pong' } : JSON.parse(event.data);
      this.messages.push(data); if (data.type === 'state') this.state = data;
    });
  }
  async wait(predicate) {
    const until = Date.now() + 8000;
    while (Date.now() < until) { const result = this.messages.find(predicate); if (result) return result; await new Promise(resolve => setTimeout(resolve, 10)); }
    throw Error('Timed out waiting for WebSocket message');
  }
  send(type, extra = {}) { const action = { type, revision: this.state.revision, requestId: crypto.randomUUID(), ...extra }; this.ws.send(JSON.stringify(action)); return action; }
}
test('real Worker: two private players, authoritative play, full-room rejection, heartbeat and reconnect', { timeout: 25000 }, async t => {
  t.after(() => sockets.forEach(ws => ws.close()));
  const denied = await post('/api/rooms', { name: '외부' }, 'https://untrusted.example');
  assert.equal(denied.status, 403);
  const created = await post('/api/rooms', { name: '하나' });
  assert.equal(created.status, 201); assert.match(created.body.room, /^[A-Z2-9]{8}$/);
  const a = new Client(created.body); await a.wait(m => m.type === 'state');
  const joined = await post(`/api/rooms/${created.body.room}/join`, { name: '둘' });
  assert.equal(joined.status, 201);
  const b = new Client(joined.body); await b.wait(m => m.type === 'state');
  await a.wait(m => m.type === 'state' && m.players.length === 2 && m.players.every(p => p.connected));
  assert.equal((await post(`/api/rooms/${created.body.room}/join`, { name: '셋' })).status, 409);
  a.send('ready'); await a.wait(m => m.type === 'state' && m.players[0].ready);
  await b.wait(m => m.type === 'state' && m.players[0].ready);
  b.send('ready');
  await a.wait(m => m.phase === 'playing'); await b.wait(m => m.phase === 'playing');
  for (const c of [a, b]) {
    assert.equal(c.state.hand.length, 7); assert(!('deck' in c.state));
    assert(c.state.players.every(p => !('hand' in p) && !('token' in p)));
  }
  const active = a.state.turn === a.state.you ? a : b, other = active === a ? b : a;
  other.send('draw'); await other.wait(m => m.code === 'NOT_YOUR_TURN');
  const oldRevision = active.state.revision;
  const draw = active.send('draw'); active.ws.send(JSON.stringify(draw));
  await active.wait(m => m.type === 'state' && m.revision > oldRevision);
  assert.equal(active.state.hand.length, 8); assert.equal(active.state.revision, oldRevision + 1);
  await other.wait(m => m.type === 'state' && m.revision > oldRevision);
  const top = other.state.topCard;
  const legal = other.state.hand.find(c => Math.floor(c / 13) === Math.floor(top / 13) || c % 13 === top % 13);
  const before = other.state.revision;
  other.send(legal === undefined ? 'draw' : 'play', { cardId: legal });
  await other.wait(m => m.type === 'state' && m.revision > before);
  assert.equal(other.state.hand.length, legal === undefined ? 8 : 6);
  a.ws.send('ping'); await a.wait(m => m.type === 'pong');
  await a.wait(m => m.type === 'state' && m.revision > before);
  const hand = [...a.state.hand], revision = a.state.revision;
  a.ws.close();
  const reconnected = new Client(created.body); await reconnected.wait(m => m.type === 'state');
  assert.deepEqual(reconnected.state.hand, hand); assert.equal(reconnected.state.revision, revision);
  const last = reconnected.state.revision;
  reconnected.send('leave'); await reconnected.wait(m => m.type === 'left');
  await b.wait(m => m.type === 'state' && m.revision > last && m.reason === 'left');
  assert.equal(b.state.winnerId, joined.body.playerId);
  const missing = await post('/api/rooms/ZZZZZZZZ/join', { name: '없음' });
  assert.equal(missing.status, 404);
});
