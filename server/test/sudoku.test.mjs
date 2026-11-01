import test from 'node:test';
import assert from 'node:assert/strict';
import { registerHooks } from 'node:module';
registerHooks({ resolve(specifier, context, next) {
    if (specifier === 'cloudflare:workers') return { url: 'data:text/javascript,export class DurableObject { constructor(ctx, env) { this.ctx = ctx; this.env = env; } }', shortCircuit: true };
    return next(specifier, context);
} });
const { SudokuCompetition, sudokuRoute } = await import('../src/sudoku.ts');
const { generate, countSolutions } = await import('../src/sudoku-engine.ts');
function fixture() {
    const instances = new Map(), stores = new Map();
    const env = { SUDOKU: { getByName(name) {
        if (!instances.has(name)) {
            const data = new Map(); stores.set(name, data);
            const storage = { async get(key) { return structuredClone(data.get(key)); }, async put(key, value) { data.set(key, structuredClone(value)); }, async setAlarm() {}, async deleteAll() { data.clear(); } };
            instances.set(name, new SudokuCompetition({ storage, id: { toString: () => name } }, env));
        }
        return instances.get(name);
    } } };
    const request = async (path, body) => {
        const response = await sudokuRoute(new Request('https://game/api/sudoku' + path, { method: body ? 'POST' : 'GET', body: body ? JSON.stringify(body) : undefined }), env);
        return { status: response.status, data: await response.json() };
    };
    return { env, request, stores };
}
test('server generates unique puzzles at every difficulty', () => {
    for (const level of ['easy', 'normal', 'hard']) {
        const { puzzle, solution } = generate(level);
        assert.equal(countSolutions(puzzle), 1); assert.equal(countSolutions(solution), 1);
    }
});
test('server verifies completion, ignores submitted time, publishes once and shares rankings', async () => {
    const { request, stores } = fixture();
    const started = await request('/start', { difficulty: 'normal' });
    assert.equal(started.status, 200); assert(!('solution' in started.data));
    const { token } = started.data;
    const run = stores.get(`run:${token}`).get('run');
    run.startedAt = Date.now() - 10000;
    assert.equal((await request(`/${token}/publish`, { name: 'early' })).status, 409);
    assert.equal((await request(`/${token}/finish`, { values: run.puzzle })).status, 400);
    const done = await request(`/${token}/finish`, { values: run.solution, elapsed: 1 });
    assert.equal(done.status, 200); assert(done.data.elapsed >= 10000);
    assert.deepEqual((await request(`/${token}/finish`, { values: run.solution })).data, done.data);
    assert.equal((await request(`/${token}/publish`, { name: ' ' })).status, 400);
    const published = await request(`/${token}/publish`, { name: '첫 번째' });
    assert.equal(published.data.rank, 1);
    const retry = await request(`/${token}/publish`, { name: '변경' });
    assert.equal(retry.data.record.name, '첫 번째');
    const board = await request('/rankings?difficulty=normal');
    assert.equal(board.data.records.length, 1); assert(!('token' in board.data.records[0]));
    assert.equal((await request('/rankings?difficulty=easy')).data.records.length, 0);
    assert.equal((await request('/rankings', { elapsed: 0 })).status, 404);
});
test('invalid, expired and missing sessions cannot submit records', async () => {
    const { request, stores } = fixture();
    assert.equal((await request('/start', { difficulty: 'bad' })).status, 400);
    const { data } = await request('/start', { difficulty: 'easy' });
    const run = stores.get(`run:${data.token}`).get('run'); run.expiresAt = 1;
    assert.equal((await request(`/${data.token}/finish`, { values: run.solution })).status, 410);
    assert.equal((await request('/00000000-0000-0000-0000-000000000000/finish', { values: [] })).status, 410);
});
