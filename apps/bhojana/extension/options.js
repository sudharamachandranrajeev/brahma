const api = typeof browser !== 'undefined' ? browser : chrome;
const status = document.getElementById('status');
const input = document.getElementById('server');

function say(text, error = false) {
  status.textContent = text;
  status.className = error ? 'error' : '';
}

const originPattern = (url) => `${new URL(url).origin}/*`;
const shopPatterns = () => SHOP_HOSTS.flatMap((h) => [`https://${h}/*`, `https://*.${h}/*`]);

async function register(server) {
  const id = 'bhojana-bridge';
  const existing = await api.scripting.getRegisteredContentScripts({ ids: [id] });
  if (existing.length) await api.scripting.unregisterContentScripts({ ids: [id] });
  await api.scripting.registerContentScripts([
    { id, matches: [originPattern(server)], js: ['bridge.js'], runAt: 'document_start', persistAcrossSessions: true },
  ]);
}

document.getElementById('form').addEventListener('submit', async (e) => {
  e.preventDefault();
  let server;
  try {
    server = new URL(input.value.trim());
    if (server.protocol !== 'https:' && server.hostname !== 'localhost') throw new Error('Use an https:// address');
  } catch (err) {
    return say(err.message || 'Enter the address of your server', true);
  }
  // Must run straight from the click, so the browser shows its permission prompt.
  const granted = await api.permissions.request({ origins: [originPattern(server), ...shopPatterns()] });
  if (!granted) return say('Permission was not given, so nothing changed.', true);
  await register(server);
  await api.storage.local.set({ server: server.origin });
  say(`Saved. Open ${server.origin} and the Compare page can now read live prices.`);
});

api.storage.local.get('server').then(({ server }) => {
  if (server) input.value = server;
});
