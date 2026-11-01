(function (root) {
    'use strict';
    const KEY = 'minigame.sudoku.session.v1', PREFERENCES = 'minigame.sudoku.preferences.v1';
    const levels = ['easy', 'normal', 'hard'];
    const board = value => Array.isArray(value) && value.length === 81 && value.every(n => Number.isInteger(n) && n >= 0 && n <= 9);
    const notes = value => Array.isArray(value) && value.length === 81 && value.every(list => Array.isArray(list) && list.length <= 9 && list.every(n => Number.isInteger(n) && n >= 1 && n <= 9));
    function valid(state) {
        return state && state.version === 1 && levels.includes(state.gameDifficulty) && board(state.puzzle) && board(state.values) && notes(state.notes) &&
            state.puzzle.every((n, i) => !n || state.values[i] === n) &&
            Number.isInteger(state.selected) && state.selected >= 0 && state.selected < 81 &&
            ['elapsed', 'hintsUsed', 'checksUsed'].every(key => Number.isFinite(state[key]) && state[key] >= 0) &&
            (state.onlineRun ? typeof state.onlineRun.token === 'string' && /^[a-f0-9-]{36}$/.test(state.onlineRun.token) &&
                Number.isFinite(state.onlineRun.expiresAt) && Number.isFinite(state.onlineStarted) : board(state.solution) && state.solution.every(n => n > 0));
    }
    function load(storage, now = Date.now()) {
        try {
            const state = JSON.parse(storage.getItem(KEY) || 'null');
            if (!valid(state)) return null;
            if (state.onlineRun && state.onlineRun.expiresAt <= now) { storage.removeItem(KEY); return null; }
            state.history = Array.isArray(state.history) ? state.history.filter(s => board(s.values) && notes(s.notes)).slice(-100) : [];
            return state;
        } catch { return null; }
    }
    function save(storage, state) {
        try { storage.setItem(KEY, JSON.stringify({ ...state, version: 1 })); return true; }
        catch { return false; }
    }
    function preferences(storage, value) {
        try {
            if (value) storage.setItem(PREFERENCES, JSON.stringify(value));
            const data = value || JSON.parse(storage.getItem(PREFERENCES) || '{}');
            return { difficulty: levels.includes(data.difficulty) ? data.difficulty : 'normal', mode: data.mode === 'personal' ? 'personal' : 'online' };
        } catch { return { difficulty: 'normal', mode: 'online' }; }
    }
    const api = { load, save, preferences };
    if (typeof module !== 'undefined') module.exports = api;
    else root.SudokuSession = api;
})(globalThis);
