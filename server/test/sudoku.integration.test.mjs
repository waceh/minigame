import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const { peers } = createRequire(import.meta.url)('../../js/sudoku/engine.js');
const base = (process.env.CARD_DUEL_SERVER || 'http://127.0.0.1:8787') + '/api/sudoku';
async function request(path, body, origin = 'http://127.0.0.1:8003') {
    const response = await fetch(base + path, { method: body ? 'POST' : 'GET', headers: { Origin: origin, ...(body ? { 'Content-Type': 'application/json' } : {}) }, body: body ? JSON.stringify(body) : undefined });
    return { status: response.status, body: await response.json(), cors: response.headers.get('Access-Control-Allow-Origin') };
}
function solve(input) {
    const board = input.slice();
    function search() {
        let cell = -1, options = [];
        for (let i = 0; i < 81; i++) {
            if (board[i]) continue;
            const choices = [1,2,3,4,5,6,7,8,9].filter(n => !board.some((v, j) => v === n && peers(i, j)));
            if (!choices.length) return false;
            if (cell < 0 || choices.length < options.length) { cell = i; options = choices; }
        }
        if (cell < 0) return true;
        for (const n of options) { board[cell] = n; if (search()) return true; }
        board[cell] = 0; return false;
    }
    assert(search()); return board;
}
test('online Sudoku: server puzzle, validation, server time, shared ranks and idempotent publication', async () => {
    assert.equal((await request('/start', { difficulty: 'invalid' })).status, 400);
    assert.equal((await request('/rankings', undefined, 'https://untrusted.example')).status, 403);
    const started = await request('/start', { difficulty: 'normal' });
    assert.equal(started.status, 200); assert.equal(started.cors, 'http://127.0.0.1:8003');
    const { puzzle, token, startedAt } = started.body;
    assert.equal(puzzle.length, 81); assert(!('solution' in started.body));
    const solution = solve(puzzle);
    assert.equal((await request(`/${token}/publish`, { name: 'early' })).status, 409);
    assert.equal((await request(`/${token}/finish`, { values: puzzle })).status, 400);
    const invalid = solution.slice(); invalid[0] = 0;
    assert.equal((await request(`/${token}/finish`, { values: invalid })).status, 400);
    const done = await request(`/${token}/finish`, { values: solution, elapsed: 0, difficulty: 'easy' });
    assert.equal(done.status, 200); assert(done.body.elapsed >= 0);
    assert.equal(done.body.elapsed, done.body.completedAt - startedAt);
    const again = await request(`/${token}/finish`, { values: solution });
    assert.deepEqual(again.body, done.body);
    assert.equal((await request(`/${token}/publish`, { name: ' ' })).status, 400);
    const name = `test-${Date.now()}`;
    const published = await request(`/${token}/publish`, { name });
    assert.equal(published.status, 200); assert.equal(published.body.record.elapsed, done.body.elapsed);
    assert.equal(published.body.record.difficulty, 'normal');
    const retry = await request(`/${token}/publish`, { name: 'renamed' });
    assert.equal(retry.body.record.name, name); assert.equal(retry.body.record.id, published.body.record.id);
    const rankings = await request('/rankings?difficulty=normal');
    const found = rankings.body.records.filter(r => r.id === published.body.record.id);
    if (published.body.rank <= 10) { assert.equal(found.length, 1); assert.equal(found[0].name, name); }
    assert(rankings.body.records.every(r => !('token' in r) && !('solution' in r) && !('puzzle' in r)));
    assert.equal((await request('/00000000-0000-0000-0000-000000000000/finish', { values: solution })).status, 410);
    assert.equal((await request('/rankings', { name: 'forged', elapsed: 0 })).status, 404);
});
