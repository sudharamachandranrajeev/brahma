const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { test } = require('node:test');
const { SHOP_HOSTS } = require('../hosts.js');
const { readShopPage, pressAddButton } = require('../reader.js');
const { isShopUrl, parseOffers, checkRequest } = require('../core.js');

const dart = (name) => readFileSync(`${__dirname}/../../lib/domain/${name}`, 'utf8');
const squash = (s) => s.replace(/\s+/g, ' ').trim();

test('the shop hosts are those of lib/domain/shops.dart', () => {
  const urls = [...dart('shops.dart').matchAll(/(?:home|search|slots):\s*'https:\/\/([^/']+)/g)];
  const hosts = [...new Set(urls.map((m) => m[1].replace(/^www\./, '')))].sort();
  assert.deepEqual([...SHOP_HOSTS].sort(), hosts);
});

test('the page scripts are identical to the ones the app runs (lib/domain/reader.dart)', () => {
  const source = dart('reader.dart');
  const body = (name) => {
    const m = source.match(new RegExp(`const ${name} = r'''\\n\\(\\(\\) => \\{\\n([\\s\\S]*?)\\n\\}\\)\\(\\)\\n'''`));
    return squash(m[1]);
  };
  const inner = (fn) => squash(fn.toString().replace(/^[^{]*\{/, '').replace(/\}\s*$/, ''));
  assert.equal(inner(readShopPage), body('readerScript'));
  assert.equal(inner(pressAddButton), body('addFirstScript'));
});

test('only https pages of known shops are accepted', () => {
  assert.ok(isShopUrl('https://www.tesco.com/groceries/en-GB/search?query=milk', SHOP_HOSTS));
  assert.ok(isShopUrl('https://groceries.morrisons.com/search?q=x', SHOP_HOSTS));
  assert.ok(isShopUrl('https://shop.aldi.co.uk/x', SHOP_HOSTS));
  assert.ok(!isShopUrl('http://www.tesco.com/', SHOP_HOSTS));
  assert.ok(!isShopUrl('https://tesco.com.evil.example/', SHOP_HOSTS));
  assert.ok(!isShopUrl('https://evil-tesco.com/', SHOP_HOSTS));
  assert.ok(!isShopUrl('https://user:pw@tesco.com/', SHOP_HOSTS));
  assert.ok(!isShopUrl('javascript:alert(1)', SHOP_HOSTS));
  assert.ok(!isShopUrl('not a url', SHOP_HOSTS));
});

test('requests are checked; other pages and unknown types are refused', () => {
  assert.deepEqual(checkRequest({ type: 'hello', id: 'a' }, SHOP_HOSTS), { type: 'hello', id: 'a' });
  const search = checkRequest({ type: 'search', id: 'b', url: 'https://www.aldi.co.uk/results?q=milk' }, SHOP_HOSTS);
  assert.equal(search.addFirst, false);
  assert.equal(checkRequest({ type: 'open', id: 'c', url: 'https://www.aldi.co.uk/', addFirst: true }, SHOP_HOSTS).addFirst, true);
  assert.throws(() => checkRequest({ type: 'search', url: 'https://example.com/' }, SHOP_HOSTS), /not a page of a shop/);
  assert.throws(() => checkRequest({ type: 'eval', code: '1' }, SHOP_HOSTS), /Unknown/);
  assert.throws(() => checkRequest(null, SHOP_HOSTS));
});

test('offers are cleaned like parseOffers in the app', () => {
  const json = JSON.stringify([
    { title: ' Milk 2L ', pence: 150.4, unit: '£0.75/l', offer: 'Clubcard Price', url: 'https://x', inStock: false },
    { title: '', pence: 100 },
    { title: 'Free', pence: 0 },
    { title: 'Bread', pence: 99 },
    'junk',
  ]);
  assert.deepEqual(parseOffers(json), [
    { title: 'Milk 2L', pence: 150, unit: '£0.75/l', offer: 'Clubcard Price', url: 'https://x', inStock: false },
    { title: 'Bread', pence: 99, unit: '', offer: '', url: '', inStock: true },
  ]);
  assert.deepEqual(parseOffers('not json'), []);
  assert.deepEqual(parseOffers(null), []);
});
