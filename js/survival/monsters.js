/**
 * 몬스터 스폰, 이동, 플레이어 충돌
 */
function getWaveStartSec(waveNum) {
    if (waveNum <= 1) return 0;
    let sec = 0;
    for (let w = 1; w < waveNum; w++) {
        sec += BOSS_WAVES.indexOf(w) >= 0 ? BOSS_WAVE_INTERVAL_SEC : WAVE_INTERVAL_SEC;
    }
    return sec;
}

function getCurrentWave() {
    const totalSec = Math.floor(gameTime / 60);
    for (let w = 1; w <= (typeof MAX_WAVE !== 'undefined' ? MAX_WAVE : 20); w++) {
        if (totalSec < getWaveStartSec(w + 1)) return w;
    }
    return typeof MAX_WAVE !== 'undefined' ? MAX_WAVE : 20;
}

function getEffectiveWave() {
    const currentWave = getCurrentWave();
    return 1 + (currentWave - 1) * 0.4;
}

function spawnMonster() {
    const diff = DIFFICULTY[currentDifficulty];
    const currentWave = getCurrentWave();
    const eff = getEffectiveWave();
    const waveMult = 1 + (eff - 1) * 0.05;
    const side = Math.floor(Math.random() * 4);
    let x, y;
    switch (side) {
        case 0: x = Math.random() * canvas.width; y = -20; break;
        case 1: x = canvas.width + 20; y = Math.random() * canvas.height; break;
        case 2: x = Math.random() * canvas.width; y = canvas.height + 20; break;
        case 3: x = -20; y = Math.random() * canvas.height; break;
    }
    const baseSpeed = (1.2 + (eff - 1) * 0.12) * diff.speedMult * waveMult;
    let health = 1 + Math.floor((eff - 1) / 2) + Math.floor(eff * 0.7);
    let radius = 12 + (eff - 1) * 0.4;
    if (currentWave >= 6) {
        health = Math.floor(health * 1.5);
        radius = radius * 1.25;
    }
    const expValue = health + Math.floor(eff - 1);
    const driftAngle = Math.random() * Math.PI * 2;
    const driftChangeTimer = 15 + Math.floor(Math.random() * 35);
    const hue = 0 + Math.random() * 35;
    monsters.push({
        x, y,
        radius,
        speed: baseSpeed,
        health, maxHealth: health,
        color: `hsl(${hue}, 75%, 45%)`,
        points: health * 10,
        expValue,
        driftAngle,
        driftChangeTimer,
        isBoss: false
    });
}

function spawnBoss(waveNum) {
    const diff = DIFFICULTY[currentDifficulty];
    const side = Math.floor(Math.random() * 4);
    let x, y;
    switch (side) {
        case 0: x = Math.random() * canvas.width; y = -40; break;
        case 1: x = canvas.width + 40; y = Math.random() * canvas.height; break;
        case 2: x = Math.random() * canvas.width; y = canvas.height + 40; break;
        case 3: x = -40; y = Math.random() * canvas.height; break;
    }
    const speedMult = diff.speedMult * 0.7;
    let health, radius, speed;
    if (waveNum >= 20) {
        health = 3250;
        radius = 50;
        speed = 0.75 * speedMult;
    } else if (waveNum >= 15) {
        health = 2250;
        radius = 44;
        speed = 0.85 * speedMult;
    } else if (waveNum >= 10) {
        health = 1375;
        radius = 38;
        speed = 1.0 * speedMult;
    } else {
        health = 500;
        radius = 28;
        speed = 1.3 * speedMult;
    }
    const points = health * 25;
    const expValue = health + 10;
    monsters.push({
        x, y,
        radius,
        speed,
        health, maxHealth: health,
        color: 'hsl(330, 75%, 40%)',
        points,
        expValue,
        driftAngle: Math.random() * Math.PI * 2,
        driftChangeTimer: 20 + Math.floor(Math.random() * 20),
        isBoss: true,
        bossWave: waveNum,
        missileCooldown: 0,
        missileShotCount: 0,
        bossNextBehaviorTimer: 180 + Math.floor(Math.random() * 80),
        bossBehaviorState: '',
        bossBehaviorTimer: 0
    });
}

const BOSS_TELEPORT_WINDUP = 28;
const BOSS_TREMBLE_FRAMES = 48;
const BOSS_DASH_FRAMES = 38;
const BOSS_DASH_SPEED = 9;

