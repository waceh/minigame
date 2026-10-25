// Bump VERSION together with the shell and web export when publishing a new build.
const VERSION = '1.3.1';
const CACHE = `jumpking-${VERSION}`;
const root = new URL('./', self.location.href);
const assets = [
    'jumpking.html', 'jumpking.webmanifest',
    `css/jumpking.css?v=${VERSION}`, `js/jumpking/mobile.js?v=${VERSION}`,
    'img/jumpking-192.png', 'img/jumpking-512.png',
    `jumpking/web/index.html?v=${VERSION}`, `jumpking/web/index.pck?v=${VERSION}`,
    'jumpking/web/index.js', 'jumpking/web/index.wasm',
    'jumpking/web/index.audio.worklet.js', 'jumpking/web/index.audio.position.worklet.js',
    'jumpking/web/index.png', 'jumpking/web/index.icon.png', 'jumpking/web/index.apple-touch-icon.png'
].map(path => new URL(path, root).href);
self.addEventListener('install', event => {
    event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(assets)));
    // Activate on the next launch, so an ongoing run never mixes two builds.
});
self.addEventListener('activate', event => {
    event.waitUntil(caches.keys().then(keys => Promise.all(
        keys.filter(key => key.startsWith('jumpking-') && key !== CACHE).map(key => caches.delete(key))
    )));
});
self.addEventListener('fetch', event => {
    if (event.request.method !== 'GET' || !assets.includes(event.request.url)) return;
    event.respondWith(caches.open(CACHE).then(async cache => {
        const cached = await cache.match(event.request);
        return cached || fetch(event.request);
    }));
});
