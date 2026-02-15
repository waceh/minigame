/**
 * 경험치 구슬, 하트 아이템
 */
function createExpOrb(x, y, value) {
    const radius = 5 + Math.min(value * 0.7, 14);
    return {
        x, y, value,
        radius,
        maxLife: EXP_ORB_LIFE,
        vx: (Math.random() - 0.5) * 2,
        vy: (Math.random() - 0.5) * 2,
        life: EXP_ORB_LIFE
    };
}

function updateExpOrbs() {
    for (let i = expOrbs.length - 1; i >= 0; i--) {
        const orb = expOrbs[i];
        orb.life--;
        const dx = player.x - orb.x;
        const dy = player.y - orb.y;
        const dist = Math.hypot(dx, dy);
        if (dist < player.magnetRadius) {
            const pullStrength = (player.magnetRadius - dist) / player.magnetRadius;
            orb.vx += (dx / dist) * pullStrength * 0.55;
            orb.vy += (dy / dist) * pullStrength * 0.55;
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
        player.hp = player.maxHp;
        expToNextLevel = Math.floor(expToNextLevel * 1.15) + 5;
        levelUpChoiceCount = 3;
        if (selectedCharacter === 0 && Math.random() < 0.05) {
            weapons.forEach(w => { w.damage = (w.damage || 1) + 0.15; });
        }
        if (selectedCharacter === 1 && Math.random() < 0.1) {
            levelUpChoiceCount = 4;
        }
        if (selectedCharacter === 2 && Math.random() < 0.1) {
            const sub = getCurrentSupplementary();
            if (sub === null || sub === 'orbit') {
                if (sub === 'orbit') upgradeSupplementaryWeapon();
                else addOrbitWeapon();
            }
        }
        showLevelUpChoices();
    }
}

function updateHeartPickups() {
    for (let i = heartPickups.length - 1; i >= 0; i--) {
        const h = heartPickups[i];
        const dx = player.x - h.x;
        const dy = player.y - h.y;
        const dist = Math.hypot(dx, dy);
        if (currentDifficulty !== 'hard' && dist < player.magnetRadius && dist > 0) {
            const pullStrength = (player.magnetRadius - dist) / player.magnetRadius * 0.28;
            h.x += (dx / dist) * pullStrength;
            h.y += (dy / dist) * pullStrength;
        }
        const pickupDist = Math.hypot(h.x - player.x, h.y - player.y);
        if (pickupDist < 14 + player.radius && player.hp < player.maxHp) {
            player.hp++;
            heartPickups.splice(i, 1);
        }
    }
}
