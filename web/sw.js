'use strict';

// Service worker de la PWA (offline nivel A): la interfaz abre sin conexión,
// pero operar requiere red. No guarda respuestas del API ni fotos.
//
// Estrategia: primero la red y, si no hay conexión, la copia guardada. Los
// archivos de Flutter no llevan hash en el nombre (main.dart.js), así que
// servir primero la caché podría mezclar versiones.
//
// `tool/build_web.sh` reemplaza __BUILD_ID__ por el número de compilación;
// al cambiar el archivo, el navegador instala el nuevo service worker y se
// borran las copias de la versión anterior.

const BUILD_ID = '__BUILD_ID__';
const CACHE_PREFIX = 'instaladores-';
const CACHE = CACHE_PREFIX + BUILD_ID;

// Fuentes y motor de Flutter en los CDN de Google: sus URLs llevan versión,
// así que se pueden servir desde la caché.
const CDN_HOSTS = ['fonts.gstatic.com', 'www.gstatic.com'];

// Lo mínimo para abrir la app sin conexión. Lo demás (motor, fuentes,
// imágenes) se guarda conforme la app lo descarga.
const CORE = [
  './',
  'index.html',
  'pwa.js',
  'flutter_bootstrap.js',
  'main.dart.js',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'assets/AssetManifest.bin.json',
  'assets/FontManifest.json',
];

// Siempre de la red: con ellos se detecta una versión nueva.
const NEVER_CACHE = ['build.json', 'sw.js'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) =>
        Promise.all(CORE.map((url) => cache.add(url).catch(() => null))),
      )
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE)
            .map((key) => caches.delete(key)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

// La página avisa qué descargó antes de que este service worker la
// controlara (la primera visita), para guardarlo también.
self.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.type !== 'cache-urls' || !Array.isArray(data.urls)) return;
  const urls = data.urls.filter((url) => isCacheable(new URL(url)));
  event.waitUntil(
    caches.open(CACHE).then((cache) =>
      Promise.all(
        urls.map((url) =>
          cache.match(url).then((hit) => hit || cache.add(url).catch(() => null)),
        ),
      ),
    ),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (!isCacheable(url)) return;

  if (CDN_HOSTS.includes(url.hostname)) {
    event.respondWith(cacheFirst(request));
    return;
  }
  if (request.mode === 'navigate') {
    event.respondWith(networkFirst(request, 'index.html'));
    return;
  }
  event.respondWith(networkFirst(request));
});

/// Solo archivos de la app (dentro de su ruta) y de los CDN de Flutter. El
/// API y las fotos de S3 nunca se guardan.
function isCacheable(url) {
  if (CDN_HOSTS.includes(url.hostname)) return true;
  if (!url.href.startsWith(self.registration.scope)) return false;
  const path = url.href.slice(self.registration.scope.length).split('?')[0];
  return !NEVER_CACHE.includes(path);
}

async function networkFirst(request, fallback) {
  const cache = await caches.open(CACHE);
  try {
    const response = await fetch(request);
    if (response.ok && response.type === 'basic') {
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    const cached =
      (await cache.match(request, { ignoreSearch: request.mode === 'navigate' })) ||
      (fallback && (await cache.match(fallback)));
    if (cached) return cached;
    throw error;
  }
}

async function cacheFirst(request) {
  const cache = await caches.open(CACHE);
  const cached = await cache.match(request);
  if (cached) return cached;
  const response = await fetch(request);
  if (response.ok || response.type === 'opaque') {
    cache.put(request, response.clone());
  }
  return response;
}
