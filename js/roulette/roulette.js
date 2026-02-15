/**
 * 룰렛 뽑기 - 이름*개수 입력, 셔플 후 당첨자 표시 (Marble Roulette 스타일)
 */
const canvas = document.getElementById('rouletteCanvas');
const ctx = canvas.getContext('2d');
const inputEl = document.getElementById('rouletteInput');
const resultEl = document.getElementById('rouletteResult');
const winnerEl = document.getElementById('rouletteWinner');
const startBtn = document.getElementById('rouletteStart');

const CANVAS_SIZE = 380;
const CENTER = CANVAS_SIZE / 2;
const RADIUS = 160;
const COLORS = ['#e74c3c', '#3498db', '#2ecc71', '#f1c40f', '#9b59b6', '#1abc9c', '#e67e22', '#7f8c8d'];

let pool = [];
let currentRotation = 0;
let animating = false;

function parseInput(text) {
    const raw = (text || '')
        .replace(/\r\n/g, '\n')
        .split(/[\n,]/)
        .map(s => s.trim())
        .filter(Boolean);
    const list = [];
    for (const s of raw) {
        if (s.includes('*')) {
            const [name, numStr] = s.split('*').map(t => t.trim());
            const count = Math.max(1, parseInt(numStr, 10) || 1);
            for (let i = 0; i < count; i++) list.push(name || '?');
        } else {
            list.push(s || '?');
        }
    }
    return list;
}

function drawWheel(rotation) {
    ctx.fillStyle = '#1a1a2e';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    const n = pool.length;
    if (n === 0) {
        ctx.fillStyle = '#888';
        ctx.font = '18px Arial';
        ctx.textAlign = 'center';
        ctx.fillText('이름을 입력하고 Shuffle Start를 누르세요', CENTER, CENTER);
        return;
    }

    const segmentAngle = (Math.PI * 2) / n;
    ctx.save();
    ctx.translate(CENTER, CENTER);
    ctx.rotate(rotation);

    for (let i = 0; i < n; i++) {
        const startAngle = i * segmentAngle;
        const endAngle = startAngle + segmentAngle;
        const color = COLORS[i % COLORS.length];
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.arc(0, 0, RADIUS, startAngle, endAngle);
        ctx.closePath();
        ctx.fillStyle = color;
        ctx.fill();
        ctx.strokeStyle = 'rgba(255,255,255,0.4)';
        ctx.lineWidth = 2;
        ctx.stroke();

        const midAngle = startAngle + segmentAngle / 2;
        const textR = RADIUS * 0.65;
        const tx = Math.cos(midAngle) * textR;
        const ty = Math.sin(midAngle) * textR;
        ctx.save();
        ctx.translate(tx, ty);
        ctx.rotate(midAngle + Math.PI / 2);
        ctx.textAlign = 'center';
        ctx.fillStyle = '#fff';
        ctx.font = 'bold 14px Arial';
        const label = pool[i].length > 8 ? pool[i].slice(0, 7) + '…' : pool[i];
        ctx.fillText(label, 0, 4);
        ctx.restore();
    }

    ctx.restore();

    ctx.beginPath();
    ctx.arc(CENTER, CENTER, 20, 0, Math.PI * 2);
    ctx.fillStyle = '#2c3e50';
    ctx.fill();
    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 3;
    ctx.stroke();
}

function easeOutCubic(t) {
    return 1 - Math.pow(1 - t, 3);
}

function spin() {
    if (animating || pool.length === 0) return;
    animating = true;
    startBtn.disabled = true;
    winnerEl.textContent = '';

    const winnerIndex = Math.floor(Math.random() * pool.length);
    const winnerName = String(pool[winnerIndex] ?? '?');
    const segmentAngle = (Math.PI * 2) / pool.length;
    const extraTurns = 5 + Math.random() * 2;
    const twoPi = Math.PI * 2;
    const targetAngle = -Math.PI / 2 - (winnerIndex * segmentAngle + segmentAngle / 2);
    const remainder = ((currentRotation % twoPi) + twoPi) % twoPi;
    const shortDelta = (targetAngle - remainder + twoPi) % twoPi;
    const finalRotation = currentRotation + (extraTurns * twoPi) + shortDelta;

    const duration = 4000;
    const startTime = performance.now();
    const startRot = currentRotation;
    const rotDelta = finalRotation - currentRotation;

    function tick(now) {
        const elapsed = now - startTime;
        const t = Math.min(1, elapsed / duration);
        const eased = easeOutCubic(t);
        currentRotation = startRot + rotDelta * eased;
        drawWheel(currentRotation);

        if (t < 1) {
            requestAnimationFrame(tick);
        } else {
            animating = false;
            startBtn.disabled = false;
            resultEl.textContent = 'The winner is';
            winnerEl.textContent = winnerName;
            winnerEl.classList.add('roulette-winner-show');
        }
    }
    requestAnimationFrame(tick);
}

function init() {
    const text = inputEl.value.trim();
    pool = parseInput(text);
    currentRotation = 0;
    drawWheel(0);
    winnerEl.classList.remove('roulette-winner-show');
    winnerEl.textContent = '';
    resultEl.textContent = pool.length > 0 ? 'The winner is' : '';
}

canvas.width = CANVAS_SIZE;
canvas.height = CANVAS_SIZE;

startBtn.addEventListener('click', spin);
document.getElementById('rouletteReset').addEventListener('click', () => {
    animating = false;
    startBtn.disabled = false;
    init();
});
inputEl.addEventListener('input', () => {
    if (!animating) {
        pool = parseInput(inputEl.value.trim());
        drawWheel(currentRotation);
    }
});

init();
