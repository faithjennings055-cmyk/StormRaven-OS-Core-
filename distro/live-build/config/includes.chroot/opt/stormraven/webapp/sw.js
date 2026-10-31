/* StormRaven OS Mobile — offline shell service worker */
const CACHE = 'stormraven-mobile-v2';
const SHELL = [
  './',
  './index.html',
  './style.css',
  './app.js',
  './manifest.json',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/apple-touch-icon.png'
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  // never cache API/WS/installer traffic to the kernel gateway
  if (
    url.pathname.startsWith('/status') ||
    url.pathname.startsWith('/health') ||
    url.pathname.startsWith('/state') ||
    url.pathname.startsWith('/tabs') ||
    url.pathname.startsWith('/decisions') ||
    url.pathname.startsWith('/commands') ||
    url.pathname.startsWith('/command') ||
    url.pathname.startsWith('/signals') ||
    url.pathname.startsWith('/events') ||
    url.pathname.startsWith('/ws') ||
    url.pathname.startsWith('/install-mobile.sh')
  ) {
    return;
  }

  if (e.request.mode === 'navigate') {
    e.respondWith(
      fetch(e.request).then((r) => {
        const copy = r.clone();
        caches.open(CACHE).then((c) => c.put(e.request, copy));
        return r;
      }).catch(() => caches.match(e.request).then((m) => m || caches.match('./index.html')))
    );
    return;
  }

  e.respondWith(
    caches.match(e.request).then((m) => m || fetch(e.request).then((r) => {
      const copy = r.clone();
      caches.open(CACHE).then((c) => c.put(e.request, copy));
      return r;
    }))
  );
});
