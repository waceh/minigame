(function (root) {
    'use strict';
    const KEY = 'minigame.sudoku.records.v1';
    const valid = record => record && typeof record.id === 'string' && record.id.length <= 100 &&
        ['easy', 'normal', 'hard'].includes(record.difficulty) &&
        typeof record.name === 'string' && record.name.length > 0 && record.name.length <= 20 &&
        Number.isSafeInteger(record.elapsed) && record.elapsed >= 0 &&
        Number.isSafeInteger(record.hints) && record.hints >= 0 &&
        Number.isSafeInteger(record.checks) && record.checks >= 0 &&
        Number.isSafeInteger(record.completedAt) && record.completedAt > 0;
    function read(storage) {
        const data = JSON.parse(storage.getItem(KEY) || '[]');
        return Array.isArray(data) ? data.filter(valid) : [];
    }
    function ranking(records, difficulty, assisted = false) {
        return records.filter(r => valid(r) && r.difficulty === difficulty && Boolean(r.hints || r.checks) === assisted)
            .sort((a, b) => a.elapsed - b.elapsed || a.completedAt - b.completedAt);
    }
    function save(storage, record) {
        if (!valid(record)) throw new Error('Invalid record');
        const records = read(storage).filter(r => r.id !== record.id);
        records.push(record);
        // Retain the fastest 100 finishes in each difficulty and assistance category.
        const retained = ['easy', 'normal', 'hard'].flatMap(level => [false, true].flatMap(assisted => ranking(records, level, assisted).slice(0, 100)));
        storage.setItem(KEY, JSON.stringify(retained));
        return retained;
    }
    const api = { read, save, ranking };
    if (typeof module !== 'undefined') module.exports = api;
    else root.SudokuRecords = api;
})(globalThis);
