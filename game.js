// Canvas 설정
const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');

// Canvas 크기 설정
canvas.width = 800;
canvas.height = 600;

// 게임 상태
let gameRunning = true;
let score = 0;
let highScore = localStorage.getItem('highScore') || 0;
let gameTime = 0;
let level = 1;
let expCurrent = 0;
let expToNextLevel = 10;
let levelUpPaused = false; // 레벨업 선택 중에는 일시정지

// 플레이어
const player = {
    x: canvas.width / 2,
    y: canvas.height / 2,
    radius: 15,
    speed: 5,
    color: '#4ecdc4',
    maxHp: 3,
    hp: 3,
    invincible: false,
    invincibleTimer: 0,
    magnetRadius: 100
};

// 입력 처리
const keys = {};
window.addEventListener('keydown', (e) => {
    keys[e.key] = true;
});
window.addEventListener('keyup', (e) => {
    keys[e.key] = false;
    if (levelUpPaused) {
        if (['1', '2', '3'].includes(e.key)) applyLevelUpChoice(parseInt(e.key, 10) - 1);
        else if (e.key === '5') { pendingLevelUpChoices = []; levelUpPaused = false; }
    }
});

// 무기 시스템
const weapons = [];
let weaponLevel = 1;

// 난이도 (이지 / 노멀 / 하드)
const DIFFICULTY = {
    easy:   { name: '이지',   speedMult: 0.7,  spawnMult: 0.6,  irregularity: 0.2  },
    normal: { name: '노멀',   speedMult: 1.2,  spawnMult: 1,    irregularity: 0.5  },
    hard:   { name: '하드',   speedMult: 1.8,  spawnMult: 1.4,  irregularity: 0.9  }
};
let currentDifficulty = 'normal';

// 몬스터 배열
const monsters = [];
let monsterSpawnTimer = 0;
let monsterSpawnRate = 60;

// 경험치 구슬 배열
const expOrbs = [];

// 피 회복 하트 (몬스터 처치 시 낮은 확률로만 드롭)
const heartPickups = [];
const HEART_DROP_CHANCE = 0.015;

// 보조무기 타입 (하나만 보유 가능)
const SUPPLEMENTARY_TYPES = ['whip', 'orbit', 'shotgun', 'boomerang', 'laser'];
const SUPPLEMENTARY_NAMES = { whip: '휩', orbit: '오비트', shotgun: '샷건', boomerang: '부메랑', laser: '레이저' };

function setSupplementaryWeapon(type) {
    if (getCurrentSupplementary() === type) {
        upgradeSupplementaryWeapon();
        return;
    }
    for (let i = weapons.length - 1; i >= 0; i--) {
        if (SUPPLEMENTARY_TYPES.includes(weapons[i].type)) weapons.splice(i, 1);
    }
    if (type === 'whip') addWhipWeapon();
    else if (type === 'orbit') addOrbitWeapon();
    else if (type === 'shotgun') addShotgunWeapon();
    else if (type === 'boomerang') addBoomerangWeapon();
    else if (type === 'laser') addLaserWeapon();
}

function getCurrentSupplementary() {
    const w = weapons.find(w => SUPPLEMENTARY_TYPES.includes(w.type));
    return w ? w.type : null;
}

function getSupplementaryWeapon() {
    return weapons.find(w => SUPPLEMENTARY_TYPES.includes(w.type)) || null;
}

// 레벨업 시 보조무기 강화
function upgradeSupplementaryWeapon() {
    const w = weapons.find(weapon => SUPPLEMENTARY_TYPES.includes(weapon.type));
    if (!w) return;
    w.level = (w.level || 1) + 1;
    w.damage = (w.damage || 1) + 0.4;
    if (w.maxCooldown != null) w.maxCooldown = Math.max(15, (w.maxCooldown || 60) - 2);
    if (w.type === 'whip') w.range = Math.min(120, (w.range || 80) + 4);
    if (w.type === 'orbit') {
        if ((w.orbAngles && w.orbAngles.length) < 4) {
            const n = (w.orbAngles ? w.orbAngles.length : 1) + 1;
            w.orbAngles = Array.from({ length: n }, (_, i) => (i * (Math.PI * 2 / n)) % (Math.PI * 2));
        } else {
            w.radius = Math.min(75, (w.radius || 55) + 3);
            w.orbRadius = Math.min(14, (w.orbRadius || 10) + 0.5);
        }
    }
    if (w.type === 'laser') w.range = Math.min(220, (w.range || 150) + 10);
    if (w.type === 'boomerang') w.maxDist = Math.min(180, (w.maxDist || 120) + 8);
}

