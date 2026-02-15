/**
 * 입력, 난이도 선택, 재시작, 게임 시작
 */
window.addEventListener('keydown', (e) => {
    if (e.key === ' ') {
        e.preventDefault();
        if (!levelUpPaused && gameRunning) gamePaused = !gamePaused;
        return;
    }
    if (e.key === 'z' || e.key === 'Z') {
        e.preventDefault();
        if (gameRunning && !gamePaused && !levelUpPaused && !ultimateActive && ultimateCooldown <= 0) {
            ultimateActive = true;
            ultimateTimer = ULTIMATE_DURATION;
            ultimateCooldown = ULTIMATE_COOLDOWN;
            ultimateWaves = [];
        }
        return;
    }
    keys[e.key] = true;
});
window.addEventListener('keyup', (e) => {
    keys[e.key] = false;
    if (levelUpPaused) {
        if (['1', '2', '3', '4'].includes(e.key)) {
            const idx = parseInt(e.key, 10) - 1;
            if (idx < pendingLevelUpChoices.length) applyLevelUpChoice(idx);
        }
        else if (e.key === '5') { pendingLevelUpChoices = []; levelUpPaused = false; }
    }
});

document.querySelectorAll('.overlay-diff').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.overlay-diff').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        currentDifficulty = btn.dataset.diff;
    });
});

const characterSelectOverlay = document.getElementById('characterSelectOverlay');
const difficultyDisplay = document.getElementById('difficultyDisplay');
const characterCardsEl = document.getElementById('characterCards');
if (characterCardsEl) {
    characterCardsEl.innerHTML = CHARACTERS.map((c, i) => {
        const img = new Image();
        img.src = c.image;
        return `<div class="character-card" data-index="${i}">
            <img class="char-thumb" src="${c.image}" alt="${c.name}">
            <div class="char-name">${c.name}</div>
            <div class="char-trait">${c.trait || ''}</div>
            <button type="button" class="char-start-btn" data-index="${i}">게임 시작</button>
        </div>`;
    }).join('');
    characterCardsEl.querySelectorAll('.character-card .char-start-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const idx = parseInt(btn.dataset.index, 10);
            selectedCharacter = idx;
            playerImage.src = CHARACTERS[idx].image;
            if (difficultyDisplay) difficultyDisplay.textContent = '난이도: ' + DIFFICULTY[currentDifficulty].name;
            characterSelectOverlay.classList.remove('show');
            gameRunning = true;
            initWeapons();
            applyCharacterTraits();
            gameLoop();
        });
    });
}

function applyCharacterTraits() {
    const c = CHARACTERS[selectedCharacter];
    if (!c) return;
    const mainWeapon = weapons.find(w => w.type === 'projectile' || w.type === 'sword');
    if (mainWeapon) {
        if (mainWeapon.type === 'projectile') {
            mainWeapon.damage = 1 + (c.damageBonus != null ? c.damageBonus : 0);
            mainWeapon.maxCooldown = Math.max(8, 30 + (c.cooldownBonus != null ? c.cooldownBonus : 0));
        }
        if (mainWeapon.type === 'sword') {
            mainWeapon.damage = 3 + (c.damageBonus != null ? c.damageBonus : 0);
            mainWeapon.maxCooldown = Math.max(20, 50 + (c.cooldownBonus != null ? c.cooldownBonus : 0));
        }
    }
    player.maxHp = c.maxHp != null ? c.maxHp : 5;
    player.speed = 5 + (c.speedBonus != null ? c.speedBonus : 0);
    player.hp = player.maxHp;
    if (selectedCharacter === 1) {
        player.knockbackPower = player.knockbackPower != null && player.knockbackPower > 0 ? player.knockbackPower : 8;
    } else {
        player.knockbackPower = 0;
    }
}

function goToMenu() {
    gameRunning = false;
    window.location.href = 'index.html';
}

const menuBtn = document.getElementById('menuBtn');
if (menuBtn) menuBtn.addEventListener('click', goToMenu);
const overlayMenuBtn = document.getElementById('overlayMenuBtn');
if (overlayMenuBtn) overlayMenuBtn.addEventListener('click', goToMenu);

function resetToInitial() {
    gameRunning = false;
    gamePaused = false;
    score = 0;
    gameTime = 0;
    level = 1;
    expCurrent = 0;
    expToNextLevel = 10;
    levelUpPaused = false;
    pendingLevelUpChoices = [];
    lastBossWave = 0;
    bossClearedTimer = 0;
    monsters.length = 0;
    bossMissiles.length = 0;
    expOrbs.length = 0;
    heartPickups.length = 0;
    weapons.length = 0;
    player.x = canvas.width / 2;
    player.y = canvas.height / 2;
    player.hp = player.maxHp;
    player.invincible = false;
    player.invincibleTimer = 0;
    player.knockbackVx = 0;
    player.knockbackVy = 0;
    player.knockbackPower = 0;
    ultimateActive = false;
    ultimateTimer = 0;
    ultimateCooldown = 0;
    ultimateWaves = [];
    initWeapons();
    document.getElementById('gameOver').classList.remove('show');
    const gameWinEl = document.getElementById('gameWin');
    if (gameWinEl) { gameWinEl.style.display = 'none'; gameWinEl.classList.remove('show'); }
    gameWon = false;
    if (difficultyDisplay) difficultyDisplay.textContent = '';
    characterSelectOverlay.classList.add('show');
}

const exitBtn = document.getElementById('exitBtn');
if (exitBtn) exitBtn.addEventListener('click', resetToInitial);

document.getElementById('restartBtn').addEventListener('click', () => {
    gameRunning = true;
    score = 0;
    gameTime = 0;
    level = 1;
    expCurrent = 0;
    expToNextLevel = 10;
    levelUpPaused = false;
    pendingLevelUpChoices = [];
    lastBossWave = 0;
    bossClearedTimer = 0;
    monsters.length = 0;
    bossMissiles.length = 0;
    expOrbs.length = 0;
    heartPickups.length = 0;
    weapons.length = 0;
    player.x = canvas.width / 2;
    player.y = canvas.height / 2;
    player.invincible = false;
    player.invincibleTimer = 0;
    player.knockbackVx = 0;
    player.knockbackVy = 0;
    ultimateActive = false;
    ultimateTimer = 0;
    ultimateCooldown = 0;
    ultimateWaves = [];
    gameWon = false;
    const gameWinEl = document.getElementById('gameWin');
    if (gameWinEl) { gameWinEl.style.display = 'none'; gameWinEl.classList.remove('show'); }
    playerImage.src = CHARACTERS[selectedCharacter].image;
    initWeapons();
    applyCharacterTraits();
    document.getElementById('gameOver').classList.remove('show');
    gameLoop();
});

const winMenuBtn = document.getElementById('winMenuBtn');
if (winMenuBtn) winMenuBtn.addEventListener('click', goToMenu);
const winRestartBtn = document.getElementById('winRestartBtn');
if (winRestartBtn) winRestartBtn.addEventListener('click', () => document.getElementById('restartBtn').click());

initWeapons();
