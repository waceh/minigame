/**
 * 배경, 오브젝트, UI, 레벨업 패널 렌더링
 */
function getWeaponLevelColor(weapon, baseColor, baseStroke) {
    const level = weapon.level || 1;
    const pulse = 0.7 + 0.3 * Math.sin(gameTime * 0.15);
    if (level >= 15) {
        const hue = (gameTime * 3) % 360;
        return {
            fill: `hsla(${hue}, 80%, 60%, 0.9)`,
            stroke: `hsla(${(hue + 60) % 360}, 90%, 50%, ${pulse})`,
            lineWidth: 3,
            glow: true,
            glowColor: `hsl(${hue}, 100%, 70%)`
        };
    } else if (level >= 10) {
        const alternate = Math.floor(gameTime / 10) % 2 === 0;
        return {
            fill: alternate ? '#ff6b6b' : '#ffd93d',
            stroke: alternate ? '#ffd93d' : '#ff6b6b',
            lineWidth: 2.5,
            glow: true,
            glowColor: alternate ? '#ff6b6b' : '#ffd93d'
        };
    } else if (level >= 5) {
        return {
            fill: '#ff6b6b',
            stroke: `rgba(255, 50, 50, ${pulse})`,
            lineWidth: 2,
            glow: true,
            glowColor: '#ff3333'
        };
    } else {
        return {
            fill: baseColor,
            stroke: baseStroke,
            lineWidth: weapon.type === 'orbit' ? 2 : 1.5,
            glow: false
        };
    }
}

function drawHeart(x, y, size) {
    if (heartImage.complete && heartImage.naturalWidth > 0) {
        ctx.drawImage(heartImage, x - size, y - size, size * 2, size * 2);
        return;
    }
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
    const { currentWave, nextWaveSec } = getWaveInfo();
    ctx.fillStyle = '#7b68ee';
    ctx.fillText(`웨이브 ${currentWave}`, 300, 22);
    ctx.fillStyle = '#aaa';
    ctx.fillText(`다음 웨이브 ${nextWaveSec}초`, 380, 22);
    const sub = getCurrentSupplementary();
    ctx.textAlign = 'right';
    ctx.fillStyle = sub ? '#c8a2c8' : '#666';
    const subWeapon = getSupplementaryWeapon();
    let subText = subWeapon
        ? `보조: ${SUPPLEMENTARY_NAMES[sub]} Lv.${subWeapon.level || 1}`
        : '보조: 없음';
    if (subWeapon && subWeapon.type === 'shotgun')
        subText += ` (${subWeapon.magazine || 0}/${subWeapon.maxMagazine || 2})`;
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
    const mainWeapon = weapons.find(w => w.type === 'projectile' || w.type === 'sword');
    const atk = mainWeapon && mainWeapon.damage != null ? mainWeapon.damage.toFixed(1) : '-';
    const atkSpd = mainWeapon && mainWeapon.maxCooldown > 0 ? (60 / mainWeapon.maxCooldown).toFixed(1) : '-';
    const moveSpd = (player.speed || 0).toFixed(1);
    ctx.fillStyle = '#aaa';
    ctx.fillText(`공격력 ${atk}  공격속도 ${atkSpd}/초  이동속도 ${moveSpd}`, canvas.width - 14, rightRow);
    ctx.textAlign = 'left';
    ctx.fillStyle = '#fff';
    const heartSize = 8;
    for (let i = 0; i < player.maxHp; i++) {
        const hx = 14 + i * 22;
        if (heart16Image.complete && heart16Image.naturalWidth > 0) {
            ctx.globalAlpha = i < player.hp ? 1 : 0.4;
            ctx.drawImage(heart16Image, hx - heartSize, 44 - heartSize, heartSize * 2, heartSize * 2);
            ctx.globalAlpha = 1;
        } else {
            ctx.fillStyle = i < player.hp ? '#ff6b6b' : 'rgba(100,100,100,0.5)';
            ctx.beginPath();
            ctx.arc(hx, 44, heartSize, 0, Math.PI * 2);
            ctx.fill();
        }
    }
    const barW = canvas.width - 28, barH = 8;
    ctx.fillStyle = 'rgba(0,0,0,0.5)';
    ctx.fillRect(14, 58, barW, barH);
    ctx.fillStyle = '#7b68ee';
    ctx.fillRect(14, 58, barW * (expCurrent / expToNextLevel), barH);
    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1;
    ctx.strokeRect(14, 58, barW, barH);
    const ultBarW = 180, ultBarH = 12;
    const ultBarX = 14, ultBarY = 72;
    ctx.fillStyle = 'rgba(0,0,0,0.7)';
    ctx.fillRect(ultBarX, ultBarY, ultBarW, ultBarH);
    if (ultimateActive) {
        const ratio = ultimateTimer / ULTIMATE_DURATION;
        ctx.fillStyle = '#ffd700';
        ctx.fillRect(ultBarX, ultBarY, ultBarW * ratio, ultBarH);
    } else if (ultimateCooldown > 0) {
        const ratio = 1 - ultimateCooldown / ULTIMATE_COOLDOWN;
        ctx.fillStyle = '#888';
        ctx.fillRect(ultBarX, ultBarY, ultBarW * ratio, ultBarH);
    } else {
        ctx.fillStyle = '#00ff00';
        ctx.fillRect(ultBarX, ultBarY, ultBarW, ultBarH);
    }
    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1;
    ctx.strokeRect(ultBarX, ultBarY, ultBarW, ultBarH);
    ctx.font = '11px Arial';
    ctx.textAlign = 'left';
    ctx.fillStyle = '#fff';
    const ultText = ultimateActive ? '필살기 활성' : ultimateCooldown > 0 ? `필살기 ${Math.ceil(ultimateCooldown / 60)}초` : '필살기 준비 (Z)';
    ctx.fillText(ultText, ultBarX + 4, ultBarY + 9);
}

