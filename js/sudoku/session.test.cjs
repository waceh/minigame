const { test } = require('node:test');
const assert = require('node:assert/strict');
const { generate } = require('./engine.js');
const session = require('./session.js');
const storage = () => { const data = new Map(); return { getItem: k => data.get(k) || null, setItem: (k, v) => data.set(k, v), removeItem: k => data.delete(k) }; };
function state() {
    const { puzzle, solution } = generate('hard');
    return { puzzle, solution, values: puzzle.slice(), notes: Array.from({ length: 81 }, () => []),
        selected: puzzle.indexOf(0), elapsed: 12345, hintsUsed: 0, checksUsed: 0, gameDifficulty: 'hard', onlineRun: null, history: [] };
}
test('session round trip preserves difficulty, puzzle, values, notes and undo history', () => {
    const store = storage(), original = state();
    original.notes[original.selected] = [1, 3, 7];
    original.history = [{ values: original.values, notes: original.notes }];
    assert(session.save(store, original));
    const loaded = session.load(store);
    assert.equal(loaded.gameDifficulty, 'hard'); assert.deepEqual(loaded.puzzle, original.puzzle);
    assert.deepEqual(loaded.notes, original.notes); assert.deepEqual(loaded.history, original.history);
    assert.equal(loaded.elapsed, 12345);
});
test('expired online sessions and malformed saves do not restore', () => {
    const store = storage(), original = state();
    original.onlineRun = { token: '00000000-0000-0000-0000-000000000000', expiresAt: 1000 };
    original.onlineStarted = 1;
    session.save(store, original); assert(session.load(store, 500)); assert.equal(session.load(store, 1001), null);
    session.save(store, { ...state(), values: [1] }); assert.equal(session.load(store), null);
    store.setItem('minigame.sudoku.session.v1', '{bad'); assert.equal(session.load(store), null);
});
test('preferences survive reload; blocked storage fails gracefully', () => {
    const store = storage();
    session.preferences(store, { mode: 'personal', difficulty: 'hard' });
    assert.deepEqual(session.preferences(store), { mode: 'personal', difficulty: 'hard' });
    const blocked = { getItem() { throw Error(); }, setItem() { throw Error(); } };
    assert.equal(session.load(blocked), null); assert.equal(session.save(blocked, state()), false);
});