// 레벨업 선택지 (뱀서 스타일)
function getLevelUpOptions() {
    const opts = [
        { id: 'damage', name: '공격력 +1', apply: () => { weapons.forEach(w => w.damage += 1); } },
        { id: 'cooldown', name: '공격 속도 ↑', apply: () => { weapons.forEach(w => w.maxCooldown = Math.max(8, w.maxCooldown - 3)); } },
        { id: 'speed', name: '이동 속도 ↑', apply: () => { player.speed += 0.5; } },
        { id: 'maxHp', name: '최대 체력 +1', apply: () => { player.maxHp++; player.hp = player.maxHp; } },
        { id: 'magnet', name: '경험치 끌어당김 ↑', apply: () => { player.magnetRadius += 25; } }
    ];
    const sub = getCurrentSupplementary();
    if (sub) {
        opts.push({
            id: 'subUpgrade',
            name: `보조강화: ${SUPPLEMENTARY_NAMES[sub]} ↑`,
            detail: '데미지·쿨감소·사거리/범위 상승',
            apply: () => { upgradeSupplementaryWeapon(); }
        });
    }
    opts.push({ id: 'whip', name: '보조: 휩', apply: () => { setSupplementaryWeapon('whip'); } });
    opts.push({ id: 'orbit', name: '보조: 오비트', apply: () => { setSupplementaryWeapon('orbit'); } });
    opts.push({ id: 'shotgun', name: '보조: 샷건', apply: () => { setSupplementaryWeapon('shotgun'); } });
    opts.push({ id: 'boomerang', name: '보조: 부메랑', apply: () => { setSupplementaryWeapon('boomerang'); } });
    opts.push({ id: 'laser', name: '보조: 레이저', apply: () => { setSupplementaryWeapon('laser'); } });
    return opts;
}
let pendingLevelUpChoices = [];

// 무기 초기화 (기본 투사체)
function initWeapons() {
    weapons.length = 0;
    weapons.push({
        type: 'projectile',
        damage: 1,
        speed: 8,
        cooldown: 0,
        maxCooldown: 30,
        projectiles: []
    });
}

// 휩 무기 (근접 범위 공격)
function addWhipWeapon() {
    if (weapons.some(w => w.type === 'whip')) return;
    weapons.push({
        type: 'whip',
        level: 1,
        damage: 2,
        cooldown: 0,
        maxCooldown: 90,
        range: 80,
        arcAngle: Math.PI * 0.6,
        swingTimer: 0
    });
}

// 오비트 (플레이어 주위 회전 구체, 접촉 시 데미지)
function addOrbitWeapon() {
    if (weapons.some(w => w.type === 'orbit')) return;
    weapons.push({
        type: 'orbit',
        level: 1,
        damage: 1,
        cooldown: 0,
        radius: 55,
        orbAngles: [0],
        orbRadius: 10,
        speed: 0.08
    });
}

// 샷건 (3발 부채꼴 발사)
function addShotgunWeapon() {
    if (weapons.some(w => w.type === 'shotgun')) return;
    weapons.push({
        type: 'shotgun',
        level: 1,
        damage: 1,
        speed: 7,
        cooldown: 0,
        maxCooldown: 45,
        projectiles: []
    });
}

// 부메랑 (날아갔다 돌아옴)
function addBoomerangWeapon() {
    if (weapons.some(w => w.type === 'boomerang')) return;
    weapons.push({
        type: 'boomerang',
        level: 1,
        damage: 2,
        speed: 6,
        cooldown: 0,
        maxCooldown: 75,
        maxDist: 120,
        projectiles: []
    });
}

// 레이저 (바라보는 방향 직선 빔)
function addLaserWeapon() {
    if (weapons.some(w => w.type === 'laser')) return;
    weapons.push({
        type: 'laser',
        level: 1,
        damage: 0.5,
        cooldown: 0,
        maxCooldown: 8,
        range: 150,
        beamTimer: 0
    });
}

// 플레이어 이동
function updatePlayer() {
    let dx = 0;
    let dy = 0;

    if (keys['ArrowUp'] || keys['w'] || keys['W']) dy -= 1;
    if (keys['ArrowDown'] || keys['s'] || keys['S']) dy += 1;
    if (keys['ArrowLeft'] || keys['a'] || keys['A']) dx -= 1;
    if (keys['ArrowRight'] || keys['d'] || keys['D']) dx += 1;

    // 대각선 이동 정규화
    if (dx !== 0 && dy !== 0) {
        dx *= 0.707;
        dy *= 0.707;
    }

    player.x += dx * player.speed;
    player.y += dy * player.speed;

    // 경계 체크
    player.x = Math.max(player.radius, Math.min(canvas.width - player.radius, player.x));
    player.y = Math.max(player.radius, Math.min(canvas.height - player.radius, player.y));
}

