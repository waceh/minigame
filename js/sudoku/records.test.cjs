const { test } = require('node:test');
const assert = require('node:assert/strict');
const { read, save, ranking } = require('./records.js');
const record = (id, elapsed, extra = {}) => ({ id, name: '플레이어', difficulty: 'normal', elapsed, hints: 0, checks: 0, completedAt: 1000, ...extra });
const storage = () => { let value = null; return { getItem: () => value, setItem: (_, data) => { value = data; } }; };

test('records persist, deduplicate and sort by time then completion date', () => {
    const store = storage();
    save(store, record('slow', 2000));
    save(store, record('newer', 1000, { completedAt: 2000 }));
    save(store, record('older', 1000));
    save(store, record('older', 1000));
    assert.deepEqual(ranking(read(store), 'normal').map(r => r.id), ['older', 'newer', 'slow']);
});
test('difficulty and assistance stay separate; each category retains its fastest 100', () => {
    const store = storage();
    for (let n = 0; n < 101; n++) save(store, record(String(n), n));
    save(store, record('hint', 1, { hints: 1 }));
    save(store, record('check', 2, { checks: 1 }));
    save(store, record('hard', 3, { difficulty: 'hard' }));
    const all = read(store);
    assert.equal(ranking(all, 'normal').length, 100);
    assert.equal(ranking(all, 'normal').at(-1).id, '99');
    assert.deepEqual(ranking(all, 'normal', true).map(r => r.id), ['hint', 'check']);
    assert.equal(ranking(all, 'hard')[0].id, 'hard');
});
test('invalid records are rejected; storage failure is surfaced to caller', () => {
    assert.throws(() => save(storage(), record('bad', -1)));
    assert.deepEqual(read({ getItem: () => '[{"id":"invalid"}]' }), []);
    assert.throws(() => save({ getItem: () => '[]', setItem: () => { throw Error('full'); } }, record('ok', 1)), /full/);
});
