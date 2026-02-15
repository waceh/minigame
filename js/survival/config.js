/**
 * 게임 설정 상수
 */
const CANVAS_WIDTH = 1360;
const CANVAS_HEIGHT = 768;

const WAVE_INTERVAL_SEC = 30;
const BOSS_WAVE_INTERVAL_SEC = 60;

const CHARACTERS = [
    { name: '1번 캐릭터', image: 'img/c1.jpg', maxHp: 3, damageBonus: 0.5, trait: '체력 ↓ / 공격력 ↑' },
    { name: '2번 캐릭터', image: 'img/c2.jpg', maxHp: 7, speedBonus: -1.2, trait: '체력 ↑ / 이속 ↓' },
    { name: '3번 캐릭터', image: 'img/c3.png', damageBonus: -0.25, cooldownBonus: -6, speedBonus: 0.4, trait: '공속·이속 ↑ / 공격력 ↓' }
];

const DIFFICULTY = {
    easy:   { name: '이지',   speedMult: 0.7,  spawnMult: 0.6,  irregularity: 0.2  },
    normal: { name: '노멀',   speedMult: 1.2,  spawnMult: 1,    irregularity: 0.5  },
    hard:   { name: '하드',   speedMult: 1.8,  spawnMult: 1.4,  irregularity: 0.9  }
};

const SUPPLEMENTARY_TYPES = ['whip', 'orbit', 'shotgun', 'boomerang', 'laser'];
const SUPPLEMENTARY_NAMES = {
    whip: '휩',
    orbit: '오비트',
    shotgun: '샷건',
    boomerang: '부메랑',
    laser: '레이저'
};

const HEART_DROP_CHANCE = 0.015;
const EXP_ORB_LIFE = 600;
const BOSS_WAVES = [5, 10, 15, 20];
const MAX_WAVE = 20;

const INVINCIBLE_DURATION = 120;
const ULTIMATE_DURATION = 600;
const ULTIMATE_COOLDOWN = 3600;
