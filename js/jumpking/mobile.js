(() => {
    'use strict';
    const frame = document.getElementById('gameFrame');
    const shell = document.getElementById('gameShell');
    const menu = document.getElementById('gameMenu');
    const resume = document.getElementById('resumeBtn');
    const restart = document.getElementById('restartBtn');
    const title = document.getElementById('menuTitle');
    const description = document.getElementById('menuDescription');
    const status = document.getElementById('loadStatus');
    const meter = document.getElementById('chargeMeter');
    const fill = document.getElementById('chargeFill');
    const chargeLabel = document.getElementById('chargeLabel');
    const fullscreen = document.getElementById('fullscreenBtn');
    const install = document.getElementById('installBtn');
    const coarse = matchMedia('(any-pointer: coarse)');
    const joystick = document.getElementById('joystick');
    const knob = document.getElementById('joystickKnob');
    let stickPointer = null;
    let stickAction = null;
    const pointers = new Map();
    const keyboard = new Map();
    const buttons = [...document.querySelectorAll('[data-action]')];
    const keyActions = { ArrowLeft: 'move_left', a: 'move_left', A: 'move_left', ArrowRight: 'move_right', d: 'move_right', D: 'move_right', ' ': 'jump' };
    let ready = false;
    let started = false;
    let won = false;
    let installPrompt;

    function send(command) {
        if (typeof frame.contentWindow?.minigameCommand !== 'function') return false;
        frame.contentWindow.minigameCommand(JSON.stringify(command));
        return true;
    }
    function isHeld(action) {
        return stickAction === action || [...pointers.values(), ...keyboard.values()].includes(action);
    }
    function paintButtons() {
        buttons.forEach(button => button.classList.toggle('pressed', isHeld(button.dataset.action)));
    }
    function clearInput() {
        stickPointer = null;
        stickAction = null;
        joystick.classList.remove('active');
        knob.style.transform = 'translate(0px, 0px)';
        joystick.setAttribute('aria-valuenow', '0');
        joystick.setAttribute('aria-valuetext', '가운데');
        pointers.clear();
        keyboard.clear();
        paintButtons();
        send({ type: 'cancel' });
        fill.style.transform = 'scaleX(0)';
        meter.setAttribute('aria-valuenow', '0');
        chargeLabel.textContent = '눌러서 충전';
    }
    function openMenu() {
        clearInput();
        send({ type: 'pause', paused: true });
        if (started) {
            title.textContent = won ? '정상 도착!' : '잠시 쉬어가기';
            description.textContent = won ? '축하합니다! 모든 발판을 올랐어요.' : '준비되면 이어서 올라가세요.';
        }
        if (!menu.open) menu.showModal();
    }
    function closeMenu() {
        if (!ready) return;
        started = true;
        restart.hidden = false;
        resume.textContent = '계속하기';
        clearInput();
        menu.close();
        send({ type: 'pause', paused: false });
        if (!coarse.matches) frame.focus();
    }
    async function enterFullscreen() {
        if (!document.fullscreenElement && shell.requestFullscreen) {
            try {
                await shell.requestFullscreen();
                if (coarse.matches && screen.orientation?.lock) {
                    await screen.orientation.lock('landscape').catch(() => {});
                }
            } catch { /* The layout already fills the browser when fullscreen is unavailable. */ }
        }
    }

    function updateStick(event) {
        if (event.pointerId !== stickPointer) return;
        const rect = joystick.getBoundingClientRect();
        let dx = event.clientX - rect.left - rect.width / 2;
        let dy = event.clientY - rect.top - rect.height / 2;
        const distance = Math.hypot(dx, dy);
        const radius = 32;
        if (distance > radius) { dx *= radius / distance; dy *= radius / distance; }
        knob.style.transform = `translate(${dx}px, ${dy}px)`;
        const nextAction = Math.abs(dx) < 10 ? null : dx < 0 ? 'move_left' : 'move_right';
        const previousAction = stickAction;
        stickAction = nextAction;
        if (previousAction && previousAction !== nextAction && !isHeld(previousAction)) {
            send({ type: 'input', action: previousAction, pressed: false });
        }
        if (nextAction) {
            const strength = Math.min(1, .25 + .75 * (Math.abs(dx) - 10) / (radius - 10));
            send({ type: 'input', action: nextAction, pressed: true, strength: [...keyboard.values()].includes(nextAction) ? 1 : strength });
        }
        const value = nextAction === 'move_left' ? -1 : nextAction === 'move_right' ? 1 : 0;
        joystick.setAttribute('aria-valuenow', String(value));
        joystick.setAttribute('aria-valuetext', value < 0 ? '왼쪽' : value > 0 ? '오른쪽' : '가운데');
    }
    joystick.addEventListener('contextmenu', event => event.preventDefault());
    joystick.addEventListener('pointerdown', event => {
        if (event.button !== 0 || stickPointer !== null || !ready || !started || menu.open) return;
        event.preventDefault();
        stickPointer = event.pointerId;
        joystick.classList.add('active');
        joystick.setPointerCapture(event.pointerId);
        updateStick(event);
    });
    joystick.addEventListener('pointermove', event => {
        if (event.pointerId !== stickPointer) return;
        event.preventDefault();
        updateStick(event);
    });
    function releaseStick(event) {
        if (event.pointerId !== stickPointer) return;
        const previousAction = stickAction;
        stickPointer = null;
        stickAction = null;
        joystick.classList.remove('active');
        knob.style.transform = 'translate(0px, 0px)';
        joystick.setAttribute('aria-valuenow', '0');
        joystick.setAttribute('aria-valuetext', '가운데');
        if (previousAction) send({ type: 'input', action: previousAction, pressed: isHeld(previousAction) });
    }
    joystick.addEventListener('pointerup', releaseStick);
    joystick.addEventListener('pointercancel', event => { if (event.pointerId === stickPointer) clearInput(); });
    joystick.addEventListener('lostpointercapture', releaseStick);

    buttons.forEach(button => {
        button.addEventListener('contextmenu', event => event.preventDefault());
        button.addEventListener('pointerdown', event => {
            if (event.button !== 0 || !ready || !started || menu.open) return;
            event.preventDefault();
            const action = button.dataset.action;
            const held = isHeld(action);
            pointers.set(event.pointerId, action);
            button.setPointerCapture(event.pointerId);
            if (!held) send({ type: 'input', action, pressed: true });
            paintButtons();
        });
        const release = event => {
            if (!pointers.has(event.pointerId)) return;
            event.preventDefault();
            const action = pointers.get(event.pointerId);
            pointers.delete(event.pointerId);
            if (!isHeld(action)) send({ type: 'input', action, pressed: false });
            paintButtons();
        };
        button.addEventListener('pointerup', release);
        button.addEventListener('pointercancel', clearInput);
        button.addEventListener('lostpointercapture', event => {
            if (pointers.has(event.pointerId)) clearInput();
        });
    });
    window.addEventListener('keydown', event => {
        if (menu.open || !ready || !started || event.ctrlKey || event.metaKey || event.altKey) return;
        if (event.key === 'Escape') { event.preventDefault(); openMenu(); return; }
        if (event.key === 'r' || event.key === 'R') { event.preventDefault(); restartGame(); return; }
        const action = keyActions[event.key];
        if (!action) return;
        event.preventDefault();
        if (keyboard.has(event.code)) return;
        const held = isHeld(action);
        keyboard.set(event.code, action);
        if (!held) send({ type: 'input', action, pressed: true });
        paintButtons();
    });
    window.addEventListener('keyup', event => {
        const action = keyboard.get(event.code);
        if (!action) return;
        event.preventDefault();
        keyboard.delete(event.code);
        if (!isHeld(action)) send({ type: 'input', action, pressed: false });
        paintButtons();
    });
    window.addEventListener('blur', clearInput);
    window.addEventListener('pagehide', () => { clearInput(); send({ type: 'pause', paused: true }); });
    document.addEventListener('visibilitychange', () => {
        if (document.hidden) openMenu();
    });
    window.addEventListener('resize', clearInput);
    window.visualViewport?.addEventListener('resize', clearInput);
    window.addEventListener('message', event => {
        if (event.source !== frame.contentWindow || event.origin !== location.origin || !event.data) return;
        if (event.data.type === 'jumpking-ready') {
            ready = true;
            resume.disabled = false;
            resume.textContent = started ? '계속하기' : '게임 시작';
            status.textContent = '';
            send({ type: 'pause', paused: menu.open || document.hidden });
        } else if (event.data.type === 'jumpking-menu') {
            openMenu();
        } else if (event.data.type === 'jumpking-state') {
            document.getElementById('heightDisplay').textContent = `${Math.max(0, Number(event.data.height) || 0)} m`;
            const percent = Math.round(Math.max(0, Math.min(1, Number(event.data.charge) || 0)) * 100);
            fill.style.transform = `scaleX(${percent / 100})`;
            meter.setAttribute('aria-valuenow', String(percent));
            chargeLabel.textContent = event.data.charging ? (percent === 100 ? '최대 충전!' : `${percent}% 충전`) : '눌러서 충전';
            if (event.data.won && !won) {
                won = true;
                document.getElementById('gameAnnouncement').textContent = '정상에 도착했습니다!';
                openMenu();
            }
        }
    });
    function restartGame() {
        if (!ready) return;
        clearInput();
        ready = false;
        won = false;
        started = true;
        resume.disabled = true;
        resume.textContent = '게임 불러오는 중…';
        status.textContent = '';
        menu.close();
        send({ type: 'restart' });
        if (!coarse.matches) frame.focus();
    }
    document.getElementById('menuBtn').addEventListener('click', openMenu);
    resume.addEventListener('click', () => {
        const firstStart = !started;
        closeMenu();
        if (firstStart && coarse.matches) void enterFullscreen();
    });
    restart.addEventListener('click', restartGame);
    menu.addEventListener('cancel', event => { event.preventDefault(); if (started) closeMenu(); });
    fullscreen.addEventListener('click', async () => {
        clearInput();
        if (document.fullscreenElement) await document.exitFullscreen().catch(() => {});
        else await enterFullscreen();
    });
    document.addEventListener('fullscreenchange', () => {
        const expanded = Boolean(document.fullscreenElement);
        fullscreen.setAttribute('aria-label', expanded ? '전체 화면 종료' : '전체 화면');
        fullscreen.textContent = expanded ? '⛶ 축소' : '⛶ 화면';
        if (!expanded) screen.orientation?.unlock?.();
        clearInput();
    });
    frame.addEventListener('load', () => {
        // Also covers restoring a page whose iframe has already initialized.
        if (typeof frame.contentWindow?.minigameCommand === 'function') {
            ready = true;
            resume.disabled = false;
            resume.textContent = started ? '계속하기' : '게임 시작';
            status.textContent = '';
            send({ type: 'pause', paused: menu.open });
        }
    });
    window.setTimeout(() => {
        if (!ready) status.textContent = '아직 불러오는 중입니다. 인터넷 연결을 확인하고, 게임 화면에 오류가 표시되면 새로고침해 주세요.';
    }, 45000);
    window.addEventListener('beforeinstallprompt', event => {
        event.preventDefault();
        installPrompt = event;
        install.hidden = false;
    });
    install.addEventListener('click', async () => {
        if (!installPrompt) return;
        await installPrompt.prompt();
        await installPrompt.userChoice;
        installPrompt = undefined;
        install.hidden = true;
    });
    window.addEventListener('appinstalled', () => { install.hidden = true; });
    const standalone = matchMedia('(display-mode: standalone)').matches || navigator.standalone;
    if (!standalone && /iPad|iPhone|iPod/.test(navigator.userAgent)) document.getElementById('installHint').hidden = false;
    if ('serviceWorker' in navigator) {
        // This worker only caches the sky-steps page and assets, not other games.
        navigator.serviceWorker.register('jumpking-sw.js').catch(() => {});
    }
    openMenu();
})();