// 무기 업데이트
function updateWeapons() {
    weapons.forEach(weapon => {
        if (weapon.type === 'whip') {
            weapon.cooldown--;
            if (weapon.swingTimer > 0) weapon.swingTimer--;
            if (weapon.cooldown <= 0) {
                weapon.cooldown = weapon.maxCooldown;
                weapon.swingTimer = 15;
                const moveAngle = getPlayerLastMoveAngle();
                monsters.forEach(monster => {
                    const dx = monster.x - player.x;
                    const dy = monster.y - player.y;
                    const dist = Math.hypot(dx, dy);
                    if (dist > weapon.range) return;
                    const angle = Math.atan2(dy, dx);
                    let diff = Math.abs(angle - moveAngle);
                    if (diff > Math.PI) diff = Math.PI * 2 - diff;
                    if (diff < weapon.arcAngle / 2) monster.health -= weapon.damage;
                });
            }
            return;
        }
        if (weapon.type === 'orbit') {
            weapon.orbAngles = weapon.orbAngles.map(a => (a + weapon.speed) % (Math.PI * 2));
            weapon.orbAngles.forEach((angle, i) => {
                const ox = player.x + Math.cos(angle) * weapon.radius;
                const oy = player.y + Math.sin(angle) * weapon.radius;
                monsters.forEach(monster => {
                    if (Math.hypot(ox - monster.x, oy - monster.y) < weapon.orbRadius + monster.radius)
                        monster.health -= weapon.damage * 0.06;
                });
            });
            return;
        }
        if (weapon.type === 'laser') {
            weapon.cooldown--;
            if (weapon.cooldown <= 0) {
                weapon.cooldown = weapon.maxCooldown;
                weapon.beamTimer = 5;
            }
            if (weapon.beamTimer > 0) {
                weapon.beamTimer--;
                const angle = getPlayerLastMoveAngle();
                const ex = player.x + Math.cos(angle) * weapon.range;
                const ey = player.y + Math.sin(angle) * weapon.range;
                monsters.forEach(monster => {
                    const proj = distToSegment(monster.x, monster.y, player.x, player.y, ex, ey);
                    if (proj < 20 + monster.radius) monster.health -= weapon.damage;
                });
            }
            return;
        }
        if (weapon.type === 'shotgun') {
            weapon.cooldown--;
            if (weapon.cooldown <= 0) {
                weapon.cooldown = weapon.maxCooldown;
                let nearestMonster = null;
                let nearestDist = Infinity;
                monsters.forEach(monster => {
                    const dist = Math.hypot(monster.x - player.x, monster.y - player.y);
                    if (dist < nearestDist) { nearestDist = dist; nearestMonster = monster; }
                });
                const baseAngle = nearestMonster
                    ? Math.atan2(nearestMonster.y - player.y, nearestMonster.x - player.x)
                    : getPlayerLastMoveAngle();
                [-0.25, 0, 0.25].forEach(off => {
                    const a = baseAngle + off;
                    weapon.projectiles.push({
                        x: player.x, y: player.y,
                        vx: Math.cos(a) * weapon.speed, vy: Math.sin(a) * weapon.speed,
                        radius: 5, damage: weapon.damage
                    });
                });
            }
        } else if (weapon.type === 'boomerang') {
            weapon.cooldown--;
            if (weapon.cooldown <= 0) {
                weapon.cooldown = weapon.maxCooldown;
                let nearestMonster = null;
                let nearestDist = Infinity;
                monsters.forEach(monster => {
                    const dist = Math.hypot(monster.x - player.x, monster.y - player.y);
                    if (dist < nearestDist) { nearestDist = dist; nearestMonster = monster; }
                });
                const angle = nearestMonster
                    ? Math.atan2(nearestMonster.y - player.y, nearestMonster.x - player.x)
                    : getPlayerLastMoveAngle();
                weapon.projectiles.push({
                    x: player.x, y: player.y,
                    vx: Math.cos(angle) * weapon.speed, vy: Math.sin(angle) * weapon.speed,
                    radius: 8, damage: weapon.damage, speed: weapon.speed,
                    fromX: player.x, fromY: player.y, maxDist: weapon.maxDist, returning: false
                });
            }
        } else if (weapon.type === 'projectile') {
            weapon.cooldown--;
            if (weapon.cooldown <= 0) {
                weapon.cooldown = weapon.maxCooldown;
                let nearestMonster = null;
                let nearestDist = Infinity;
                monsters.forEach(monster => {
                    const dist = Math.hypot(monster.x - player.x, monster.y - player.y);
                    if (dist < nearestDist) { nearestDist = dist; nearestMonster = monster; }
                });
                const angle = nearestMonster
                    ? Math.atan2(nearestMonster.y - player.y, nearestMonster.x - player.x)
                    : getPlayerLastMoveAngle();
                weapon.projectiles.push({
                    x: player.x, y: player.y,
                    vx: Math.cos(angle) * weapon.speed, vy: Math.sin(angle) * weapon.speed,
                    radius: 5, damage: weapon.damage
                });
            }
        }
        if (!weapon.projectiles) return;
        weapon.projectiles = weapon.projectiles.filter(projectile => {
            if (projectile.returning) {
                const dx = player.x - projectile.x;
                const dy = player.y - projectile.y;
                const dist = Math.hypot(dx, dy);
                if (dist < 25) return false;
                projectile.x += (dx / dist) * projectile.speed;
                projectile.y += (dy / dist) * projectile.speed;
            } else {
                projectile.x += projectile.vx;
                projectile.y += projectile.vy;
                const fromDist = projectile.fromX != null
                    ? Math.hypot(projectile.x - projectile.fromX, projectile.y - projectile.fromY)
                    : 0;
                if (projectile.maxDist && fromDist >= projectile.maxDist) {
                    projectile.returning = true;
                    projectile.speed = projectile.speed || weapon.speed;
                }
            }
            if (projectile.x < 0 || projectile.x > canvas.width || projectile.y < 0 || projectile.y > canvas.height)
                if (!projectile.returning) return false;
            let hit = false;
            monsters.forEach(monster => {
                if (Math.hypot(projectile.x - monster.x, projectile.y - monster.y) < projectile.radius + monster.radius) {
                    monster.health -= projectile.damage;
                    hit = true;
                }
            });
            return !hit;
        });
    });
    monsters.forEach(m => {
        if (m.health <= 0) {
            score += m.points;
            expOrbs.push(createExpOrb(m.x, m.y, m.expValue));
            if (Math.random() < HEART_DROP_CHANCE) heartPickups.push({ x: m.x, y: m.y });
        }
    });
    for (let i = monsters.length - 1; i >= 0; i--) {
        if (monsters[i].health <= 0) monsters.splice(i, 1);
    }
}

