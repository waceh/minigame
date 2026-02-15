/**
 * 사다리 타기 게임 - 라인 개수 선택, 당첨칸 직접 입력
 */
const canvas = document.getElementById('ladderCanvas');
const ctx = canvas.getContext('2d');

const ladderBallImage = new Image();
ladderBallImage.src = 'img/c2.jpg';

const BALL_R = 36;
const VERTICAL_STEP = 3;  // 세로 이동: 프레임당 픽셀 (1.5배 속도, 가로도 동일)

let CANVAS_WIDTH = 800;
let CANVAS_HEIGHT = 500;
let TOP_Y = 50;
let BOTTOM_Y = 450;
let N = 5;
let colWidth = 0;
let rungs = [];
let results = [];
let animating = false;
let disabledColumns = new Set();
let lastPath = null;
let arrivalLabels = {};  // col index -> 선택 번호(1-based), 캔버스 하단에 그림

function getN() {
    return parseInt(document.getElementById('lineCount').value, 10) || 5;
}

function getRungCount() {
    return parseInt(document.getElementById('rungCount').value, 10) || 6;
}

function buildResultInputs() {
    const n = getN();
    const container = document.getElementById('ladderResultOverlay');
    if (!container) return;
    container.innerHTML = '';
    for (let i = 0; i < n; i++) {
        const input = document.createElement('input');
        input.type = 'text';
        input.placeholder = '';
        input.maxLength = 14;
        input.dataset.index = i;
        container.appendChild(input);
    }
}

function getResultsFromInputs() {
    const inputs = document.querySelectorAll('#ladderResultOverlay input');
    const arr = [];
    for (let i = 0; i < inputs.length; i++) {
        const v = (inputs[i].value || '').trim();
        arr.push(v || '');
    }
    return arr;
}

function getColumnFromCanvasXY(canvasX, canvasY) {
    if (canvasY > TOP_Y + 50) return -1;
    const col = Math.round(canvasX / colWidth) - 1;
    if (col < 0 || col >= N) return -1;
    return col;
}

function init() {
    N = getN();
    results = getResultsFromInputs();
    if (results.length !== N) {
        while (results.length < N) results.push('');
        results.length = N;
    }
    CANVAS_HEIGHT = Math.min(700, Math.max(450, window.innerHeight * 0.5));
    CANVAS_WIDTH = Math.min(960, Math.max(560, (window.innerWidth || 800) * 0.88));
    TOP_Y = 50;
    BOTTOM_Y = CANVAS_HEIGHT - 50;
    colWidth = CANVAS_WIDTH / (N + 1);
    canvas.width = CANVAS_WIDTH;
    canvas.height = CANVAS_HEIGHT;

    const overlay = document.getElementById('ladderResultOverlay');
    if (overlay && overlay.parentElement) {
        overlay.style.width = canvas.width + 'px';
        overlay.style.height = canvas.height + 'px';
    }
    const inputs = overlay ? overlay.querySelectorAll('input') : [];
    for (let i = 0; i < inputs.length && i < N; i++) {
        const centerX = colWidth * (i + 1);
        inputs[i].style.left = centerX + 'px';
    }

    disabledColumns.clear();
    lastPath = null;
    rungs = [];
    arrivalLabels = {};
    document.querySelectorAll('#ladderResultOverlay input').forEach(inp => { inp.disabled = false; });
    const lineCountEl = document.getElementById('lineCount');
    const rungCountEl = document.getElementById('rungCount');
    if (lineCountEl) lineCountEl.disabled = false;
    if (rungCountEl) rungCountEl.disabled = false;
    const rungCount = getRungCount();
    const gap = (BOTTOM_Y - TOP_Y) / (rungCount + 1);
    for (let row = 0; row < rungCount; row++) {
        const y = TOP_Y + gap * (row + 1);
        const count = 1 + Math.floor(Math.random() * 2);
        const used = new Set();
        for (let k = 0; k < count; k++) {
            const col = Math.floor(Math.random() * (N - 1));
            if (used.has(col)) continue;
            used.add(col);
            rungs.push({ left: col, right: col + 1, y });
        }
    }
    draw();
}

function getPathSegments(startLine) {
    const sortedRungs = [...rungs].sort((a, b) => a.y - b.y);
    const verticals = [];
    const usedRungs = [];
    let line = startLine;
    let y = TOP_Y;
    for (const rung of sortedRungs) {
        verticals.push({ col: line, y1: y, y2: rung.y });
        if (rung.left === line || rung.right === line) usedRungs.push(rung);
        y = rung.y;
        if (rung.left === line) line = rung.right;
        else if (rung.right === line) line = rung.left;
    }
    verticals.push({ col: line, y1: y, y2: BOTTOM_Y });
    return { verticals, rungs: usedRungs };
}

