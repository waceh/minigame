import test from 'node:test';
import assert from 'node:assert/strict';
import { applyAction, canPlay, createRoom, joinRoom, newPlayer, normalizeName, viewFor } from '../src/game.ts';
const request = (state, type, extra = {}) => ({ type, revision: state.revision, requestId: crypto.randomUUID(), ...extra });
function game() {
  let s = createRoom('ABCDEFGH', newPlayer('하나'));
  s = joinRoom(s, newPlayer('둘'));
  s = applyAction(s, s.players[0].id, request(s, 'ready'), () => .4);
  s = applyAction(s, s.players[1].id, request(s, 'ready'), () => .4);
  return s;
}
function cards(s) { return [...s.deck, ...s.discard, ...s.players.flatMap(p => p.hand)]; }
test('both players must be ready; server deals 52 unique cards', () => {
  const s = game();
  assert.equal(s.phase, 'playing'); assert.deepEqual(s.players.map(p => p.hand.length), [7, 7]);
  assert.equal(new Set(cards(s)).size, 52); assert.equal(cards(s).length, 52);
});
test('private snapshots never reveal tokens, the deck or opponent cards', () => {
  const s = game(), v = viewFor(s, s.players[0].id);
  assert.deepEqual(v.hand, s.players[0].hand); assert(!('deck' in v));
  for (const p of v.players) { assert(!('hand' in p)); assert(!('token' in p)); assert(!('requests' in p)); }
  assert(!JSON.stringify(v).includes(s.players[1].token));
});
test('turn, ownership, matching and stale-state checks are authoritative', () => {
  const s = game(), active = s.players[s.turn], other = s.players[1 - s.turn];
  assert.throws(() => applyAction(s, other.id, request(s, 'draw')), { code: 'NOT_YOUR_TURN' });
  assert.throws(() => applyAction(s, active.id, request(s, 'play', { cardId: s.deck[0] })), { code: 'INVALID_CARD' });
  const bad = active.hand.find(c => !canPlay(c, s.discard.at(-1)));
  assert.notEqual(bad, undefined);
  assert.throws(() => applyAction(s, active.id, request(s, 'play', { cardId: bad })), { code: 'ILLEGAL_CARD' });
  assert.throws(() => applyAction(s, active.id, { ...request(s, 'draw'), revision: -1 }), { code: 'STALE_STATE' });
  assert.equal(cards(s).length, 52);
});
test('duplicate actions do not draw or switch turns twice', () => {
  const s = game(), action = request(s, 'draw'), id = s.players[s.turn].id;
  const next = applyAction(s, id, action);
  assert.equal(next.players.find(p => p.id === id).hand.length, 8);
  assert.strictEqual(applyAction(next, id, action), next);
  assert.equal(s.players.find(p => p.id === id).hand.length, 7);
});
test('full-room rejection and explicit leaving', () => {
  let s = game();
  assert.throws(() => joinRoom(s, newPlayer('셋')), { code: 'ROOM_FULL' });
  const leaving = s.players[0].id;
  s = applyAction(s, leaving, request(s, 'leave'));
  assert.equal(s.phase, 'finished'); assert.equal(s.winnerId, s.players[1].id);
  assert.throws(() => viewFor(s, leaving), { code: 'UNAUTHORIZED' });
});
test('deck recycles without duplicating the top card', () => {
  let s = game(); s.deck = []; s.discard = [20, 30, 40];
  const player = s.players[s.turn];
  s = applyAction(s, player.id, request(s, 'draw'), () => .2);
  assert.deepEqual(s.discard, [40]); assert.equal(s.deck.length, 1);
  assert([20, 30].includes(s.players.find(p => p.id === player.id).hand.at(-1)));
});
test('a complete match conserves cards and permits a rematch', () => {
  let s = game();
  for (let turn = 0; turn < 2000 && s.phase === 'playing'; turn++) {
    const p = s.players[s.turn], card = p.hand.find(c => canPlay(c, s.discard.at(-1)));
    s = applyAction(s, p.id, request(s, card === undefined ? 'draw' : 'play', { cardId: card }), () => .3);
    assert.equal(cards(s).length, 52); assert.equal(new Set(cards(s)).size, 52);
  }
  assert.equal(s.phase, 'finished');
  const oldStarter = 0;
  for (const p of [...s.players]) s = applyAction(s, p.id, request(s, 'ready'), () => .7);
  assert.equal(s.phase, 'playing'); assert.equal(s.round, 2); assert.equal(s.turn, 1 - oldStarter);
});
test('invalid nicknames and malformed input are rejected', () => {
  assert.throws(() => normalizeName('  ')); assert.throws(() => normalizeName('가'.repeat(17)));
  assert.equal(normalizeName('  하나\u0000 '), '하나');
  const s = game(); assert.throws(() => applyAction(s, s.players[0].id, null));
});
