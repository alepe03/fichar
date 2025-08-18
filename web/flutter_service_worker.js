// Service Worker para Fichar Trivalle Web App
const CACHE_NAME = 'fichar-trivalle-v1';
const urlsToCache = [
  '/',
  '/index.html',
  '/manifest.json',
  '/sqlite3.wasm',
  '/sqflite_sw.js',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png'
];

// Instalación del Service Worker
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('Cache abierto');
        return cache.addAll(urlsToCache);
      })
  );
});

// Activación del Service Worker
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('Eliminando cache antiguo:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
});

// Interceptar peticiones
self.addEventListener('fetch', (event) => {
  // No cachear peticiones a la API
  if (event.request.url.includes('trivalle.com/apiFichar')) {
    event.respondWith(
      fetch(event.request)
        .catch((error) => {
          console.error('Error en petición a API:', error);
          // Retornar respuesta de error personalizada
          return new Response(
            JSON.stringify({
              error: 'Error de conexión con el servidor',
              details: error.message
            }),
            {
              status: 503,
              statusText: 'Service Unavailable',
              headers: {
                'Content-Type': 'application/json'
              }
            }
          );
        })
    );
    return;
  }

  // Cachear recursos estáticos
  event.respondWith(
    caches.match(event.request)
      .then((response) => {
        if (response) {
          return response;
        }
        return fetch(event.request);
      })
  );
});

// Manejo de errores global
self.addEventListener('error', (event) => {
  console.error('Error en Service Worker:', event.error);
});

self.addEventListener('unhandledrejection', (event) => {
  console.error('Promise rechazada no manejada:', event.reason);
});
