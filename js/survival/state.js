/**
 * 캔버스 및 게임 상태
 */
const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');
function setCanvasSize() {
    const reserved = 140;
    const availableH = Math.max(400, window.innerHeight - reserved);
    const targetH = Math.min(CANVAS_HEIGHT, Math.round(availableH));
    const targetW = Math.round(targetH * (CANVAS_WIDTH / CANVAS_HEIGHT));
    if (targetW > window.innerWidth * 0.95) {
        canvas.width = Math.min(CANVAS_WIDTH, Math.round(window.innerWidth * 0.95));
        canvas.height = Math.round(canvas.width * (CANVAS_HEIGHT / CANVAS_WIDTH));
    } else {
        canvas.width = targetW;
        canvas.height = targetH;
    }
}
setCanvasSize();
window.addEventListener('resize', setCanvasSize);

let gameRunning = true;
let score = 0;
let highScore = localStorage.getItem('highScore') || 0;
let gameTime = 0;
let level = 1;
let expCurrent = 0;
let expToNextLevel = 10;
let levelUpPaused = false;
let gamePaused = false;

let selectedCharacter = 0;
const playerImage = new Image();
playerImage.src = CHARACTERS[selectedCharacter].image;

const orbitImage = new Image();
orbitImage.src = 'img/c3.png';

const heartImage = new Image();
heartImage.src = 'img/heart.png';

const heart16Image = new Image();
heart16Image.src = 'img/heart_16.png';

const player = {
    x: canvas.width / 2,
    y: canvas.height / 2,
    radius: 18,
    speed: 5,
    color: '#4ecdc4',
    maxHp: 5,
    hp: 5,
    invincible: false,
    invincibleTimer: 0,
    magnetRadius: 115,
    knockbackVx: 0,
    knockbackVy: 0,
    knockbackPower: 0
};

const keys = {};
const weapons = [];
const monsters = [];
const bossMissiles = [];
let monsterSpawnTimer = 0;
let monsterSpawnRate = 60;
const expOrbs = [];
const heartPickups = [];
let currentDifficulty = 'normal';
let pendingLevelUpChoices = [];
let levelUpChoiceCount = 3;
let lastMoveAngle = 0;
let lastBossWave = 0;
let gameWon = false;
let bossClearedTimer = 0;

function getWaveInfo() {
    const totalSec = Math.floor(gameTime / 60);
    const currentWave = getCurrentWave();
    const nextWaveStartSec = getWaveStartSec(currentWave + 1);
    const nextWaveSec = Math.max(0, nextWaveStartSec - totalSec);
    const waveStartFrame = getWaveStartSec(currentWave) * 60;
    const showWavePopup = gameTime >= waveStartFrame && (gameTime - waveStartFrame) < 120;
    return { currentWave, nextWaveSec, showWavePopup };
}