function distToSegment(px, py, x1, y1, x2, y2) {
    const dx = x2 - x1, dy = y2 - y1;
    const len = Math.hypot(dx, dy) || 1;
    const t = Math.max(0, Math.min(1, ((px - x1) * dx + (py - y1) * dy) / (len * len)));
    const projX = x1 + t * dx, projY = y1 + t * dy;
    return Math.hypot(px - projX, py - projY);
}

let lastMoveAngle = 0;
function getPlayerLastMoveAngle() {
    let dx = 0, dy = 0;
    if (keys['ArrowUp'] || keys['w'] || keys['W']) dy -= 1;
    if (keys['ArrowDown'] || keys['s'] || keys['S']) dy += 1;
    if (keys['ArrowLeft'] || keys['a'] || keys['A']) dx -= 1;
    if (keys['ArrowRight'] || keys['d'] || keys['D']) dx += 1;
    if (dx !== 0 || dy !== 0) lastMoveAngle = Math.atan2(dy, dx);
    return lastMoveAngle;
}

function createExpOrb(x, y, value) {
    return {
        x, y, value,
        radius: 8,
        vx: (Math.random() - 0.5) * 2,
        vy: (Math.random() - 0.5) * 2,
        life: 300
    };
}

// 몬스터 생성
function spawnMonster() {
    const diff = DIFFICULTY[currentDifficulty];
    const side = Math.floor(Math.random() * 4);
    let x, y;
    switch(side) {
        case 0: x = Math.random() * canvas.width; y = -20; break;
        case 1: x = canvas.width + 20; y = Math.random() * canvas.height; break;
        case 2: x = Math.random() * canvas.width; y = canvas.height + 20; break;
        case 3: x = -20; y = Math.random() * canvas.height; break;
    }
    const baseSpeed = (1.2 + level * 0.15) * diff.speedMult;
    const health = 1 + Math.floor(level / 5);
    const driftAngle = Math.random() * Math.PI * 2;
    const driftChangeTimer = 15 + Math.floor(Math.random() * 35);
    const hue = 0 + Math.random() * 35;
    monsters.push({
        x, y,
        radius: 12 + level * 0.5,
        speed: baseSpeed,
        health, maxHealth: health,
        color: `hsl(${hue}, 75%, 45%)`,
        points: health * 10,
        expValue: health,
        driftAngle,
        driftChangeTimer
    });
}

