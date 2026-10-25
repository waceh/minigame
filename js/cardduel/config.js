// After deployment, put the HTTPS Workers URL here. No keys or secrets belong here.
const CARD_DUEL_PRODUCTION_SERVER = '';
window.CARD_DUEL_SERVER = CARD_DUEL_PRODUCTION_SERVER || (
    ['localhost', '127.0.0.1', '::1'].includes(location.hostname)
        ? `${location.protocol}//${location.hostname}:8787`
        : ''
);
