/* Service worker da Calculadora de LIO — permite uso offline.
   Estratégia: network-first (pega atualizações quando online) com fallback
   ao cache quando sem rede. Não intercepta o endpoint da IA (/wp-json/). */
const CACHE = 'iol-calc-v1';

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(['./', './manifest.json', './icon.svg']).catch(() => {})));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))));
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;            // POST do proxy de IA passa direto
  if (e.request.url.includes('/wp-json/')) return;   // nunca cachear a API
  e.respondWith(
    fetch(e.request).then(r => {
      if (r.ok) { const cp = r.clone(); caches.open(CACHE).then(c => c.put(e.request, cp)); }
      return r;
    }).catch(() => caches.match(e.request).then(m => m || caches.match('./')))
  );
});
