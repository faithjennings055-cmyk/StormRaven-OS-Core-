/* StormRaven OS Mobile — network-first service worker (v4) */
const CACHE = 'stormraven-mobile-v4';
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
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
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
    url.pathname.startsWith('/iso/') ||
    url.pathname.startsWith('/downloads/') ||
    url.pathname.startsWith('/install-')
  ) {
    return;
  }

  // Always network-first so updates to index.html, app.js, and style.css appear immediately on reload
  e.respondWith(
    fetch(e.request, { cache: 'no-store' }).then((r) => {
      const copy = r.clone();
      caches.open(CACHE).then((c) => c.put(e.request, copy));
      return r;
    }).catch(() => caches.match(e.request).then((m) => m || caches.match('./index.html')))
  );
});