function drawLevelUpPanel() {
    const rowHeight = 52;
    const panelH = pendingLevelUpChoices.length >= 4 ? 332 : 280;
    const baseY = canvas.height / 2 - panelH / 2 + 95;
    ctx.fillStyle = 'rgba(0, 0, 0, 0.85)';
    ctx.fillRect(canvas.width / 2 - 200, canvas.height / 2 - panelH / 2, 400, panelH);
    ctx.strokeStyle = '#ffd700';
    ctx.lineWidth = 3;
    ctx.strokeRect(canvas.width / 2 - 200, canvas.height / 2 - panelH / 2, 400, panelH);
    ctx.fillStyle = '#ffd700';
    ctx.font = 'bold 22px Arial';
    ctx.textAlign = 'center';
    ctx.fillText('레벨 업! 강화를 선택하세요', canvas.width / 2, canvas.height / 2 - panelH / 2 + 38);
    ctx.font = '18px Arial';
    ctx.fillStyle = '#fff';
    ctx.textAlign = 'center';
    pendingLevelUpChoices.forEach((opt, i) => {
        const y = baseY + i * rowHeight;
        const mainText = `${i + 1}. ${opt.name}`;
        ctx.fillText(mainText, canvas.width / 2, y);
        if (i === 3 && pendingLevelUpChoices.length >= 4) {
            ctx.font = 'bold 14px Arial';
            ctx.fillStyle = '#ff6b35';
            const w = ctx.measureText(mainText).width;
            ctx.textAlign = 'left';
            ctx.fillText('   X2 bonus', canvas.width / 2 + w / 2 + 6, y);
            ctx.textAlign = 'center';
            ctx.font = '18px Arial';
            ctx.fillStyle = '#fff';
        }
        if (opt.detail) {
            ctx.font = '13px Arial';
            ctx.fillStyle = '#b8b8b8';
            ctx.fillText(opt.detail, canvas.width / 2, y + 20);
            ctx.font = '18px Arial';
            ctx.fillStyle = '#fff';
        }
    });
    ctx.fillStyle = '#aaa';
    ctx.font = '14px Arial';
    const keyHint = pendingLevelUpChoices.length >= 4 ? '1~4 키로 선택' : '1, 2, 3 키로 선택';
    ctx.fillText(`${keyHint}  /  5: 선택포기`, canvas.width / 2, canvas.height / 2 + panelH / 2 - 22);
    ctx.textAlign = 'left';
}

