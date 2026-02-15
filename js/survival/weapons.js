/**
 * 무기: 메인 투사체, 보조무기(휩/오비트/샷건/부메랑/레이저), 업데이트
 */
function getPlayerLastMoveAngle() {
    let dx = 0, dy = 0;
    if (keys['ArrowUp'] || keys['w'] || keys['W']) dy -= 1;
    if (keys['ArrowDown'] || keys['s'] || keys['S']) dy += 1;
    if (keys['ArrowLeft'] || keys['a'] || keys['A']) dx -= 1;
    if (keys['ArrowRight'] || keys['d'] || keys['D']) dx += 1;
    if (dx !== 0 || dy !== 0) lastMoveAngle = Math.atan2(dy, dx);
    return lastMoveAngle;
}

function getCurrentSupplementary() {
    const w = weapons.find(w => SUPPLEMENTARY_TYPES.includes(w.type));
    return w ? w.type : null;
}

function getSupplementaryWeapon() {
    return weapons.find(w => SUPPLEMENTARY_TYPES.includes(w.type)) || null;
}

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
    if (w.type === 'boomerang') {
        w.maxDist = Math.min(540, (w.maxDist || 360) + 24);
        w.damage = (w.damage || 2) + 0.5;
        w.boomerangRadius = (w.boomerangRadius || 8) + 2;
    }
    if (w.type === 'shotgun') {
        w.maxMagazine = Math.min(5, (w.maxMagazine || 2) + 1);
        w.damage = (w.damage || 1) + 2.8;
        w.pelletCount = Math.min(14, (w.pelletCount || 6) + 2);
        w.pelletRadius = Math.min(6, (w.pelletRadius || 2.5) + 0.5);
        w.range = Math.min(320, (w.range || 200) + 18);
        w.reloadOneFrames = Math.max(90, (w.reloadOneFrames || 120) - 6);
    }
}

