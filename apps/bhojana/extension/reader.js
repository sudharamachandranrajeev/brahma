// Runs inside a shop page (chrome.scripting.executeScript). The bodies below are the
// scripts in lib/domain/reader.dart, which the app runs in its own web view; the test
// keeps them identical.

function readShopPage() {
    const out = [], seen = new Set();
    const unitRe = /(£\s?\d+(?:\.\d+)?|\d+(?:\.\d+)?p)\s*(?:\/|per)\s*(?:\d+\s?)?[a-z]+/gi;
    const priceRe = /£\s?(\d{1,4}(?:\.\d{1,2})?)|(?:^|\s)(\d{1,3})p\b/g;
    const offerRe = /(clubcard price|nectar price|rollback|asda price|more card price|lidl plus|\b\d+ for £\s?\d+(?:\.\d\d)?|any \d+ for|half price|buy \d+ get \d+|save £\s?\d+(?:\.\d\d)?|\d+% off|was £\s?\d+(?:\.\d\d)?)/i;
    const noStockRe = /out of stock|sold out|currently unavailable|not available/i;
    const add = (title, pence, url, unit, offer, inStock) => {
      title = (title || '').replace(/\s+/g, ' ').trim();
      if (title.length < 3 || !(pence > 0)) return;
      const key = title.toLowerCase() + '|' + pence;
      if (seen.has(key)) return;
      seen.add(key);
      out.push({title, pence, url: url || '', unit: unit || '', offer: offer || '', inStock});
    };
    const walk = (n) => {
      if (!n || typeof n !== 'object') return;
      if (Array.isArray(n)) return n.forEach(walk);
      const types = [].concat(n['@type'] || []);
      if (types.includes('Product') && n.name) {
        const o = [].concat(n.offers || [])[0] || {};
        const p = parseFloat(o.price ?? o.lowPrice);
        const stock = o.availability ? !/OutOfStock|SoldOut/i.test(o.availability) : true;
        add(n.name, Math.round(p * 100), n.url || o.url, '', '', stock);
      }
      for (const k in n) walk(n[k]);
    };
    for (const s of document.querySelectorAll('script[type="application/ld+json"]')) {
      try { walk(JSON.parse(s.textContent)); } catch (e) {}
    }
    const tiles = new Set();
    for (const a of document.querySelectorAll('a[href]')) {
      let el = a;
      for (let i = 0; i < 7 && el && el !== document.body; i++, el = el.parentElement) {
        const text = el.innerText || '';
        if (text.length > 700) break;
        const units = text.match(unitRe) || [];
        let rest = text;
        for (const u of units) rest = rest.replace(u, ' ');
        const prices = [...rest.matchAll(priceRe)].map((m) => m[1] ? Math.round(parseFloat(m[1]) * 100) : parseInt(m[2]));
        if (!prices.length) continue;
        // A tile already read, or the list around it: not a product of its own.
        if ([...tiles].some((t) => el.contains(t))) break;
        tiles.add(el);
        const lines = text.split('\n').map((l) => l.trim()).filter((l) => l && !/£|\dp\b/.test(l) && !offerRe.test(l));
        const label = a.getAttribute('aria-label') || a.getAttribute('title') || '';
        let title = (a.innerText || '').trim().length > 5 ? a.innerText : (label || lines.sort((x, y) => y.length - x.length)[0]);
        const offer = (text.match(offerRe) || [''])[0];
        title = (title || '').replace(/\(?[^()]*\bper\b[^()]*\)|\([^()]*\/[^()]*\)|(for )?(£|GBP) ?\d+(\.\d+)?/g, ' ');
        add(title, Math.min(...prices), a.href, units[0] || '', offer, !noStockRe.test(text));
        break;
      }
    }
    return JSON.stringify(out.slice(0, 40));
}

function pressAddButton() {
    const re = /^\s*(add|add to (basket|trolley|bag|cart))\b/i;
    for (const b of document.querySelectorAll('button, [role="button"], input[type="submit"]')) {
      const label = (b.getAttribute('aria-label') || b.innerText || b.value || '').trim();
      if (!re.test(label) || b.disabled || b.offsetParent === null) continue;
      b.scrollIntoView({block: 'center'});
      b.click();
      return 'added';
    }
    return 'none';
}

if (typeof module !== 'undefined') module.exports = { readShopPage, pressAddButton };
