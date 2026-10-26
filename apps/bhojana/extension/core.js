// Pure helpers of the extension, kept apart from the browser APIs so node can test them.

/** Whether [url] is an https page of a shop in [hosts] (or one of its subdomains). */
function isShopUrl(url, hosts) {
  let u;
  try {
    u = new URL(url);
  } catch {
    return false;
  }
  if (u.protocol !== 'https:' || u.username || u.password) return false;
  return hosts.some((h) => u.hostname === h || u.hostname.endsWith('.' + h) || u.hostname === 'www.' + h);
}

/** The offers in the reader's JSON text, dropping anything unusable (as parseOffers in reader.dart). */
function parseOffers(json) {
  let raw;
  try {
    raw = typeof json === 'string' ? JSON.parse(json) : json;
  } catch {
    return [];
  }
  if (!Array.isArray(raw)) return [];
  const out = [];
  for (const r of raw) {
    if (!r || typeof r !== 'object') continue;
    const title = String(r.title ?? '').trim();
    const pence = Math.round(Number(r.pence));
    if (!title || !(pence > 0)) continue;
    out.push({
      title,
      pence,
      unit: String(r.unit ?? ''),
      offer: String(r.offer ?? ''),
      url: String(r.url ?? ''),
      inStock: r.inStock !== false,
    });
  }
  return out;
}

/** Checks a message from the web page; returns the cleaned request or throws a readable Error. */
function checkRequest(msg, hosts) {
  if (!msg || typeof msg !== 'object') throw new Error('Not a request');
  const id = String(msg.id ?? '').slice(0, 64);
  switch (msg.type) {
    case 'hello':
      return { type: 'hello', id };
    case 'search':
    case 'open':
      if (!isShopUrl(msg.url, hosts)) throw new Error('That is not a page of a shop Bhojana knows');
      return { type: msg.type, id, url: String(msg.url), addFirst: msg.addFirst === true };
    default:
      throw new Error('Unknown request');
  }
}

if (typeof module !== 'undefined') module.exports = { isShopUrl, parseOffers, checkRequest };