// pathToHighlight: 지나온 세로 구간(verticals)과 지나온 가로 룽(rungs)만 포함.
// 도착/흡수 후에는 반드시 rungs: [] 로 호출해 가로선 하이라이트 제거.
function draw(ballX, ballY, ballScale, pathToHighlight) {
    ctx.fillStyle = '#1a1a2e';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.strokeStyle = '#7b68ee';
    ctx.lineWidth = 3;
    for (let i = 0; i < N; i++) {
        const x = colWidth * (i + 1);
        ctx.beginPath();
        ctx.moveTo(x, TOP_Y);
        ctx.lineTo(x, BOTTOM_Y);
        ctx.stroke();
    }
    ctx.strokeStyle = '#7b68ee';
    ctx.lineWidth = 4;
    rungs.forEach(({ left, right, y }) => {
        const x1 = colWidth * (left + 1);
        const x2 = colWidth * (right + 1);
        ctx.beginPath();
        ctx.moveTo(x1, y);
        ctx.lineTo(x2, y);
        ctx.stroke();
    });
    if (pathToHighlight) {
        ctx.strokeStyle = '#ff8c00';
        ctx.lineWidth = 5;
        (pathToHighlight.verticals || []).forEach(({ col, y1, y2 }) => {
            const x = colWidth * (col + 1);
            ctx.beginPath();
            ctx.moveTo(x, y1);
            ctx.lineTo(x, y2);
            ctx.stroke();
        });
        (pathToHighlight.rungs || []).forEach(({ left, right, y }) => {
            const x1 = colWidth * (left + 1);
            const x2 = colWidth * (right + 1);
            ctx.beginPath();
            ctx.moveTo(x1, y);
            ctx.lineTo(x2, y);
            ctx.stroke();
        });
    }
    ctx.fillStyle = '#fff';
    ctx.font = 'bold 18px Arial';
    ctx.textAlign = 'center';
    for (let i = 0; i < N; i++) {
        ctx.fillStyle = disabledColumns.has(i) ? 'rgba(150, 150, 150, 0.7)' : '#fff';
        ctx.fillText(i + 1, colWidth * (i + 1), TOP_Y - 18);
    }
    if (ballX != null && ballY != null) {
        const scale = ballScale != null ? ballScale : 1;
        if (scale <= 0) return;
        const r = BALL_R * scale;
        ctx.save();
        ctx.globalAlpha = scale;
        if (ladderBallImage.complete && ladderBallImage.naturalWidth > 0) {
            ctx.beginPath();
            ctx.arc(ballX, ballY, r, 0, Math.PI * 2);
            ctx.closePath();
            ctx.clip();
            ctx.drawImage(ladderBallImage, ballX - r, ballY - r, r * 2, r * 2);
        } else {
            ctx.fillStyle = '#e74c3c';
            ctx.beginPath();
            ctx.arc(ballX, ballY, r, 0, Math.PI * 2);
            ctx.fill();
        }
        ctx.restore();
        ctx.strokeStyle = '#fff';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(ballX, ballY, r, 0, Math.PI * 2);
        ctx.stroke();
    }
    // 도착한 칸: 텍스트박스 위(사다리 쪽)에 선택 번호 + 아래화살표 표시
    const labelY = BOTTOM_Y - 24;
    ctx.fillStyle = '#ffd700';
    ctx.font = 'bold 14px Arial';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    for (let i = 0; i < N; i++) {
        if (arrivalLabels[i] != null) {
            ctx.fillText(arrivalLabels[i] + '번 \u2193', colWidth * (i + 1), labelY);
        }
    }
    ctx.textBaseline = 'alphabetic';
}

function getEndLine(startLine) {
    let line = startLine;
    const sortedRungs = [...rungs].sort((a, b) => a.y - b.y);
    for (const rung of sortedRungs) {
        if (rung.left === line) line = rung.right;
        else if (rung.right === line) line = rung.left;
    }
    return line;
}

function* walkPath(startLine) {
    let line = startLine;
    let x = colWidth * (startLine + 1);
    let y = TOP_Y;
    const sortedRungs = [...rungs].sort((a, b) => a.y - b.y);
    let pathVerticals = [];
    let pathRungs = [];
    let segmentStartY = TOP_Y;
    const pathSoFar = () => ({ verticals: pathVerticals.slice(), rungs: pathRungs.slice() });

    yield { x, y, pathSoFar: pathSoFar() };
    for (const rung of sortedRungs) {
        const targetY = rung.y;
        while (y < targetY - 1) {
            y += VERTICAL_STEP;
            x = colWidth * (line + 1);
            yield { x, y, pathSoFar: pathSoFar() };
        }
        pathVerticals.push({ col: line, y1: segmentStartY, y2: rung.y });
        const fromX = x;
        const actuallyCrossing = rung.left === line || rung.right === line;
        if (rung.left === line) line = rung.right;
        else if (rung.right === line) line = rung.left;
        const toX = colWidth * (line + 1);
        const dist = Math.abs(toX - fromX);
        const horizontalSteps = Math.max(1, Math.ceil(dist / VERTICAL_STEP));
        for (let s = 1; s <= horizontalSteps; s++) {
            x = fromX + (toX - fromX) * s / horizontalSteps;
            yield { x, y, pathSoFar: pathSoFar() };
        }
        if (actuallyCrossing) pathRungs.push(rung);
        segmentStartY = rung.y;
    }
    while (y < BOTTOM_Y - 1) {
        y += VERTICAL_STEP;
        x = colWidth * (line + 1);
        yield { x, y, pathSoFar: pathSoFar() };
    }
    pathVerticals.push({ col: line, y1: segmentStartY, y2: BOTTOM_Y });
    x = colWidth * (line + 1);
    y = BOTTOM_Y;
    yield { x, y, pathSoFar: pathSoFar() };
    const targetY = CANVAS_HEIGHT - 24;
    const absorbSteps = 22;
    for (let s = 1; s <= absorbSteps; s++) {
        const t = s / absorbSteps;
        y = BOTTOM_Y + (targetY - BOTTOM_Y) * t;
        x = colWidth * (line + 1);
        const scale = 1 - t;
        yield { x, y, scale, pathSoFar: pathSoFar() };
    }
}

