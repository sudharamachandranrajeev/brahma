// Bhojana's service worker: the app shell comes from the cache so the app
// opens offline. /api is never cached (it carries the account's data and
// must be fresh); pages are fetched first and fall back to the cached shell.
const CACHE = "bhojana-__VERSION__";
const SHELL = __SHELL__;

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => k.startsWith("bhojana-") && k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener("fetch", (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== "GET" || url.origin !== self.location.origin || url.pathname.startsWith("/api/")) return;
  if (e.request.mode === "navigate") {
    e.respondWith(fetch(e.request).catch(() => caches.match("/", { cacheName: CACHE })));
    return;
  }
  e.respondWith(caches.match(e.request, { cacheName: CACHE }).then((hit) => hit ?? fetch(e.request)));
});