function draw() {
    ctx.fillStyle = '#1a1a2e';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
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
    if (ultimateActive && selectedCharacter === 1) {
        ultimateWaves.forEach(wave => {
            const alpha = Math.max(0, 1 - wave.radius / wave.maxRadius);
            ctx.strokeStyle = `rgba(100, 200, 255, ${alpha * 0.8})`;
            ctx.lineWidth = 4;
            ctx.beginPath();
            ctx.arc(wave.x, wave.y, wave.radius, 0, Math.PI * 2);
            ctx.stroke();
        });
    }
    if (ultimateActive && selectedCharacter === 2) {
        const speedLines = 8;
        for (let i = 0; i < speedLines; i++) {
            const angle = (i / speedLines) * Math.PI * 2 + gameTime * 0.2;
            const dist = 30 + Math.sin(gameTime * 0.1 + i) * 10;
            const x1 = player.x + Math.cos(angle) * dist;
            const y1 = player.y + Math.sin(angle) * dist;
            const x2 = player.x + Math.cos(angle) * (dist + 15);
            const y2 = player.y + Math.sin(angle) * (dist + 15);
            ctx.strokeStyle = 'rgba(255, 200, 50, 0.6)';
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.moveTo(x1, y1);
            ctx.lineTo(x2, y2);
            ctx.stroke();
        }
    }
    heartPickups.forEach(h => drawHeart(h.x, h.y, 14));
    expOrbs.forEach(orb => {
        const maxLife = orb.maxLife != null ? orb.maxLife : EXP_ORB_LIFE;
        const a = orb.life / maxLife;
        ctx.save();
        ctx.translate(orb.x, orb.y);
        ctx.rotate(Math.PI / 4);
        ctx.fillStyle = `rgba(50, 205, 130, ${a})`;
        ctx.strokeStyle = `rgba(144, 238, 144, ${a})`;
        ctx.lineWidth = 2;
        ctx.beginPath();
        const r = (orb.radius != null ? orb.radius : 8) * 1.2;
        ctx.moveTo(r, 0); ctx.lineTo(0, r); ctx.lineTo(-r, 0); ctx.lineTo(0, -r);
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
        ctx.restore();
    });
    monsters.forEach(monster => {
        const r = monster.radius, half = r * 0.7;
        const isTough = monster.maxHealth > 1;
        const isBoss = monster.isBoss === true;
        const drawX = monster.x + (monster.shakeX || 0);
        const drawY = monster.y + (monster.shakeY || 0);
        const isTeleportWindup = isBoss && monster.bossBehaviorState === 'teleport_windup';
        const isTremble = isBoss && monster.bossBehaviorState === 'tremble';
        if (isTeleportWindup) {
            const pulse = 0.6 + 0.2 * Math.sin(gameTime * 0.35);
            ctx.globalAlpha = pulse;
        }
        ctx.save();
        ctx.translate(drawX + 2, drawY + 2);
        ctx.rotate(Math.PI / 4);
        ctx.fillStyle = 'rgba(0, 0, 0, 0.4)';
        ctx.fillRect(-half, -half, r * 1.4, r * 1.4);
        ctx.restore();
        ctx.save();
        ctx.translate(drawX, drawY);
        ctx.rotate(Math.PI / 4);
        if (isBoss) {
            const outer = half * 1.5;
            ctx.fillStyle = 'rgba(60, 10, 30, 0.6)';
            ctx.strokeStyle = isTremble ? 'rgba(255, 220, 100, 0.95)' : 'rgba(255, 180, 50, 0.95)';
            ctx.lineWidth = isTremble ? 4 : 3;
            ctx.fillRect(-outer, -outer, outer * 2, outer * 2);
            ctx.strokeRect(-outer, -outer, outer * 2, outer * 2);
        } else if (isTough) {
            const outer = half * 1.35;
            ctx.fillStyle = 'rgba(80, 20, 20, 0.5)';
            ctx.strokeStyle = 'rgba(180, 40, 40, 0.9)';
            ctx.lineWidth = 2;
            ctx.fillRect(-outer, -outer, outer * 2, outer * 2);
            ctx.strokeRect(-outer, -outer, outer * 2, outer * 2);
        }
        ctx.fillStyle = monster.color;
        ctx.fillRect(-half, -half, r * 1.4, r * 1.4);
        ctx.strokeStyle = isBoss ? 'rgba(255, 200, 80, 0.95)' : (isTough ? 'rgba(220, 80, 80, 0.95)' : 'rgba(200, 60, 60, 0.9)');
        ctx.lineWidth = isBoss ? 3 : (isTough ? 2 : 1.5);
        ctx.strokeRect(-half, -half, r * 1.4, r * 1.4);
        ctx.restore();
        if (isTeleportWindup) ctx.globalAlpha = 1;
        if (monster.health < monster.maxHealth) {
            const barWidth = monster.radius * 2, barHeight = 4;
            const barY = drawY - monster.radius - 12;
            ctx.fillStyle = 'rgba(80,0,0,0.8)';
            ctx.fillRect(drawX - barWidth / 2, barY, barWidth, barHeight);
            ctx.fillStyle = '#8b0000';
            ctx.fillRect(drawX - barWidth / 2, barY,
                barWidth * (monster.health / monster.maxHealth), barHeight);
        }
    });
    bossMissiles.forEach(m => {
        ctx.save();
        ctx.fillStyle = '#ff4444';
        ctx.strokeStyle = '#cc2222';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.arc(m.x, m.y, m.radius, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
        ctx.restore();
    });
    weapons.forEach(weapon => {
        if (!weapon.projectiles) return;
        weapon.projectiles.forEach(projectile => {
            const r = projectile.radius;
            if (weapon.type === 'shotgun') {
                const colors = getWeaponLevelColor(weapon, '#ffcc66', '#cc9933');
                ctx.save();
                if (colors.glow) {
                    ctx.shadowBlur = 10;
                    ctx.shadowColor = colors.glowColor;
                }
                ctx.fillStyle = colors.fill;
                ctx.strokeStyle = colors.stroke;
                ctx.lineWidth = colors.lineWidth;
                ctx.beginPath();
                ctx.arc(projectile.x, projectile.y, r, 0, Math.PI * 2);
                ctx.fill();
                ctx.stroke();
                ctx.shadowBlur = 0;
                ctx.restore();
                return;
            }
            const angle = projectile.returning
                ? Math.atan2(player.y - projectile.y, player.x - projectile.x)
                : Math.atan2(projectile.vy, projectile.vx);
            const isBoomerang = weapon.type === 'boomerang';
            const colors = getWeaponLevelColor(weapon, isBoomerang ? '#9b59b6' : '#00d4ff', isBoomerang ? '#8e44ad' : '#7df9ff');
            ctx.save();
            if (colors.glow) {
                ctx.shadowBlur = 12;
                ctx.shadowColor = colors.glowColor;
            }
            ctx.translate(projectile.x, projectile.y);
            ctx.rotate(angle);
            ctx.fillStyle = colors.fill;
            ctx.strokeStyle = colors.stroke;
            ctx.lineWidth = colors.lineWidth;
            if (isBoomerang) {
                ctx.beginPath();
                ctx.arc(0, 0, r * 1.4, -Math.PI / 2, Math.PI / 2);
                ctx.closePath();
                ctx.fill();
                ctx.stroke();
            } else {
                ctx.beginPath();
                ctx.moveTo(r * 1.4, 0); ctx.lineTo(-r * 1.1, r * 1.1); ctx.lineTo(-r * 0.4, 0); ctx.lineTo(-r * 1.1, -r * 1.1);
                ctx.closePath();
                ctx.fill();
                ctx.stroke();
            }
            ctx.shadowBlur = 0;
            ctx.restore();
        });
    });
    weapons.forEach(weapon => {
        if (weapon.type !== 'orbit') return;
        const r = weapon.orbRadius;
        const imgReady = orbitImage.complete && orbitImage.naturalWidth > 0;
        const colors = getWeaponLevelColor(weapon, '#f1c40f', '#f39c12');
        weapon.orbAngles.forEach(angle => {
            const ox = player.x + Math.cos(angle) * weapon.radius;
            const oy = player.y + Math.sin(angle) * weapon.radius;
            ctx.save();
            if (colors.glow) {
                ctx.shadowBlur = 15;
                ctx.shadowColor = colors.glowColor;
            }
            if (imgReady) {
                ctx.beginPath();
                ctx.arc(ox, oy, r, 0, Math.PI * 2);
                ctx.closePath();
                ctx.clip();
                ctx.drawImage(orbitImage, ox - r, oy - r, r * 2, r * 2);
                ctx.restore();
                ctx.save();
                if (colors.glow) {
                    ctx.shadowBlur = 15;
                    ctx.shadowColor = colors.glowColor;
                }
                ctx.strokeStyle = colors.stroke;
                ctx.lineWidth = colors.lineWidth;
                ctx.beginPath();
                ctx.arc(ox, oy, r, 0, Math.PI * 2);
                ctx.stroke();
            } else {
                ctx.fillStyle = colors.fill;
                ctx.strokeStyle = colors.stroke;
                ctx.lineWidth = colors.lineWidth;
                ctx.beginPath();
                ctx.arc(ox, oy, r, 0, Math.PI * 2);
                ctx.fill();
                ctx.stroke();
            }
            ctx.shadowBlur = 0;
            ctx.restore();
        });
    });
    weapons.forEach(weapon => {
        if (weapon.type === 'laser' && weapon.beamTimer > 0) {
            const angle = getPlayerLastMoveAngle();
            const ex = player.x + Math.cos(angle) * weapon.range;
            const ey = player.y + Math.sin(angle) * weapon.range;
            const colors = getWeaponLevelColor(weapon, '#ff96c8', '#ff69b4');
            ctx.save();
            if (colors.glow) {
                ctx.shadowBlur = 20;
                ctx.shadowColor = colors.glowColor;
            }
            ctx.strokeStyle = colors.stroke.includes('rgba') ? colors.stroke : colors.stroke.replace(')', ', 0.7)').replace('hsl', 'hsla');
            ctx.lineWidth = 4 + (weapon.level >= 5 ? 1 : 0);
            ctx.beginPath();
            ctx.moveTo(player.x, player.y);
            ctx.lineTo(ex, ey);
            ctx.stroke();
            ctx.shadowBlur = 0;
            ctx.restore();
        }
    });
    weapons.forEach(weapon => {
        if (weapon.type === 'sword' && weapon.swingInstances && weapon.swingInstances.length > 0) {
            const swingFrames = 12;
            weapon.swingInstances.forEach((inst, idx) => {
                if (inst.swingTimer <= 0) return;
                const angle = inst.swingAngle != null ? inst.swingAngle : getPlayerLastMoveAngle();
                const progress = 1 - inst.swingTimer / swingFrames;
                const startAngle = angle - weapon.arcAngle / 2;
                const sweepAngle = weapon.arcAngle * progress;
                if (sweepAngle > 0.01) {
                    const opacity = 0.35 + 0.2 * (inst.swingTimer / swingFrames);
                    ctx.beginPath();
                    ctx.moveTo(player.x, player.y);
                    ctx.arc(player.x, player.y, weapon.range, startAngle, startAngle + sweepAngle);
                    ctx.closePath();
                    ctx.fillStyle = `rgba(180, 200, 255, ${opacity})`;
                    ctx.fill();
                    ctx.strokeStyle = `rgba(255, 255, 255, ${0.5 + 0.35 * (inst.swingTimer / swingFrames)})`;
                    ctx.lineWidth = 3;
                    ctx.stroke();
                }
            });
        }
    });
    weapons.forEach(weapon => {
        if (weapon.type === 'whip' && weapon.swingTimer > 0) {
            const angle = getPlayerLastMoveAngle();
            const colors = getWeaponLevelColor(weapon, '#ffc864', '#ff9933');
            ctx.save();
            if (colors.glow) {
                ctx.shadowBlur = 25;
                ctx.shadowColor = colors.glowColor;
            }
            ctx.strokeStyle = colors.stroke.includes('rgba') ? colors.stroke : colors.stroke.replace(')', ', 0.8)').replace('hsl', 'hsla');
            ctx.lineWidth = 12 + (weapon.level >= 10 ? 2 : weapon.level >= 5 ? 1 : 0);
            ctx.beginPath();
            ctx.arc(player.x, player.y, weapon.range, angle - weapon.arcAngle / 2, angle + weapon.arcAngle / 2);
            ctx.stroke();
            ctx.shadowBlur = 0;
            ctx.restore();
        }
    });
    const blink = player.invincible && Math.floor(player.invincibleTimer / 5) % 2 === 0;
    if (!blink) {
        const baseR = player.radius;
        const r = ultimateActive && selectedCharacter === 0 ? baseR * 3 : baseR;
        const imgReady = playerImage.complete && playerImage.naturalWidth > 0;
        if (ultimateActive && selectedCharacter === 0) {
            const glow = 0.5 + 0.3 * Math.sin(gameTime * 0.15);
            ctx.shadowBlur = 30 + glow * 20;
            ctx.shadowColor = '#ffd700';
        }
        if (imgReady) {
            ctx.save();
            ctx.beginPath();
            ctx.arc(player.x, player.y, r, 0, Math.PI * 2);
            ctx.closePath();
            ctx.clip();
            ctx.drawImage(playerImage, player.x - r, player.y - r, r * 2, r * 2);
            ctx.restore();
        } else {
            ctx.shadowBlur = ultimateActive && selectedCharacter === 0 ? 30 : 20;
            ctx.shadowColor = ultimateActive && selectedCharacter === 0 ? '#ffd700' : player.color;
            ctx.fillStyle = player.color;
            ctx.beginPath();
            ctx.arc(player.x, player.y, r, 0, Math.PI * 2);
            ctx.fill();
            ctx.shadowBlur = 0;
        }
        ctx.strokeStyle = ultimateActive && selectedCharacter === 0 ? '#ffd700' : '#fff';
        ctx.lineWidth = ultimateActive && selectedCharacter === 0 ? 4 : 2;
        ctx.beginPath();
        ctx.arc(player.x, player.y, r, 0, Math.PI * 2);
        ctx.stroke();
        ctx.shadowBlur = 0;
    }
    const shotgunWeapon = weapons.find(w => w.type === 'shotgun');
    if (shotgunWeapon) {
        const ax = player.x;
        const ay = player.y - player.radius - 18;
        const maxM = shotgunWeapon.maxMagazine || 2;
        const mag = shotgunWeapon.magazine || 0;
        const relTimer = shotgunWeapon.reloadTimer || 0;
        const relTotal = shotgunWeapon.reloadOneFrames || 120;
        ctx.save();
        ctx.fillStyle = 'rgba(0,0,0,0.7)';
        ctx.strokeStyle = 'rgba(255,220,150,0.9)';
        ctx.lineWidth = 1.5;
        const boxW = maxM * 10 + 12;
        const boxH = 14;
        ctx.fillRect(ax - boxW / 2, ay - boxH / 2, boxW, boxH);
        ctx.strokeRect(ax - boxW / 2, ay - boxH / 2, boxW, boxH);
        for (let i = 0; i < maxM; i++) {
            const bx = ax - boxW / 2 + 8 + i * 10;
            if (i < mag) {
                ctx.fillStyle = '#ffcc66';
                ctx.strokeStyle = '#cc9933';
            } else if (relTimer > 0 && i === mag) {
                ctx.fillStyle = 'rgba(255,200,80,' + (0.3 + 0.5 * (1 - relTimer / relTotal)) + ')';
                ctx.strokeStyle = '#cc9933';
            } else {
                ctx.fillStyle = 'rgba(80,80,80,0.6)';
                ctx.strokeStyle = 'rgba(100,100,100,0.8)';
            }
            ctx.beginPath();
            ctx.arc(bx, ay, 4, 0, Math.PI * 2);
            ctx.fill();
            ctx.stroke();
        }
        ctx.restore();
    }
    drawGameUI();
    const { currentWave, showWavePopup } = getWaveInfo();
    if (showWavePopup && !levelUpPaused) {
        ctx.save();
        ctx.font = 'bold 48px Arial';
        ctx.textAlign = 'center';
        ctx.fillStyle = 'rgba(255, 215, 0, 0.95)';
        ctx.strokeStyle = '#333';
        ctx.lineWidth = 3;
        const msg = `웨이브 ${currentWave}!`;
        ctx.strokeText(msg, canvas.width / 2, canvas.height / 2 - 20);
        ctx.fillText(msg, canvas.width / 2, canvas.height / 2 - 20);
        ctx.restore();
    }
    if (gamePaused) {
        ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        ctx.font = 'bold 42px Arial';
        ctx.textAlign = 'center';
        ctx.fillStyle = '#fff';
        ctx.fillText('멈춤', canvas.width / 2, canvas.height / 2 - 30);
        ctx.font = '20px Arial';
        ctx.fillStyle = '#ccc';
        ctx.fillText('스페이스: 재개', canvas.width / 2, canvas.height / 2 + 20);
    }
    if (levelUpPaused && pendingLevelUpChoices.length > 0) drawLevelUpPanel();
}