// 몬스터 업데이트 (플레이어 방향 + 불규칙한 옆으로 흔들림)
function updateMonsters() {
    const diff = DIFFICULTY[currentDifficulty];
    const irregularity = diff.irregularity;
    monsters.forEach((monster) => {
        const dx = player.x - monster.x;
        const dy = player.y - monster.y;
        const dist = Math.hypot(dx, dy);
        if (dist > 0) {
            const towardX = dx / dist;
            const towardY = dy / dist;
            monster.driftChangeTimer--;
            if (monster.driftChangeTimer <= 0) {
                monster.driftAngle += (Math.random() - 0.5) * 2.5;
                monster.driftChangeTimer = 12 + Math.floor(Math.random() * 28);
            }
            const wobble = Math.sin(monster.driftAngle) * irregularity;
            const perpX = -towardY;
            const perpY = towardX;
            monster.x += (towardX + perpX * wobble) * monster.speed;
            monster.y += (towardY + perpY * wobble) * monster.speed;
        }
        if (player.invincible) return;
        const playerDist = Math.hypot(monster.x - player.x, monster.y - player.y);
        if (playerDist < monster.radius + player.radius) {
            player.hp--;
            player.invincible = true;
            player.invincibleTimer = 90;
            if (player.hp <= 0) gameOver();
        }
    });
}

// 경험치 구슬 업데이트
function updateExpOrbs() {
    for (let i = expOrbs.length - 1; i >= 0; i--) {
        const orb = expOrbs[i];
        orb.life--;
        const dx = player.x - orb.x;
        const dy = player.y - orb.y;
        const dist = Math.hypot(dx, dy);
        if (dist < player.magnetRadius) {
            const pullStrength = (player.magnetRadius - dist) / player.magnetRadius;
            orb.vx += (dx / dist) * pullStrength * 0.5;
            orb.vy += (dy / dist) * pullStrength * 0.5;
        }
        orb.x += orb.vx;
        orb.y += orb.vy;
        orb.vx *= 0.95;
        orb.vy *= 0.95;
        const playerDist = Math.hypot(orb.x - player.x, orb.y - player.y);
        if (playerDist < orb.radius + player.radius) {
            expCurrent += orb.value;
            score += orb.value * 5;
            expOrbs.splice(i, 1);
        }
        if (orb.life <= 0) expOrbs.splice(i, 1);
    }
    while (expCurrent >= expToNextLevel && !levelUpPaused) {
        expCurrent -= expToNextLevel;
        level++;
        expToNextLevel = Math.floor(expToNextLevel * 1.15) + 5;
        showLevelUpChoices();
    }
}

// 피 회복 하트 수집 처리
function updateHeartPickups() {
    for (let i = heartPickups.length - 1; i >= 0; i--) {
        const h = heartPickups[i];
        const dist = Math.hypot(h.x - player.x, h.y - player.y);
        if (dist < 14 + player.radius) {
            if (player.hp < player.maxHp) player.hp++;
            heartPickups.splice(i, 1);
        }
    }
}

// 레벨업 시 3가지 선택지 표시
function showLevelUpChoices() {
    levelUpPaused = true;
    const pool = getLevelUpOptions();
    pendingLevelUpChoices = [];
    for (let i = 0; i < 3 && pool.length > 0; i++) {
        const idx = Math.floor(Math.random() * pool.length);
        pendingLevelUpChoices.push(pool.splice(idx, 1)[0]);
    }
}

function applyLevelUpChoice(index) {
    if (index < 0 || index >= pendingLevelUpChoices.length) return;
    pendingLevelUpChoices[index].apply();
    pendingLevelUpChoices = [];
    levelUpPaused = false;
}

