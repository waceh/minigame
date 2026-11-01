(() => {
    'use strict';
    const $ = id => document.getElementById(id);
    const { peers, generate } = window.SudokuEngine;
    let puzzle, solution, values, notes, selected = 0, pencil = false, history = [], errors = new Set(), won = false, elapsed = 0, lastTick = Date.now();
    let gameDifficulty = 'normal', hintsUsed = 0, checksUsed = 0;
    let pendingRecord = null;
    let onlineRun = null, loading = false, onlineStarted = 0;
    let recordPublished = false;
    function persist() {
        if (!values || loading) return;
        const state = { puzzle, solution, values, notes, selected, pencil, history: history.slice(-100), elapsed,
            gameDifficulty, hintsUsed, checksUsed, onlineRun, onlineStarted, won, pendingRecord, recordPublished,
            recordName: $('record-name').value };
        let saved = false;
        try { saved = window.SudokuSession.save(window.localStorage, state); } catch {}
        $('session-status').textContent = saved ? '진행 자동 저장 · 새로고침해도 이어하기' : '자동 저장을 사용할 수 없습니다. 브라우저의 사이트 저장 권한을 확인해 주세요.';
    }
    function savePreferences() {
        try { window.SudokuSession.preferences(window.localStorage, { difficulty: $('difficulty').value, mode: $('game-mode').value }); } catch {}
    }
    $('difficulty').onchange = savePreferences;
    $('game-mode').onchange = savePreferences;
    $('record-name').addEventListener('input', persist);
    function restore() {
        let state;
        try {
            const preferences = window.SudokuSession.preferences(window.localStorage);
            $('difficulty').value = preferences.difficulty; $('game-mode').value = preferences.mode;
            state = window.SudokuSession.load(window.localStorage);
        } catch { return false; }
        if (!state) return false;
        ({ puzzle, solution, values, notes, selected, pencil, history, elapsed, gameDifficulty, hintsUsed, checksUsed, onlineRun, onlineStarted } = state);
        won = Boolean(state.won); recordPublished = Boolean(state.recordPublished);
        pendingRecord = won && state.pendingRecord && state.pendingRecord.token === onlineRun?.token ? state.pendingRecord : null;
        $('difficulty').value = gameDifficulty; $('game-mode').value = onlineRun ? 'online' : 'personal';
        $('online-difficulty').value = gameDifficulty;
        $('record-name').value = typeof state.recordName === 'string' ? state.recordName.slice(0, 20) : '플레이어';
        lastTick = Date.now(); updateTimer();
        if (won) {
            showCompletion();
            if (recordPublished) { $('save-record').disabled = true; $('save-status').textContent = '등록한 완료 기록입니다.'; }
        }
        message(won ? '완료한 게임을 불러왔습니다. 새 게임으로 다시 도전할 수 있습니다.' : `${labels[gameDifficulty]} 게임을 이어서 진행합니다. 입력과 메모를 복원했습니다.`);
        render();
        return true;
    }
    let rankingRequest = 0;
    async function renderOnlineRanking() {
        const requestId = ++rankingRequest;
        $('online-status').textContent = '순위를 불러오는 중…';
        $('online-rows').replaceChildren();
        try {
            const data = await window.SudokuOnline.request(`/rankings?difficulty=${$('online-difficulty').value}`);
            if (requestId !== rankingRequest) return;
            data.records.forEach((record, i) => {
                const row = document.createElement('tr');
                for (const text of [i + 1, record.name, formatTime(record.elapsed), new Date(record.completedAt).toLocaleDateString('ko-KR')]) {
                    const cell = document.createElement('td'); cell.textContent = text; row.append(cell);
                }
                $('online-rows').append(row);
            });
            $('online-status').textContent = data.records.length ? '서버에서 확인한 완료 기록입니다.' : '아직 기록이 없습니다. 첫 번째 기록에 도전하세요!';
        } catch (error) { if (requestId === rankingRequest) $('online-status').textContent = error.message; }
    }
    $('online-refresh').onclick = renderOnlineRanking;
    $('online-difficulty').onchange = renderOnlineRanking;
    async function verifyOnline(record) {
        const result = await window.SudokuOnline.request(`/${record.token}/finish`, { values: record.values });
        record.elapsed = result.elapsed; record.completedAt = result.completedAt;
        if (pendingRecord === record) {
            elapsed = result.elapsed;
            $('timer').textContent = formatTime(result.elapsed);
            $('finish-summary').textContent = `${labels[record.difficulty]} · 온라인 ${formatTime(result.elapsed)} (서버 확인)`;
            persist();
        }
    }
    const labels = { easy: '쉬움', normal: '보통', hard: '어려움' };
    function formatTime(ms) {
        const seconds = Math.floor(ms / 1000);
        return `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
    }
    $('record-form').onsubmit = async event => {
        event.preventDefault();
        if (!pendingRecord?.token || $('save-record').disabled) return;
        const name = $('record-name').value.trim().slice(0, 20);
        if (!name) { $('save-status').textContent = '기록에 남길 이름을 입력하세요.'; return; }
        if (pendingRecord.token) {
            const record = pendingRecord;
            $('save-record').disabled = true;
            $('save-status').textContent = '서버에 기록을 저장하는 중…';
            try {
                await verifyOnline(record);
                const result = await window.SudokuOnline.request(`/${record.token}/publish`, { name });
                if (pendingRecord !== record) return;
                recordPublished = true;
                $('save-status').textContent = result.rank ? `${labels[record.difficulty]} ${result.rank}위로 등록했습니다!` : '완료했습니다. 순위표에는 상위 100개 기록만 보관합니다.';
                $('online-difficulty').value = record.difficulty;
                renderOnlineRanking();
                persist();
            } catch (error) {
                if (pendingRecord === record) { $('save-record').disabled = false; $('save-status').textContent = error.message + ' 기록 저장을 눌러 재시도할 수 있습니다.'; }
            }
            return;
        }
    };
    function updateTimer() {
        const now = Date.now();
        if (!won && onlineRun) elapsed = Math.max(0, now - onlineStarted);
        else if (!won && !document.hidden) elapsed += Math.max(0, now - lastTick);
        lastTick = now;
        const seconds = Math.floor(elapsed / 1000);
        $('timer').textContent = `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
    }
    const cells = Array.from({ length: 81 }, (_, i) => {
        const cell = document.createElement('button');
        cell.className = 'cell';
        cell.type = 'button';
        cell.addEventListener('click', () => { selected = i; render(); });
        $('board').append(cell);
        return cell;
    });
    function message(text) { $('message').textContent = text; }
    function render() {
        if (!values) {
            cells.forEach(cell => { cell.disabled = true; });
            for (const id of ['notes', 'erase', 'undo', 'check', 'hint']) $(id).disabled = true;
            $('numbers').querySelectorAll('button').forEach(button => { button.disabled = true; });
            return;
        }
        cells.forEach((cell, i) => {
            cell.disabled = loading;
            cell.className = 'cell' + (puzzle[i] ? ' given' : '') + (peers(i, selected) ? ' related' : '') +
                (values[selected] && values[i] === values[selected] ? ' same' : '') + (i === selected ? ' selected' : '') + (errors.has(i) ? ' error' : '');
            cell.replaceChildren();
            if (values[i]) cell.textContent = values[i];
            else if (notes[i].length) {
                const grid = document.createElement('span'); grid.className = 'pencil';
                for (let n = 1; n <= 9; n++) { const mark = document.createElement('span'); mark.textContent = notes[i].includes(n) ? n : ''; grid.append(mark); }
                cell.append(grid);
            }
            cell.tabIndex = i === selected ? 0 : -1;
            cell.setAttribute('aria-label', `${Math.floor(i / 9) + 1}행 ${i % 9 + 1}열, ${values[i] || '빈칸'}${puzzle[i] ? ', 고정 숫자' : ''}${!values[i] && notes[i].length ? ', 메모 ' + notes[i].join(' ') : ''}${errors.has(i) ? ', 오답' : ''}`);
        });
        $('progress').textContent = `${values.filter(Boolean).length} / 81`;
        $('notes').setAttribute('aria-pressed', String(pencil));
        $('undo').disabled = !history.length || won || loading;
        for (const id of ['notes', 'erase', 'check', 'hint']) $(id).disabled = won || loading || (Boolean(onlineRun) && ['check', 'hint'].includes(id));
        $('numbers').querySelectorAll('button').forEach(button => { button.disabled = won || loading; });
        persist();
    }
    function snapshot() { history.push({ values: values.slice(), notes: notes.map(n => n.slice()) }); }
    function finishMove() {
        errors.clear();
        updateTimer();
        won = onlineRun ? values.every((v, i) => v >= 1 && v <= 9 && !values.some((n, j) => i !== j && n === v && peers(i, j))) : values.every((v, i) => v === solution[i]);
        if (won) {
            message(`완성! ${$('timer').textContent} 만에 모든 칸을 채웠습니다.${onlineRun ? ' 완료 기록에서 순위를 등록하세요.' : ' 다음에는 기록 경쟁에 도전해 보세요!'}`);
            pendingRecord = { id: `${Date.now()}-${Math.random().toString(36).slice(2)}`, difficulty: gameDifficulty, elapsed: Math.floor(elapsed), hints: hintsUsed, checks: checksUsed, completedAt: Date.now() };
            if (onlineRun) { pendingRecord.token = onlineRun.token; pendingRecord.values = values.slice(); }
            showCompletion();
        }
        render();
    }
    function showCompletion() {
        $('finish-summary').textContent = `${labels[gameDifficulty]} · ${formatTime(elapsed)} · 힌트 ${hintsUsed}회 · 오답 확인 ${checksUsed}회`;
        $('finish-record').hidden = false;
        $('save-record').disabled = !onlineRun;
        $('record-form').hidden = !onlineRun;
        $('save-status').textContent = onlineRun ? '이름을 입력하고 기록 저장을 누르세요.' : '';
        $('record-privacy').textContent = onlineRun ? '이름과 완료 시간이 순위표에 공개됩니다.' : '개인 연습은 순위에 등록되지 않습니다. 기록 경쟁 모드에서 도전하세요.';
        if (onlineRun && pendingRecord && !recordPublished) {
            const record = pendingRecord;
            verifyOnline(record).catch(error => { if (pendingRecord === record && !$('save-record').disabled) $('save-status').textContent = error.message + ' 기록 저장을 눌러 재시도하세요.'; });
        }
    }
    function enter(n) {
        if (won || loading || puzzle[selected]) return;
        if (pencil && n && values[selected]) return;
        if (!pencil && values[selected] === n && (n || !notes[selected].length)) return;
        snapshot();
        if (pencil && n) {
            notes[selected] = notes[selected].includes(n) ? notes[selected].filter(v => v !== n) : [...notes[selected], n].sort();
        } else {
            values[selected] = n; notes[selected] = [];
            if (n) notes.forEach((list, i) => { if (peers(i, selected)) notes[i] = list.filter(v => v !== n); });
        }
        message(pencil && n ? '후보 숫자를 메모했습니다.' : '같은 줄과 상자에 겹치는 숫자가 없는지 살펴보세요.');
        finishMove();
    }
    for (let n = 1; n <= 9; n++) {
        const button = document.createElement('button'); button.textContent = n; button.setAttribute('aria-label', `${n} 입력`);
        button.addEventListener('click', () => enter(n)); $('numbers').append(button);
    }
    $('notes').onclick = () => { pencil = !pencil; render(); message(pencil ? '메모 모드: 후보 숫자를 입력하세요.' : '숫자 입력 모드입니다.'); };
    $('erase').onclick = () => enter(0);
    $('undo').onclick = () => {
        if (won || !history.length) return;
        ({ values, notes } = history.pop()); errors.clear(); render(); message('이전 입력으로 되돌렸습니다.');
    };
    $('check').onclick = () => {
        checksUsed++;
        errors = new Set(values.flatMap((v, i) => v && v !== solution[i] ? [i] : []));
        message(errors.size ? `오답 ${errors.size}칸을 빨간색으로 표시했습니다.` : '입력한 숫자가 모두 맞습니다. 계속 풀어보세요!'); render();
    };
    $('hint').onclick = () => {
        const i = !puzzle[selected] && values[selected] !== solution[selected] ? selected : values.findIndex((v, j) => v !== solution[j]);
        if (i < 0) return;
        hintsUsed++;
        selected = i; const mode = pencil; pencil = false; enter(solution[i]); pencil = mode;
        if (!won) message(`${Math.floor(i / 9) + 1}행 ${i % 9 + 1}열에 정답을 채웠습니다.`);
        render();
    };
    async function start() {
        if (loading) return;
        loading = true; $('new-game').disabled = true;
        render();
        const difficulty = $('difficulty').value, online = $('game-mode').value === 'online';
        let next;
        try {
            if (online) { message('온라인 퍼즐을 준비하는 중…'); next = await window.SudokuOnline.request('/start', { difficulty }); }
            else next = generate(difficulty);
        } catch (error) {
            loading = false; $('new-game').disabled = false;
            if (values) render();
            else {
                $('game-mode').value = 'personal';
                await start();
            }
            message(error.message + (onlineRun ? '' : ' 개인 연습을 이용하거나 온라인 경쟁으로 다시 시도하세요.'));
            return;
        }
        gameDifficulty = difficulty; puzzle = next.puzzle; solution = next.solution;
        onlineRun = online ? next : null; onlineStarted = Date.now();
        loading = false; $('new-game').disabled = false;
        hintsUsed = 0; checksUsed = 0;
        recordPublished = false; savePreferences();
        $('online-difficulty').value = gameDifficulty;
        renderOnlineRanking();
        pendingRecord = null; $('finish-record').hidden = true;
        values = puzzle.slice(); notes = Array.from({ length: 81 }, () => []); history = []; errors.clear();
        selected = puzzle.indexOf(0); won = false; pencil = false; elapsed = 0; lastTick = Date.now(); $('timer').textContent = '00:00';
        message(onlineRun ? '온라인 경쟁 시작! 힌트 없이 풀고 모두와 기록을 겨뤄보세요.' : '빈칸을 선택하고 숫자를 입력하세요.'); render();
    }
    $('new-game').onclick = () => {
        if (won && pendingRecord && !$('save-record').disabled && !window.confirm('완료 기록을 저장하지 않았습니다. 새 게임을 시작할까요?')) return;
        if (history.length && !won && !window.confirm('현재 진행을 지우고 새 퍼즐을 시작할까요?')) return;
        return start();
    };
    document.addEventListener('keydown', event => {
        if (event.target.closest('select, input, textarea') || event.altKey) return;
        if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'z') { event.preventDefault(); $('undo').click(); return; }
        if (event.ctrlKey || event.metaKey) return;
        // Keep native keyboard activation on the toolbar and navigation links.
        if (!event.target.closest('#board') && event.target !== document.body) return;
        let next = selected, row = Math.floor(selected / 9), col = selected % 9;
        if (event.key === 'ArrowLeft') next = row * 9 + Math.max(0, col - 1);
        else if (event.key === 'ArrowRight') next = row * 9 + Math.min(8, col + 1);
        else if (event.key === 'ArrowUp') next = Math.max(0, row - 1) * 9 + col;
        else if (event.key === 'ArrowDown') next = Math.min(8, row + 1) * 9 + col;
        else if (/^[1-9]$/.test(event.key)) enter(Number(event.key));
        else if (['Backspace', 'Delete', '0'].includes(event.key)) enter(0);
        else if (event.key.toLowerCase() === 'n') $('notes').click();
        else return;
        event.preventDefault(); selected = next; render(); cells[selected].focus();
    });
    setInterval(updateTimer, 1000);
    document.addEventListener('visibilitychange', () => { lastTick = Date.now(); persist(); });
    window.addEventListener('pagehide', () => { updateTimer(); persist(); });
    if (restore()) renderOnlineRanking();
    else start();
})();