function updateBossBehavior(monster) {
    const state = monster.bossBehaviorState || '';
    let timer = monster.bossBehaviorTimer || 0;
    if (state === 'teleport_windup') {
        monster.bossBehaviorTimer = timer - 1;
        if (monster.bossBehaviorTimer <= 0) {
            const margin = 80;
            const angle = Math.random() * Math.PI * 2;
            const dist = margin + Math.random() * (Math.min(canvas.width, canvas.height) * 0.35);
            monster.x = canvas.width / 2 + Math.cos(angle) * dist + (Math.random() - 0.5) * 100;
            monster.y = canvas.height / 2 + Math.sin(angle) * dist + (Math.random() - 0.5) * 100;
            monster.x = Math.max(margin, Math.min(canvas.width - margin, monster.x));
            monster.y = Math.max(margin, Math.min(canvas.height - margin, monster.y));
            monster.bossBehaviorState = '';
            monster.bossNextBehaviorTimer = 200 + Math.floor(Math.random() * 100);
        }
        return true;
    }
    if (state === 'tremble') {
        monster.bossBehaviorTimer = timer - 1;
        monster.shakeX = (Math.random() - 0.5) * 6;
        monster.shakeY = (Math.random() - 0.5) * 6;
        if (monster.bossBehaviorTimer <= 0) {
            const angle = Math.atan2(player.y - monster.y, player.x - monster.x) + (Math.random() - 0.5) * 1.2;
            const sp = BOSS_DASH_SPEED * (0.85 + Math.random() * 0.3);
            monster.bossDashVx = Math.cos(angle) * sp;
            monster.bossDashVy = Math.sin(angle) * sp;
            monster.bossBehaviorState = 'dash';
            monster.bossBehaviorTimer = BOSS_DASH_FRAMES;
            monster.shakeX = 0;
            monster.shakeY = 0;
        }
        return true;
    }
    if (state === 'dash') {
        monster.x += monster.bossDashVx || 0;
        monster.y += monster.bossDashVy || 0;
        monster.x = Math.max(monster.radius, Math.min(canvas.width - monster.radius, monster.x));
        monster.y = Math.max(monster.radius, Math.min(canvas.height - monster.radius, monster.y));
        monster.bossBehaviorTimer = timer - 1;
        if (monster.bossBehaviorTimer <= 0) {
            monster.bossBehaviorState = '';
            monster.bossNextBehaviorTimer = 220 + Math.floor(Math.random() * 80);
        }
        return true;
    }
    monster.bossNextBehaviorTimer = (monster.bossNextBehaviorTimer || 0) - 1;
    if (monster.bossNextBehaviorTimer <= 0) {
        const roll = Math.random();
        if (roll < 0.5) {
            monster.bossBehaviorState = 'teleport_windup';
            monster.bossBehaviorTimer = BOSS_TELEPORT_WINDUP;
        } else {
            monster.bossBehaviorState = 'tremble';
            monster.bossBehaviorTimer = BOSS_TREMBLE_FRAMES;
        }
        return true;
    }
    return false;
}

const BOSS_MISSILE_SPEED = 2.8;
const BOSS_FAST_MISSILE_SPEED = 5.5;
const BOSS_MISSILE_RADIUS = 8;
const BOSS_MISSILE_DAMAGE = 1;

function getBossCooldown(wave) {
    if (wave >= 20) return 45;
    if (wave >= 15) return 55;
    if (wave >= 10) return 70;
    return 85;
}
function getBossRingCount(wave) {
    if (wave >= 20) return 20;
    if (wave >= 15) return 16;
    if (wave >= 10) return 12;
    return 10;
}
function getBossFastChance(wave) {
    if (wave >= 20) return 0.35;
    if (wave >= 15) return 0.3;
    if (wave >= 10) return 0.25;
    return 0.2;
}

function pushBossMissile(monster, vx, vy, speed, radius, damage) {
    const sp = Math.hypot(vx, vy) || 1;
    const mul = (speed || BOSS_MISSILE_SPEED) / sp;
    bossMissiles.push({
        x: monster.x, y: monster.y,
        vx: vx * mul, vy: vy * mul,
        radius: radius || BOSS_MISSILE_RADIUS,
        damage: damage != null ? damage : BOSS_MISSILE_DAMAGE
    });
}