// 렌더링
function draw() {
    // 배경
    ctx.fillStyle = '#1a1a2e';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    // 그리드 배경
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.05)';
    ctx.lineWidth = 1;
    for (let i = 0; i < canvas.width; i += 50) {
        ctx.beginPath();
        ctx.moveTo(i, 0);
        ctx.lineTo(i, canvas.height);
        ctx.stroke();
    }
    for (let i = 0; i < canvas.height; i += 50) {
        ctx.beginPath();
        ctx.moveTo(0, i);
        ctx.lineTo(canvas.width, i);
        ctx.stroke();
    }
    
    // 피 회복 하트
    heartPickups.forEach(h => drawHeart(h.x, h.y, 14));
    
    // 경험치 — 초록 마름모(다이아몬드) · 수집품 구분
    expOrbs.forEach(orb => {
        const a = orb.life / 300;
        ctx.save();
        ctx.translate(orb.x, orb.y);
        ctx.rotate(Math.PI / 4);
        ctx.fillStyle = `rgba(50, 205, 130, ${a})`;
        ctx.strokeStyle = `rgba(144, 238, 144, ${a})`;
        ctx.lineWidth = 2;
        ctx.beginPath();
        const r = orb.radius * 1.2;
        ctx.moveTo(r, 0);
        ctx.lineTo(0, r);
        ctx.lineTo(-r, 0);
        ctx.lineTo(0, -r);
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
        ctx.restore();
    });
    
    // 몬스터 — 빨강/주황. 체력 2 이상은 다이아몬드 두 겹으로 구분
    monsters.forEach(monster => {
        const r = monster.radius;
        const half = r * 0.7;
        const isTough = monster.maxHealth > 1;
        ctx.save();
        ctx.translate(monster.x + 2, monster.y + 2);
        ctx.rotate(Math.PI / 4);
        ctx.fillStyle = 'rgba(0, 0, 0, 0.4)';
        ctx.fillRect(-half, -half, r * 1.4, r * 1.4);
        ctx.restore();
        ctx.save();
        ctx.translate(monster.x, monster.y);
        ctx.rotate(Math.PI / 4);
        if (isTough) {
            const outer = half * 1.35;
            ctx.fillStyle = 'rgba(80, 20, 20, 0.5)';
            ctx.strokeStyle = 'rgba(180, 40, 40, 0.9)';
            ctx.lineWidth = 2;
            ctx.fillRect(-outer, -outer, outer * 2, outer * 2);
            ctx.strokeRect(-outer, -outer, outer * 2, outer * 2);
        }
        ctx.fillStyle = monster.color;
        ctx.fillRect(-half, -half, r * 1.4, r * 1.4);
        ctx.strokeStyle = isTough ? 'rgba(220, 80, 80, 0.95)' : 'rgba(200, 60, 60, 0.9)';
        ctx.lineWidth = isTough ? 2 : 1.5;
        ctx.strokeRect(-half, -half, r * 1.4, r * 1.4);
        ctx.restore();
        if (monster.health < monster.maxHealth) {
            const barWidth = monster.radius * 2;
            const barHeight = 4;
            ctx.fillStyle = 'rgba(80,0,0,0.8)';
            ctx.fillRect(monster.x - barWidth / 2, monster.y - monster.radius - 12, barWidth, barHeight);
            ctx.fillStyle = '#8b0000';
            ctx.fillRect(monster.x - barWidth / 2, monster.y - monster.radius - 12,
                        barWidth * (monster.health / monster.maxHealth), barHeight);
        }
    });
    
    // 미사일/샷건/부메랑 — 투사체
    weapons.forEach(weapon => {
        if (!weapon.projectiles) return;
        weapon.projectiles.forEach(projectile => {
            const angle = projectile.returning
                ? Math.atan2(player.y - projectile.y, player.x - projectile.x)
                : Math.atan2(projectile.vy, projectile.vx);
            const r = projectile.radius;
            const isBoomerang = weapon.type === 'boomerang';
            ctx.save();
            ctx.translate(projectile.x, projectile.y);
            ctx.rotate(angle);
            ctx.fillStyle = isBoomerang ? '#9b59b6' : '#00d4ff';
            ctx.strokeStyle = isBoomerang ? '#8e44ad' : '#7df9ff';
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.moveTo(r * 1.4, 0);
            ctx.lineTo(-r * 1.1, r * 1.1);
            ctx.lineTo(-r * 0.4, 0);
            ctx.lineTo(-r * 1.1, -r * 1.1);
            ctx.closePath();
            ctx.fill();
            ctx.stroke();
            ctx.restore();
        });
    });
    
    // 오비트 구체
    weapons.forEach(weapon => {
        if (weapon.type !== 'orbit') return;
        weapon.orbAngles.forEach(angle => {
            const ox = player.x + Math.cos(angle) * weapon.radius;
            const oy = player.y + Math.sin(angle) * weapon.radius;
            ctx.fillStyle = '#f1c40f';
            ctx.strokeStyle = '#f39c12';
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.arc(ox, oy, weapon.orbRadius, 0, Math.PI * 2);
            ctx.fill();
            ctx.stroke();
        });
    });
    
    // 레이저 빔
    weapons.forEach(weapon => {
        if (weapon.type === 'laser' && weapon.beamTimer > 0) {
            const angle = getPlayerLastMoveAngle();
            const ex = player.x + Math.cos(angle) * weapon.range;
            const ey = player.y + Math.sin(angle) * weapon.range;
            ctx.strokeStyle = 'rgba(255, 150, 200, 0.6)';
            ctx.lineWidth = 4;
            ctx.beginPath();
            ctx.moveTo(player.x, player.y);
            ctx.lineTo(ex, ey);
            ctx.stroke();
        }
    });
    
    // 휩 스윙 이펙트
    weapons.forEach(weapon => {
        if (weapon.type === 'whip' && weapon.swingTimer > 0) {
            const angle = getPlayerLastMoveAngle();
            ctx.strokeStyle = 'rgba(255, 200, 100, 0.8)';
            ctx.lineWidth = 12;
            ctx.beginPath();
            ctx.arc(player.x, player.y, weapon.range, angle - weapon.arcAngle / 2, angle + weapon.arcAngle / 2);
            ctx.stroke();
        }
    });
    
    // 플레이어 (무적 시 깜빡임)
    const blink = player.invincible && Math.floor(player.invincibleTimer / 5) % 2 === 0;
    if (!blink) {
        ctx.shadowBlur = 20;
        ctx.shadowColor = player.color;
        ctx.fillStyle = player.color;
        ctx.beginPath();
        ctx.arc(player.x, player.y, player.radius, 0, Math.PI * 2);
        ctx.fill();
        ctx.shadowBlur = 0;
        ctx.strokeStyle = '#fff';
        ctx.lineWidth = 2;
        ctx.stroke();
    }
    
    // UI: 체력, 레벨, 경험치 바, 생존 시간
    drawGameUI();
    
    // 레벨업 선택 패널
    if (levelUpPaused && pendingLevelUpChoices.length > 0) {
        drawLevelUpPanel();
    }
}

