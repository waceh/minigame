(() => {
    'use strict';
    const $ = id => document.getElementById(id);
    const { peers, generate } = window.SudokuEngine;
    let puzzle, solution, values, notes, selected = 0, pencil = false, history = [], errors = new Set(), won = false, elapsed = 0, lastTick = Date.now();
    let gameDifficulty = 'normal', hintsUsed = 0, checksUsed = 0;
    let pendingRecord = null;
    let onlineRun = null, loading = false, onlineStarted = 0;
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
        }
    }
    const labels = { easy: '쉬움', normal: '보통', hard: '어려움' };
    function formatTime(ms) {
        const seconds = Math.floor(ms / 1000);
        return `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
    }
    function renderRanking() {
        $('ranking-rows').replaceChildren();
        try {
            const ranked = window.SudokuRecords.ranking(window.SudokuRecords.read(window.localStorage), $('ranking-difficulty').value, $('ranking-mode').value === 'assisted');
            ranked.slice(0, 10).forEach((record, i) => {
                const row = document.createElement('tr');
                for (const text of [i + 1, record.name, formatTime(record.elapsed), record.hints || record.checks ? `힌트 ${record.hints} · 확인 ${record.checks}` : '없음', new Date(record.completedAt).toLocaleDateString('ko-KR', { month: 'numeric', day: 'numeric' })]) {
                    const cell = document.createElement('td'); cell.textContent = text; row.append(cell);
                }
                $('ranking-rows').append(row);
            });
            $('ranking-status').textContent = ranked.length ? `${ranked.length}개 기록 중 상위 10개를 표시합니다.` : '아직 기록이 없습니다. 퍼즐을 완성해 첫 기록을 남겨보세요.';
        } catch {
            $('ranking-status').textContent = '저장된 기록을 읽을 수 없습니다. 브라우저의 사이트 저장소 설정을 확인해 주세요.';
        }
    }
    $('ranking-difficulty').onchange = renderRanking;
    $('ranking-mode').onchange = renderRanking;
    $('record-form').onsubmit = async event => {
        event.preventDefault();
        if (!pendingRecord || $('save-record').disabled) return;
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
                $('save-status').textContent = result.rank ? `온라인 ${labels[record.difficulty]} ${result.rank}위로 등록했습니다!` : '완료했습니다. 온라인 순위표에는 상위 100개 기록만 보관합니다.';
                $('online-difficulty').value = record.difficulty;
                renderOnlineRanking();
            } catch (error) {
                if (pendingRecord === record) { $('save-record').disabled = false; $('save-status').textContent = error.message + ' 기록 저장을 눌러 재시도할 수 있습니다.'; }
            }
            return;
        }
        try {
            const records = window.SudokuRecords.save(window.localStorage, { ...pendingRecord, name });
            const assisted = Boolean(pendingRecord.hints || pendingRecord.checks);
            const rank = window.SudokuRecords.ranking(records, pendingRecord.difficulty, assisted).findIndex(r => r.id === pendingRecord.id) + 1;
            $('save-record').disabled = true;
            $('ranking-difficulty').value = pendingRecord.difficulty;
            $('ranking-mode').value = assisted ? 'assisted' : 'solo';
            $('save-status').textContent = rank ? `${labels[pendingRecord.difficulty]} · ${assisted ? '도움 사용' : '직접 풀이'} ${rank}위로 저장했습니다!` : '해당 분류의 상위 100개 기록만 보관합니다. 이번 기록은 순위에 들지 못했습니다.';
            renderRanking();
        } catch { $('save-status').textContent = '기록을 저장하지 못했습니다. 저장 공간과 사이트 저장 권한을 확인한 뒤 다시 시도해 주세요.'; }
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
    }
    function snapshot() { history.push({ values: values.slice(), notes: notes.map(n => n.slice()) }); }
    function finishMove() {
        errors.clear();
        updateTimer();
        won = onlineRun ? values.every((v, i) => v >= 1 && v <= 9 && !values.some((n, j) => i !== j && n === v && peers(i, j))) : values.every((v, i) => v === solution[i]);
        if (won) {
            message(`완성! ${$('timer').textContent} 만에 모든 칸을 채웠습니다. 아래에서 순위를 기록하세요.`);
            pendingRecord = { id: `${Date.now()}-${Math.random().toString(36).slice(2)}`, difficulty: gameDifficulty, elapsed: Math.floor(elapsed), hints: hintsUsed, checks: checksUsed, completedAt: Date.now() };
            if (onlineRun) { pendingRecord.token = onlineRun.token; pendingRecord.values = values.slice(); }
            $('finish-summary').textContent = `${labels[gameDifficulty]} · ${formatTime(elapsed)} · 힌트 ${hintsUsed}회 · 오답 확인 ${checksUsed}회`;
            $('finish-record').hidden = false;
            $('save-record').disabled = false;
            $('save-status').textContent = '이름을 입력하고 기록 저장을 누르세요.';
            $('record-privacy').textContent = onlineRun ? '온라인 순위표에 이름과 완료 시간이 공개됩니다.' : '이 브라우저의 개인 순위표에 저장됩니다.';
            if (onlineRun) {
                const record = pendingRecord;
                verifyOnline(record).catch(error => { if (pendingRecord === record && !$('save-record').disabled) $('save-status').textContent = error.message + ' 기록 저장을 눌러 재시도하세요.'; });
            }
        }
        render();
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
    document.addEventListener('visibilitychange', () => { lastTick = Date.now(); });
    window.addEventListener('storage', renderRanking);
    renderRanking();
    renderOnlineRanking();
    start();
})();
