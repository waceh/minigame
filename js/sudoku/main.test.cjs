const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const engine = require('./engine.js');
const session = require('./session.js');
const html = fs.readFileSync(require.resolve('../../sudoku.html'), 'utf8');
class Element {
    constructor() { this.children = []; this.attrs = {}; this.value = ''; this.textContent = ''; this.disabled = false; this.listeners = {}; }
    append(child) { this.children.push(child); }
    replaceChildren() { this.children = []; this.textContent = ''; }
    setAttribute(k, v) { this.attrs[k] = v; }
    addEventListener(k, fn) { this.listeners[k] = fn; }
    querySelectorAll() { return this.children; }
    click() { if (!this.disabled) return (this.onclick || this.listeners.click)?.(); }
    focus() {}
}
function fixture() {
    const data = new Map(); let now = Date.now(), starts = 0;
    const store = { getItem: k => data.get(k) || null, setItem: (k, v) => data.set(k, v), removeItem: k => data.delete(k) };
    async function load() {
        const ids = Object.fromEntries([...html.matchAll(/id="([^"]+)"/g)].map(m => [m[1], new Element()]));
        ids.difficulty.value = ids['online-difficulty'].value = 'normal'; ids['game-mode'].value = 'online'; ids['record-name'].value = '플레이어';
        const listeners = {}, timers = [];
        const document = { getElementById: id => { assert(ids[id], `Missing #${id}`); return ids[id]; }, createElement: () => new Element(), addEventListener(k, fn) { listeners[k] = fn; }, hidden: false };
        const context = { document, Set, Math, Date: class extends Date { static now() { return now; } }, localStorage: store, confirm: () => true,
            SudokuEngine: engine, SudokuSession: session, setInterval(fn) { timers.push(fn); }, addEventListener(k, fn) { listeners[k] = fn; },
            SudokuOnline: { async request(path) {
                if (path === '/start') { starts++; return { puzzle: engine.generate('hard').puzzle, token: '00000000-0000-0000-0000-000000000000', expiresAt: now + 86400000 }; }
                return { records: [] };
            } } };
        context.window = context; vm.createContext(context);
        vm.runInContext(fs.readFileSync(require.resolve('./main.js'), 'utf8'), context);
        await new Promise(setImmediate);
        return { ids, listeners, timers };
    }
    return { load, store, tick(ms) { now += ms; }, starts: () => starts };
}
test('refresh restores the selected difficulty, board, notes, undo and elapsed practice time', async () => {
    const f = fixture(); session.preferences(f.store, { difficulty: 'hard', mode: 'personal' });
    const first = await f.load(); const { ids } = first;
    const blank = ids.board.children.findIndex(c => c.attrs['aria-label'].includes('빈칸'));
    ids.board.children[blank].click(); ids.notes.click(); ids.numbers.children[2].click();
    f.tick(6500); first.listeners.pagehide();
    const before = ids.board.children.map(c => c.attrs['aria-label']);
    f.tick(60000); const next = await f.load();
    assert.equal(next.ids.difficulty.value, 'hard'); assert.equal(next.ids['game-mode'].value, 'personal');
    assert.deepEqual(next.ids.board.children.map(c => c.attrs['aria-label']), before);
    assert.equal(next.ids.timer.textContent, '00:06'); assert.equal(next.ids.undo.disabled, false);
    next.ids.undo.click(); assert(!next.ids.board.children[blank].attrs['aria-label'].includes('메모'));
    assert.equal(f.starts(), 0);
});
test('online refresh reuses the session token and keeps wall-clock time without requesting another puzzle', async () => {
    const f = fixture(); const first = await f.load();
    f.tick(5000); first.listeners.pagehide(); f.tick(60000);
    const next = await f.load(); assert.equal(f.starts(), 1); assert.equal(next.ids.timer.textContent, '01:05');
    assert.equal(next.ids.hint.disabled, true); assert.equal(next.ids['game-mode'].value, 'online');
    assert.match(next.ids.message.textContent, /이어서/);
});
