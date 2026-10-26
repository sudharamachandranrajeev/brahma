// Opens shop pages for the Bhojana web app and reads prices from them in the
// user's own signed-in browser, so loyalty prices, stock and postcode show.
// Chrome runs this as a service worker, Firefox as a background script.
if (typeof importScripts === 'function') importScripts('hosts.js', 'reader.js', 'core.js');

const api = typeof browser !== 'undefined' ? browser : chrome;
const LOAD_TIMEOUT_MS = 30000;
const READ_TRIES = 6;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function loaded(tabId) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      api.tabs.onUpdated.removeListener(listener);
      reject(new Error('The shop page did not load'));
    }, LOAD_TIMEOUT_MS);
    function listener(id, change) {
      if (id !== tabId || change.status !== 'complete') return;
      clearTimeout(timer);
      api.tabs.onUpdated.removeListener(listener);
      resolve();
    }
    api.tabs.onUpdated.addListener(listener);
  });
}

async function run(tabId, func) {
  const [result] = await api.scripting.executeScript({ target: { tabId }, func });
  return result?.result;
}

/** Reads a shop's search page in a background tab and closes it. */
async function search(url) {
  const tab = await api.tabs.create({ url, active: false });
  try {
    await loaded(tab.id);
    // Most shops draw their results with script after the page loads.
    for (let i = 0; i < READ_TRIES; i++) {
      await sleep(1500);
      const offers = parseOffers(await run(tab.id, readShopPage));
      if (offers.length) return offers;
    }
    return [];
  } finally {
    api.tabs.remove(tab.id).catch(() => {});
  }
}

/** Opens a shop page for the user to see, optionally pressing its first Add button. */
async function open(url, addFirst) {
  const tab = await api.tabs.create({ url, active: true });
  if (!addFirst) return 'opened';
  await loaded(tab.id);
  await sleep(1500);
  return run(tab.id, pressAddButton);
}

api.runtime.onMessage.addListener((msg, sender, respond) => {
  (async () => {
    try {
      const req = checkRequest(msg, SHOP_HOSTS);
      if (req.type === 'hello') return respond({ ok: true, version: api.runtime.getManifest().version });
      if (req.type === 'search') return respond({ ok: true, offers: await search(req.url) });
      respond({ ok: true, result: await open(req.url, req.addFirst) });
    } catch (e) {
      respond({ ok: false, message: e.message });
    }
  })();
  return true;
});

// The options page registers the content script on the user's own server.
api.runtime.onInstalled.addListener(() => api.runtime.openOptionsPage?.());
