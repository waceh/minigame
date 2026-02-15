/**
 * 플레이어 입력 이동, 게임 루프, 게임 오버
 */
function updatePlayer() {
    player.x += player.knockbackVx || 0;
    player.y += player.knockbackVy || 0;
    player.knockbackVx *= 0.82;
    player.knockbackVy *= 0.82;
    if (Math.abs(player.knockbackVx) < 0.08) player.knockbackVx = 0;
    if (Math.abs(player.knockbackVy) < 0.08) player.knockbackVy = 0;
    let dx = 0, dy = 0;
    if (keys['ArrowUp'] || keys['w'] || keys['W']) dy -= 1;
    if (keys['ArrowDown'] || keys['s'] || keys['S']) dy += 1;
    if (keys['ArrowLeft'] || keys['a'] || keys['A']) dx -= 1;
    if (keys['ArrowRight'] || keys['d'] || keys['D']) dx += 1;
    if (dx !== 0 && dy !== 0) {
        dx *= 0.707;
        dy *= 0.707;
    }
    const speedMult = ultimateActive && selectedCharacter === 2 ? 2 : 1;
    player.x += dx * player.speed * speedMult;
    player.y += dy * player.speed * speedMult;
    player.x = Math.max(player.radius, Math.min(canvas.width - player.radius, player.x));
    player.y = Math.max(player.radius, Math.min(canvas.height - player.radius, player.y));
}

function gameOver() {
    gameRunning = false;
    if (score > highScore) {
        highScore = score;
        localStorage.setItem('highScore', highScore);
    }
    document.getElementById('finalScore').textContent = score;
    document.getElementById('gameOver').classList.add('show');
}

function gameWin() {
    gameRunning = false;
    if (score > highScore) {
        highScore = score;
        localStorage.setItem('highScore', highScore);
    }
    const winEl = document.getElementById('gameWin');
    if (winEl) {
        const span = document.getElementById('winScore');
        if (span) span.textContent = score;
        winEl.style.display = 'block';
        winEl.classList.add('show');
    }
}

function gameLoop() {
    if (!gameRunning) return;
    if (!gamePaused && !levelUpPaused) gameTime++;
    if (player.invincible) {
        player.invincibleTimer--;
        if (player.invincibleTimer <= 0) player.invincible = false;
    }
    if (ultimateCooldown > 0) ultimateCooldown--;
    if (ultimateActive) {
        ultimateTimer--;
        if (ultimateTimer <= 0) {
            ultimateActive = false;
            ultimateWaves = [];
        } else {
            if (selectedCharacter === 1) {
                if (ultimateTimer % 20 === 0) {
                    ultimateWaves.push({ x: player.x, y: player.y, radius: 0, maxRadius: 350, speed: 8, damage: 3 });
                }
                for (let i = ultimateWaves.length - 1; i >= 0; i--) {
                    const wave = ultimateWaves[i];
                    wave.radius += wave.speed;
                    if (wave.radius >= wave.maxRadius) {
                        ultimateWaves.splice(i, 1);
                        continue;
                    }
                    monsters.forEach(monster => {
                        const dist = Math.hypot(monster.x - wave.x, monster.y - wave.y);
                        const prevDist = dist - wave.speed;
                        if (prevDist < wave.radius && dist >= wave.radius - wave.speed && dist <= wave.radius + 10) {
                            monster.health -= wave.damage;
                        }
                    });
                }
            }
        }
    }
    if (bossClearedTimer > 0) {
        bossClearedTimer--;
        if (bossClearedTimer <= 0) {
            const nextWave = getCurrentWave() + 1;
            const nextWaveStartSec = getWaveStartSec(nextWave);
            gameTime = nextWaveStartSec * 60;
        }
    }
    if (!gamePaused && !levelUpPaused) {
        updatePlayer();
        monsterSpawnTimer++;
        if (monsterSpawnTimer >= monsterSpawnRate) {
            monsterSpawnTimer = 0;
            const currentWave = getCurrentWave();
            const isBossWave = BOSS_WAVES.indexOf(currentWave) >= 0;
            if (isBossWave) {
                if (currentWave === 5 && lastBossWave < 5) { spawnBoss(5); lastBossWave = 5; }
                else if (currentWave === 10 && lastBossWave < 10) { spawnBoss(10); lastBossWave = 10; }
                else if (currentWave === 15 && lastBossWave < 15) { spawnBoss(15); lastBossWave = 15; }
                else if (currentWave === 20 && lastBossWave < 20) { spawnBoss(20); lastBossWave = 20; }
            } else {
                const eff = getEffectiveWave();
                const spawnCount = 1 + Math.floor(eff - 1);
                for (let i = 0; i < spawnCount; i++) spawnMonster();
            }
        }
        if (typeof MAX_WAVE !== 'undefined' && getCurrentWave() > MAX_WAVE && !gameWon) {
            gameWon = true;
            gameWin();
        }
        const diff = DIFFICULTY[currentDifficulty];
        const eff = getEffectiveWave();
        const baseRate = Math.max(20, 60 - (eff - 1) * 6);
        monsterSpawnRate = Math.max(12, Math.floor(baseRate / diff.spawnMult));
        updateWeapons();
        updateMonsters();
        updateBossMissiles();
        updateExpOrbs();
        updateHeartPickups();
    }
    draw();
    document.getElementById('score').textContent = score;
    document.getElementById('highScore').textContent = highScore;
    requestAnimationFrame(gameLoop);
}
