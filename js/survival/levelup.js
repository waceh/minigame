/**
 * 레벨업 선택지 표시 및 적용 (보조무기 최대 2개)
 */
function isSupplementaryOpt(opt) {
    return opt.id === 'subUpgrade' || SUPPLEMENTARY_TYPES.includes(opt.id);
}

function showLevelUpChoices() {
    levelUpPaused = true;
    const pool = getLevelUpOptions();
    pendingLevelUpChoices = [];
    const maxChoices = Math.max(3, Math.min(4, levelUpChoiceCount || 3));
    const shuffled = pool.slice().sort(() => Math.random() - 0.5);
    let suppCount = 0;
    for (const opt of shuffled) {
        if (pendingLevelUpChoices.length >= maxChoices) break;
        if (isSupplementaryOpt(opt)) {
            if (suppCount >= 2) continue;
            suppCount++;
        }
        pendingLevelUpChoices.push(opt);
    }
    levelUpChoiceCount = 3;
    const mobileChoices = document.querySelector('.mobile-upgrades');
    mobileChoices.classList.add('show');
    mobileChoices.querySelectorAll('[data-choice]').forEach(button => {
        const index = Number(button.dataset.choice);
        if (Number.isNaN(index)) return;
        const option = pendingLevelUpChoices[index];
        button.hidden = !option;
        if (option) button.textContent = `${index + 1}. ${option.name}${option.detail ? ` · ${option.detail}` : ''}`;
    });
}

function applyLevelUpChoice(index) {
    if (index < 0 || index >= pendingLevelUpChoices.length) return;
    const opt = pendingLevelUpChoices[index];
    opt.apply();
    if (index === 3 && pendingLevelUpChoices.length >= 4) opt.apply();
    pendingLevelUpChoices = [];
    levelUpPaused = false;
    document.querySelector('.mobile-upgrades').classList.remove('show');
}