function getLevelUpOptions() {
    const opts = [
        { id: 'damage', name: '공격력 +1', apply: () => { weapons.forEach(w => w.damage += 1); } },
        { id: 'cooldown', name: '공격 속도 ↑', apply: () => { weapons.forEach(w => w.maxCooldown = Math.max(8, w.maxCooldown - 3)); } },
        { id: 'speed', name: '이동 속도 ↑', apply: () => { player.speed += 0.5; } },
        { id: 'maxHp', name: '최대 체력 +1', apply: () => { player.maxHp++; player.hp++; } },
        { id: 'magnet', name: '경험치 끌어당김 ↑', apply: () => { player.magnetRadius += 28; } }
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
    const swordWeapon = weapons.find(w => w.type === 'sword');
    if (swordWeapon) {
        opts.push({
            id: 'swordRange',
            name: '공격 범위 ↑',
            detail: '칼 사거리·부채꼴 범위 상승',
            apply: () => {
                swordWeapon.range = Math.min(200, (swordWeapon.range || 110) + 18);
                swordWeapon.arcAngle = Math.min(Math.PI * 1.6, (swordWeapon.arcAngle || Math.PI / 2) + 0.12);
            }
        });
    }
    if (selectedCharacter === 1) {
        opts.push({
            id: 'knockback',
            name: '넉백 ↑',
            detail: '맞을 때 밀려나는 거리 증가',
            apply: () => { player.knockbackPower = (player.knockbackPower || 8) + 4; }
        });
    }
    opts.push({ id: 'whip', name: '보조: 휩', apply: () => { setSupplementaryWeapon('whip'); } });
    opts.push({ id: 'orbit', name: '보조: 오비트', apply: () => { setSupplementaryWeapon('orbit'); } });
    opts.push({ id: 'shotgun', name: '보조: 샷건', apply: () => { setSupplementaryWeapon('shotgun'); } });
    opts.push({ id: 'boomerang', name: '보조: 부메랑', apply: () => { setSupplementaryWeapon('boomerang'); } });
    opts.push({ id: 'laser', name: '보조: 레이저', apply: () => { setSupplementaryWeapon('laser'); } });
    return opts;
}

function initWeapons() {
    weapons.length = 0;
    if (selectedCharacter === 1) {
        weapons.push({
            type: 'sword',
            damage: 3,
            cooldown: 0,
            maxCooldown: 50,
            range: 110,
            arcAngle: Math.PI / 2,
            swingInstances: []
        });
    } else {
        weapons.push({
            type: 'projectile',
            damage: 1,
            speed: 8,
            cooldown: 0,
            maxCooldown: 30,
            projectiles: []
        });
    }
}

function addWhipWeapon() {
    if (weapons.some(w => w.type === 'whip')) return;
    weapons.push({
        type: 'whip', level: 1, damage: 2, cooldown: 0, maxCooldown: 90,
        range: 80, arcAngle: Math.PI * 0.6, swingTimer: 0
    });
}

function addOrbitWeapon() {
    if (weapons.some(w => w.type === 'orbit')) return;
    weapons.push({
        type: 'orbit', level: 1, damage: 1, cooldown: 0, radius: 55,
        orbAngles: [0], orbRadius: 10, speed: 0.08
    });
}

function addShotgunWeapon() {
    if (weapons.some(w => w.type === 'shotgun')) return;
    weapons.push({
        type: 'shotgun', level: 1, damage: 7.2,
        pelletCount: 6, pelletSpeed: 14, pelletRadius: 2.5,
        spreadAngle: 0.55, range: 200,
        magazine: 2, maxMagazine: 2,
        reloadTimer: 0, reloadOneFrames: 120, reloadInProgress: false,
        fireCooldown: 0, fireCooldownFrames: 60,
        projectiles: []
    });
}

function addBoomerangWeapon() {
    if (weapons.some(w => w.type === 'boomerang')) return;
    weapons.push({
        type: 'boomerang', level: 1, damage: 2, speed: 6, cooldown: 0,
        maxCooldown: 75, maxDist: 360, boomerangRadius: 8, projectiles: []
    });
}

function addLaserWeapon() {
    if (weapons.some(w => w.type === 'laser')) return;
    weapons.push({
        type: 'laser', level: 1, damage: 0.5, cooldown: 0, maxCooldown: 8,
        range: 150, beamTimer: 0
    });
}

function distToSegment(px, py, x1, y1, x2, y2) {
    const dx = x2 - x1, dy = y2 - y1;
    const len = Math.hypot(dx, dy) || 1;
    const t = Math.max(0, Math.min(1, ((px - x1) * dx + (py - y1) * dy) / (len * len)));
    const projX = x1 + t * dx, projY = y1 + t * dy;
    return Math.hypot(px - projX, py - projY);
}

function updateWeapons() {
    weapons.forEach(weapon => {
        if (weapon.type === 'sword') {
            weapon.cooldown--;
            const swingFrames = 12;
            if (!weapon.swingInstances) weapon.swingInstances = [];
            for (let i = weapon.swingInstances.length - 1; i >= 0; i--) {
                const inst = weapon.swingInstances[i];
                inst.swingTimer--;
                if (inst.swingTimer === 0) {
                    const swingAngle = inst.swingAngle;
                    const knockbackPower = (selectedCharacter === 1 && (player.knockbackPower || 0) > 0) ? player.knockbackPower : 0;
                    monsters.forEach(monster => {
                        const dx = monster.x - player.x, dy = monster.y - player.y;
                        const dist = Math.hypot(dx, dy);
                        if (dist > weapon.range + monster.radius) return;
                        const angle = Math.atan2(dy, dx);
                        let diff = Math.abs(angle - swingAngle);
                        if (diff > Math.PI) diff = Math.PI * 2 - diff;
                        const angleMargin = Math.atan(monster.radius / Math.max(dist, 1));
                        if (diff < weapon.arcAngle / 2 + angleMargin) {
                            monster.health -= weapon.damage;
                            if (knockbackPower > 0 && dist > 0) {
                                const awayX = dx / dist;
                                const awayY = dy / dist;
                                monster.knockbackVx = (monster.knockbackVx || 0) + awayX * knockbackPower;
                                monster.knockbackVy = (monster.knockbackVy || 0) + awayY * knockbackPower;
                            }
                        }
                    });
                    weapon.swingInstances.splice(i, 1);
                }
            }
            if (weapon.cooldown <= 0) {
                weapon.cooldown = weapon.maxCooldown;
                let nearestMonster = null, nearestDist = Infinity;
                monsters.forEach(monster => {
                    const dist = Math.hypot(monster.x - player.x, monster.y - player.y);
                    if (dist < nearestDist) { nearestDist = dist; nearestMonster = monster; }
                });
                const swingAngle = nearestMonster
                    ? Math.atan2(nearestMonster.y - player.y, nearestMonster.x - player.x)
                    : getPlayerLastMoveAngle();
                weapon.swingInstances.push({ swingTimer: swingFrames, swingAngle });
            }
            return;
        }
        if (weapon.type === 'whip') {
            weapon.cooldown--;
            if (weapon.swingTimer > 0) weapon.swingTimer--;
            if (weapon.cooldown <= 0) {
                weapon.cooldown = weapon.maxCooldown;
                weapon.swingTimer = 15;
                const moveAngle = getPlayerLastMoveAngle();
                monsters.forEach(monster => {
                    const dx = monster.x - player.x, dy = monster.y - player.y;
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
            weapon.orbAngles.forEach((angle) => {
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
            if (weapon.cooldown <= 0) { weapon.cooldown = weapon.maxCooldown; weapon.beamTimer = 5; }
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
            const mag = weapon.magazine || 0;
            const maxMag = weapon.maxMagazine || 2;
            const relFrames = weapon.reloadOneFrames || 120;
            if (weapon.reloadInProgress && mag < maxMag) {
                if ((weapon.reloadTimer || 0) > 0) {
                    weapon.reloadTimer--;
                } else {
                    weapon.magazine = (weapon.magazine || 0) + 1;
                    if (weapon.magazine >= maxMag) weapon.reloadInProgress = false;
                    else weapon.reloadTimer = relFrames;
                }
            }
            if ((weapon.fireCooldown || 0) > 0) weapon.fireCooldown--;
            const canFire = (weapon.magazine || 0) > 0 && !weapon.reloadInProgress && (weapon.fireCooldown || 0) <= 0;
            if (canFire) {
                weapon.magazine--;
                if (weapon.magazine === 0) {
                    weapon.reloadTimer = relFrames;
                    weapon.reloadInProgress = true;
                }
                weapon.fireCooldown = weapon.fireCooldownFrames || 60;
                let nearestMonster = null, nearestDist = Infinity;
                monsters.forEach(monster => {
                    const dist = Math.hypot(monster.x - player.x, monster.y - player.y);
                    if (dist < nearestDist) { nearestDist = dist; nearestMonster = monster; }
                });
                const baseAngle = nearestMonster
                    ? Math.atan2(nearestMonster.y - player.y, nearestMonster.x - player.x)
                    : getPlayerLastMoveAngle();
                const count = weapon.pelletCount || 6;
                const spread = weapon.spreadAngle || 0.55;
                const speed = weapon.pelletSpeed || 14;
                const range = weapon.range || 200;
                for (let i = 0; i < count; i++) {
                    const a = baseAngle + (Math.random() - 0.5) * spread * 2;
                    weapon.projectiles.push({
                        x: player.x, y: player.y,
                        vx: Math.cos(a) * speed, vy: Math.sin(a) * speed,
                        radius: weapon.pelletRadius || 2.5,
                        damage: weapon.damage,
                        fromX: player.x, fromY: player.y, maxDist: range
                    });
                }
            }
        } else if (weapon.type === 'boomerang') {
            weapon.cooldown--;
            const boomerangList = weapon.projectiles || [];
            const lowLevelWaitReturn = weapon.level <= 1 && boomerangList.length > 0;
            if (weapon.cooldown <= 0 && !lowLevelWaitReturn) {
                weapon.cooldown = weapon.maxCooldown;
                let nearestMonster = null, nearestDist = Infinity;
                monsters.forEach(monster => {
                    const dist = Math.hypot(monster.x - player.x, monster.y - player.y);
                    if (dist < nearestDist) { nearestDist = dist; nearestMonster = monster; }
                });
                const angle = nearestMonster
                    ? Math.atan2(nearestMonster.y - player.y, nearestMonster.x - player.x)
                    : getPlayerLastMoveAngle();
                const br = weapon.boomerangRadius != null ? weapon.boomerangRadius : 8;
                weapon.projectiles.push({
                    x: player.x, y: player.y,
                    vx: Math.cos(angle) * weapon.speed, vy: Math.sin(angle) * weapon.speed,
                    radius: br, damage: weapon.damage, speed: weapon.speed,
                    fromX: player.x, fromY: player.y, maxDist: weapon.maxDist, returning: false
                });
            }
        } else if (weapon.type === 'projectile') {
            weapon.cooldown--;
            if (weapon.cooldown <= 0) {
                weapon.cooldown = weapon.maxCooldown;
                let nearestMonster = null, nearestDist = Infinity;
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
            if (weapon.type === 'shotgun') {
                projectile.x += projectile.vx;
                projectile.y += projectile.vy;
                const fromDist = (projectile.fromX != null && projectile.fromY != null)
                    ? Math.hypot(projectile.x - projectile.fromX, projectile.y - projectile.fromY)
                    : 0;
                if (projectile.maxDist != null && fromDist >= projectile.maxDist) return false;
                if (projectile.x < -20 || projectile.x > canvas.width + 20 || projectile.y < -20 || projectile.y > canvas.height + 20) return false;
                const pierceHits = projectile.pierceHits || 0;
                monsters.forEach(monster => {
                    if (Math.hypot(projectile.x - monster.x, projectile.y - monster.y) < projectile.radius + monster.radius) {
                        const mult = pierceHits === 0 ? 1 : Math.pow(0.65, pierceHits);
                        monster.health -= projectile.damage * mult;
                        projectile.pierceHits = pierceHits + 1;
                    }
                });
                return true;
            }
            if (projectile.returning) {
                const dx = player.x - projectile.x, dy = player.y - projectile.y;
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
            if (weapon.type !== 'boomerang' && (projectile.x < 0 || projectile.x > canvas.width || projectile.y < 0 || projectile.y > canvas.height))
                if (!projectile.returning) return false;
            let hit = false;
            monsters.forEach(monster => {
                if (Math.hypot(projectile.x - monster.x, projectile.y - monster.y) < projectile.radius + monster.radius) {
                    monster.health -= projectile.damage;
                    if (weapon.type === 'boomerang') {
                        const bdx = monster.x - projectile.x, bdy = monster.y - projectile.y;
                        const bdist = Math.hypot(bdx, bdy) || 1;
                        const knock = 2.2;
                        monster.knockbackVx = (monster.knockbackVx || 0) + (bdx / bdist) * knock;
                        monster.knockbackVy = (monster.knockbackVy || 0) + (bdy / bdist) * knock;
                    } else {
                        hit = true;
                    }
                }
            });
            return weapon.type === 'boomerang' ? true : !hit;
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
        if (monsters[i].health <= 0) {
            const dead = monsters[i];
            if (dead.isBoss && dead.bossWave === getCurrentWave()) {
                bossClearedTimer = 180;
            }
            monsters.splice(i, 1);
        }
    }
}
