// Runs on the user's own Bhojana server page only (registered by the options page).
// Relays messages between the web app and the extension's background.
const api = typeof browser !== 'undefined' ? browser : chrome;

window.addEventListener('message', async (event) => {
  const msg = event.data;
  if (event.source !== window || event.origin !== location.origin) return;
  if (!msg || msg.source !== 'bhojana-web') return;
  let reply;
  try {
    reply = await api.runtime.sendMessage(msg);
  } catch (e) {
    reply = { ok: false, message: 'The Bhojana extension is not running' };
  }
  window.postMessage({ source: 'bhojana-ext', id: msg.id, type: msg.type, ...reply }, location.origin);
});
