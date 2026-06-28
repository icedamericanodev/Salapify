/* Peso Smart — Service Worker v2 */
const CACHE = "peso-smart-v64";

const FILES = [
  "./",
  "./index.html",
  "./manifest.json",
  "./icon-192.png",
  "./icon-512.png",
  "https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.js"
];

/* Install — cache all app files */
self.addEventListener("install", e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(FILES))
  );
  self.skipWaiting();
});

/* Activate — delete old caches */
self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

/* Fetch — serve from cache, fall back to network */
self.addEventListener("fetch", e => {
  const req = e.request;
  // Page loads: try the network first so a new deploy shows up right away when online
  if (req.mode === "navigate") {
    e.respondWith(
      fetch(req).then(res => {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(req, copy));
        return res;
      }).catch(() => caches.match(req).then(r => r || caches.match("./index.html")))
    );
    return;
  }
  // Everything else (Chart.js, icons): cache first, then network
  e.respondWith(caches.match(req).then(r => r || fetch(req)));
});