function runBall(startLine) {
    if (animating) return;
    results = getResultsFromInputs();
    if (results.length !== N) {
        while (results.length < N) results.push('');
        results.length = N;
    }
    const allEmpty = results.every(r => !r.trim());
    if (allEmpty && N > 0) {
        const winIndex = Math.floor(Math.random() * N);
        results = results.map((_, i) => i === winIndex ? '당첨' : '꽝');
        const inputs = document.querySelectorAll('#ladderResultOverlay input');
        results.forEach((val, i) => { if (inputs[i]) inputs[i].value = val; });
    }
    animating = true;
    const lineCountEl = document.getElementById('lineCount');
    const rungCountEl = document.getElementById('rungCount');
    if (lineCountEl) lineCountEl.disabled = true;
    if (rungCountEl) rungCountEl.disabled = true;
    document.querySelectorAll('#ladderResultOverlay input').forEach(inp => {
        inp.classList.remove('ladder-input-glow');
        inp.disabled = true;
    });
    document.getElementById('result').textContent = '';
    const gen = walkPath(startLine);
    const step = () => {
        const v = gen.next();
        if (v.done) {
            const endLine = getEndLine(startLine);
            document.getElementById('result').textContent = '선택: ' + (startLine + 1) + ' → ' + (results[endLine] || '');
            animating = false;
            disabledColumns.add(startLine);
            lastPath = getPathSegments(startLine);
            arrivalLabels[endLine] = startLine + 1;
            draw(null, null, null, { verticals: lastPath.verticals, rungs: lastPath.rungs });
            const inputs = document.querySelectorAll('#ladderResultOverlay input');
            if (inputs[endLine]) {
                inputs[endLine].classList.add('ladder-input-glow');
                setTimeout(() => inputs[endLine].classList.remove('ladder-input-glow'), 2500);
            }
            return;
        }
        draw(v.value.x, v.value.y, v.value.scale, v.value.pathSoFar || null);
        requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
}

function apply() {
    buildResultInputs();
    init();
}

function handleCanvasClick(e) {
    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / rect.width;
    const scaleY = canvas.height / rect.height;
    const x = (e.clientX - rect.left) * scaleX;
    const y = (e.clientY - rect.top) * scaleY;
    const col = getColumnFromCanvasXY(x, y);
    if (col >= 0 && !disabledColumns.has(col)) runBall(col);
}

document.getElementById('lineCount').addEventListener('change', () => {
    buildResultInputs();
    init();
});
document.getElementById('rungCount').addEventListener('change', () => {
    buildResultInputs();
    init();
});

canvas.addEventListener('click', handleCanvasClick);

document.getElementById('ladderApply').addEventListener('click', apply);
document.getElementById('ladderExit').addEventListener('click', () => apply());
document.getElementById('ladderReset').addEventListener('click', () => {
    results = getResultsFromInputs();
    init();
});
document.getElementById('ladderShowWin').addEventListener('click', () => {
    if (animating) return;
    results = getResultsFromInputs();
    if (results.length !== N) {
        while (results.length < N) results.push('');
        results.length = N;
    }
    const allEmpty = results.every(r => !(r || '').trim());
    if (allEmpty && N > 0) {
        const winIndex = Math.floor(Math.random() * N);
        results = results.map((_, i) => i === winIndex ? '당첨' : '꽝');
        const inputs = document.querySelectorAll('#ladderResultOverlay input');
        results.forEach((val, i) => { if (inputs[i]) inputs[i].value = val; });
    }
    const winEndCol = results.findIndex(v => (v || '').trim() === '당첨');
    if (winEndCol < 0) {
        document.getElementById('result').textContent = '당첨이 없습니다.';
        setTimeout(() => { document.getElementById('result').textContent = ''; }, 2000);
        return;
    }
    let startCol = -1;
    for (let i = 0; i < N; i++) {
        if (getEndLine(i) === winEndCol) { startCol = i; break; }
    }
    if (startCol >= 0 && !disabledColumns.has(startCol)) {
        runBall(startCol);
    } else if (startCol >= 0) {
        document.getElementById('result').textContent = '이미 ' + (startCol + 1) + '번을 골랐습니다.';
        setTimeout(() => { document.getElementById('result').textContent = ''; }, 2000);
    }
});

apply();