// 하트 모양 그리기 (피 회복 아이템) — 위쪽 두 볼록, 아래 뾰족한 진짜 하트
function drawHeart(x, y, size) {
    ctx.save();
    ctx.translate(x, y);
    const s = size;
    ctx.fillStyle = '#e74c3c';
    ctx.strokeStyle = '#c0392b';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(0, -s * 0.35);
    ctx.bezierCurveTo(s * 0.5, -s * 0.35, s * 0.5, s * 0.2, 0, s * 0.45);
    ctx.bezierCurveTo(-s * 0.5, s * 0.2, -s * 0.5, -s * 0.35, 0, -s * 0.35);
    ctx.fill();
    ctx.stroke();
    ctx.restore();
}

function drawGameUI() {
    ctx.font = '16px Arial';
    ctx.textAlign = 'left';
    ctx.fillStyle = '#fff';
    ctx.fillText(`레벨 ${level}`, 14, 22);
    ctx.fillStyle = '#aaa';
    ctx.fillText(`난이도: ${DIFFICULTY[currentDifficulty].name}`, 105, 22);
    const totalSec = Math.floor(gameTime / 60);
    const min = Math.floor(totalSec / 60);
    const sec = totalSec % 60;
    ctx.fillText(`생존 ${min}:${String(sec).padStart(2, '0')}`, 210, 22);
    const sub = getCurrentSupplementary();
    ctx.textAlign = 'right';
    ctx.fillStyle = sub ? '#c8a2c8' : '#666';
    const subWeapon = getSupplementaryWeapon();
    const subText = subWeapon
        ? `보조: ${SUPPLEMENTARY_NAMES[sub]} Lv.${subWeapon.level || 1}`
        : '보조: 없음';
    ctx.fillText(subText, canvas.width - 14, 22);
    let rightRow = 22;
    if (sub) {
        ctx.font = '12px Arial';
        ctx.fillStyle = '#888';
        ctx.fillText('강화 시: 데미지·쿨·사거리↑', canvas.width - 14, 38);
        ctx.font = '16px Arial';
        rightRow = 52;
    } else {
        rightRow = 40;
    }
    const mainWeapon = weapons.find(w => w.type === 'projectile');
    if (mainWeapon) {
        const atk = mainWeapon.damage != null ? mainWeapon.damage.toFixed(1) : '1';
        const atkSpd = mainWeapon.maxCooldown > 0 ? (60 / mainWeapon.maxCooldown).toFixed(1) : '-';
        ctx.fillStyle = '#aaa';
        ctx.fillText(`공격력 ${atk}  공격속도 ${atkSpd}/초`, canvas.width - 14, rightRow);
    }
    ctx.textAlign = 'left';
    ctx.fillStyle = '#fff';
    // 체력 하트
    for (let i = 0; i < player.maxHp; i++) {
        ctx.fillStyle = i < player.hp ? '#ff6b6b' : 'rgba(100,100,100,0.5)';
        ctx.beginPath();
        ctx.arc(14 + i * 22, 44, 8, 0, Math.PI * 2);
        ctx.fill();
    }
    // 경험치 바
    const barW = canvas.width - 28;
    const barH = 8;
    ctx.fillStyle = 'rgba(0,0,0,0.5)';
    ctx.fillRect(14, 58, barW, barH);
    ctx.fillStyle = '#7b68ee';
    ctx.fillRect(14, 58, barW * (expCurrent / expToNextLevel), barH);
    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1;
    ctx.strokeRect(14, 58, barW, barH);
}