function updateBossMissiles() {
    monsters.forEach((monster) => {
        if (!monster.isBoss || monster.health <= 0) return;
        const wave = monster.bossWave || 5;
        const cooldown = getBossCooldown(wave);
        const ringCount = getBossRingCount(wave);
        const fastChance = getBossFastChance(wave);
        monster.missileCooldown = (monster.missileCooldown || 0) - 1;
        if (monster.missileCooldown <= 0) {
            monster.missileCooldown = cooldown;
            monster.missileShotCount = (monster.missileShotCount || 0) + 1;
            const dx = player.x - monster.x;
            const dy = player.y - monster.y;
            const dist = Math.hypot(dx, dy) || 1;
            const aimX = dx / dist, aimY = dy / dist;
            const isRingAttack = monster.missileShotCount % 3 === 0;
            const rnd = Math.random();
            if (isRingAttack) {
                for (let i = 0; i < ringCount; i++) {
                    const a = (i / ringCount) * Math.PI * 2;
                    pushBossMissile(monster, Math.cos(a), Math.sin(a), BOSS_MISSILE_SPEED);
                }
            } else if (wave >= 20 && rnd < 0.15) {
                for (let i = 0; i < ringCount; i++) {
                    const a = (i / ringCount) * Math.PI * 2;
                    pushBossMissile(monster, Math.cos(a), Math.sin(a), BOSS_MISSILE_SPEED);
                }
                pushBossMissile(monster, aimX, aimY, BOSS_FAST_MISSILE_SPEED);
            } else if ((wave >= 20 && rnd >= 0.15 && rnd < 0.27) || (wave >= 15 && wave < 20 && rnd < 0.12)) {
                const spread = 0.35;
                for (let i = 0; i < 3; i++) {
                    const t = (i - 1) * spread;
                    const perpX = -aimY, perpY = aimX;
                    pushBossMissile(monster, aimX + perpX * t, aimY + perpY * t, BOSS_MISSILE_SPEED);
                }
            } else if ((wave === 10 && rnd < 0.15) || (wave >= 15 && wave < 20 && rnd >= 0.12 && rnd < 0.27) || (wave >= 20 && rnd >= 0.27 && rnd < 0.42)) {
                pushBossMissile(monster, aimX, aimY, BOSS_MISSILE_SPEED);
                pushBossMissile(monster, aimX, aimY, BOSS_MISSILE_SPEED);
            } else {
                const useFast = (wave >= 20 && rnd >= 0.42 && rnd < 0.77) || (wave >= 15 && rnd >= 0.27 && rnd < 0.57) || (wave >= 10 && rnd >= 0.15 && rnd < 0.40) || (wave === 5 && rnd < fastChance);
                pushBossMissile(monster, aimX, aimY, useFast ? BOSS_FAST_MISSILE_SPEED : BOSS_MISSILE_SPEED);
            }
        }
    });
    for (let i = bossMissiles.length - 1; i >= 0; i--) {
        const m = bossMissiles[i];
        m.x += m.vx;
        m.y += m.vy;
        if (m.x < -50 || m.x > canvas.width + 50 || m.y < -50 || m.y > canvas.height + 50) {
            bossMissiles.splice(i, 1);
            continue;
        }
        if (!player.invincible) {
            const d = Math.hypot(m.x - player.x, m.y - player.y);
            if (d < m.radius + player.radius) {
                player.hp--;
                player.invincible = true;
                player.invincibleTimer = INVINCIBLE_DURATION;
                const awayDist = Math.hypot(player.x - m.x, player.y - m.y) || 1;
                player.knockbackVx = (player.knockbackVx || 0) + (player.x - m.x) / awayDist * 4;
                player.knockbackVy = (player.knockbackVy || 0) + (player.y - m.y) / awayDist * 4;
                if (player.hp <= 0) gameOver();
                bossMissiles.splice(i, 1);
            }
        }
    }
}

function updateMonsters() {
    const diff = DIFFICULTY[currentDifficulty];
    const irregularity = diff.irregularity;
    monsters.forEach((monster) => {
        if (monster.knockbackVx != null || monster.knockbackVy != null) {
            const knockMult = monster.isBoss ? 0.1 : 1;
            monster.x += (monster.knockbackVx || 0) * knockMult;
            monster.y += (monster.knockbackVy || 0) * knockMult;
            monster.knockbackVx *= 0.82;
            monster.knockbackVy *= 0.82;
            if (Math.abs(monster.knockbackVx) < 0.15) monster.knockbackVx = 0;
            if (Math.abs(monster.knockbackVy) < 0.15) monster.knockbackVy = 0;
        }
        if (monster.isBoss) updateBossBehavior(monster);
        const skipNormalMove = monster.isBoss && (monster.bossBehaviorState || '').length > 0;
        if (!skipNormalMove) {
            const dx = player.x - monster.x;
            const dy = player.y - monster.y;
            const dist = Math.hypot(dx, dy);
            if (dist > 0) {
                const towardX = dx / dist, towardY = dy / dist;
                monster.driftChangeTimer--;
                if (monster.driftChangeTimer <= 0) {
                    monster.driftAngle += (Math.random() - 0.5) * 2.5;
                    monster.driftChangeTimer = 12 + Math.floor(Math.random() * 28);
                }
                const wobble = Math.sin(monster.driftAngle) * irregularity;
                const perpX = -towardY, perpY = towardX;
                monster.x += (towardX + perpX * wobble) * monster.speed;
                monster.y += (towardY + perpY * wobble) * monster.speed;
            }
        }
        const playerDist = Math.hypot(monster.x - player.x, monster.y - player.y);
        const playerRadius = ultimateActive && selectedCharacter === 0 ? player.radius * 3 : player.radius;
        if (ultimateActive && selectedCharacter === 0 && playerDist < monster.radius + playerRadius) {
            monster.health = 0;
            return;
        }
        if (player.invincible) return;
        if (playerDist < monster.radius + player.radius) {
            player.hp--;
            player.invincible = true;
            player.invincibleTimer = INVINCIBLE_DURATION;
            if (playerDist > 0) {
                const awayX = (player.x - monster.x) / playerDist;
                const awayY = (player.y - monster.y) / playerDist;
                const hitKnockback = 3;
                player.knockbackVx = (player.knockbackVx || 0) + awayX * hitKnockback;
                player.knockbackVy = (player.knockbackVy || 0) + awayY * hitKnockback;
            }
            if (player.hp <= 0) gameOver();
        }
    });
}
