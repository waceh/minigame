(() => {
    'use strict';
    // Set this origin after deploying the existing server/ Worker.
    const SUDOKU_PRODUCTION_SERVER = 'https://minigame-card-duel.minigame-card-duel-server.workers.dev';
    const base = SUDOKU_PRODUCTION_SERVER;
    async function request(path, body) {
        if (!base) throw Error('온라인 서버 연결이 아직 설정되지 않았습니다.');
        let response;
        try {
            response = await fetch(base + '/api/sudoku' + path, { method: body ? 'POST' : 'GET', headers: body ? { 'Content-Type': 'application/json' } : {}, body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(15000) });
        } catch { throw Error('온라인 서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.'); }
        const data = await response.json();
        if (!response.ok) throw Error(data.message || '요청을 처리하지 못했습니다.');
        return data;
    }
    window.SudokuOnline = { request };
})();