function drawLevelUpPanel() {
    ctx.fillStyle = 'rgba(0, 0, 0, 0.85)';
    ctx.fillRect(canvas.width / 2 - 200, canvas.height / 2 - 100, 400, 220);
    ctx.strokeStyle = '#ffd700';
    ctx.lineWidth = 3;
    ctx.strokeRect(canvas.width / 2 - 200, canvas.height / 2 - 100, 400, 220);
    ctx.fillStyle = '#ffd700';
    ctx.font = 'bold 22px Arial';
    ctx.textAlign = 'center';
    ctx.fillText('레벨 업! 강화를 선택하세요', canvas.width / 2, canvas.height / 2 - 65);
    ctx.font = '18px Arial';
    pendingLevelUpChoices.forEach((opt, i) => {
        const y = canvas.height / 2 - 32 + i * 44;
        ctx.fillStyle = '#fff';
        ctx.fillText(`${i + 1}. ${opt.name}`, canvas.width / 2, y);
        if (opt.detail) {
            ctx.font = '13px Arial';
            ctx.fillStyle = '#b8b8b8';
            ctx.fillText(`   ${opt.detail}`, canvas.width / 2, y + 18);
            ctx.font = '18px Arial';
            ctx.fillStyle = '#fff';
        }
    });
    ctx.fillStyle = '#aaa';
    ctx.font = '14px Arial';
    ctx.fillText('1, 2, 3 키로 선택  /  5: 선택포기', canvas.width / 2, canvas.height / 2 + 78);
    ctx.textAlign = 'left';
}

// 게임 루프
function gameLoop() {
    if (!gameRunning) return;
    
    if (!levelUpPaused) gameTime++;
    
    // 무적 시간 감소
    if (player.invincible) {
        player.invincibleTimer--;
        if (player.invincibleTimer <= 0) {
            player.invincible = false;
        }
    }
    
    if (!levelUpPaused) {
        updatePlayer();
        monsterSpawnTimer++;
        if (monsterSpawnTimer >= monsterSpawnRate) {
            monsterSpawnTimer = 0;
            const spawnCount = 1 + Math.floor(level / 10);
            for (let i = 0; i < spawnCount; i++) spawnMonster();
        }
        const diff = DIFFICULTY[currentDifficulty];
        const baseRate = Math.max(25, 60 - Math.floor(gameTime / 500));
        monsterSpawnRate = Math.max(15, Math.floor(baseRate / diff.spawnMult));
        updateWeapons();
        updateMonsters();
        updateExpOrbs();
        updateHeartPickups();
    }
    
    draw();
    document.getElementById('score').textContent = score;
    document.getElementById('highScore').textContent = highScore;
    requestAnimationFrame(gameLoop);
}

// 게임 오버
function gameOver() {
    gameRunning = false;
    
    if (score > highScore) {
        highScore = score;
        localStorage.setItem('highScore', highScore);
    }
    
    document.getElementById('finalScore').textContent = score;
    document.getElementById('gameOver').classList.add('show');
}

// 난이도 선택
document.querySelectorAll('.diff-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.diff-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        currentDifficulty = btn.dataset.diff;
    });
});

// 재시작
document.getElementById('restartBtn').addEventListener('click', () => {
    gameRunning = true;
    score = 0;
    gameTime = 0;
    level = 1;
    expCurrent = 0;
    expToNextLevel = 10;
    levelUpPaused = false;
    pendingLevelUpChoices = [];
    monsters.length = 0;
    expOrbs.length = 0;
    heartPickups.length = 0;
    weapons.length = 0;
    player.x = canvas.width / 2;
    player.y = canvas.height / 2;
    player.hp = player.maxHp;
    player.invincible = false;
    player.invincibleTimer = 0;
    initWeapons();
    document.getElementById('gameOver').classList.remove('show');
    gameLoop();
});

// 게임 시작
initWeapons();
gameLoop();

