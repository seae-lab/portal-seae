// web/flutter_service_worker.js

const CACHE_NAME = 'flutter-app-cache';
const RESOURCES_TO_PRECACHE = [
  '/',
  '/index.html',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/manifest.json',
  // Adicione outros assets que você queira precachear aqui
  // ex: '/assets/images/logo.png'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      return cache.addAll(RESOURCES_TO_PRECACHE);
    })
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          if (cacheName !== CACHE_NAME) {
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => {
      return self.clients.claim();
    }).then(() => {
      // Notifica todos os clientes (abas) que há uma nova versão.
      return self.clients.matchAll().then(clients => {
        return Promise.all(
          clients.map(client => {
            // AQUI está a mensagem que seu App Flutter irá receber
            return client.postMessage({ type: 'NEW_VERSION_ACTIVATED' });
          })
        );
      });
    })
  );
});

self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request).then(response => {
      return response || fetch(event.request).then(fetchResponse => {
        return caches.open(CACHE_NAME).then(cache => {
          cache.put(event.request, fetchResponse.clone());
          return fetchResponse;
        });
      });
    })
  );
});