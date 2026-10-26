// The domain rules the web shares with the native app (lib/domain/book.dart,
// shops.dart; cases mirror test/domain_test.dart), the row merge and HLC order.
import "fake-indexeddb/auto";
import assert from "node:assert/strict";
import { test } from "node:test";
import {
  bestPrice,
  costByShop,
  myShops,
  niceDate,
  parsePounds,
  pounds,
  ShoppingBook,
  sortItems,
  splitQuantity,
  tidyPostcode,
  type Item,
  type Price,
} from "../src/lib/book.ts";
import { HlcClock } from "../src/lib/hlc.ts";
import { mergeRow } from "../src/lib/schema.ts";
import { DEFAULT_SHOPS, SHOPS, searchable, searchUrl, shopById } from "../src/lib/shops.ts";
import { Store } from "../src/lib/store.ts";

test("quantities are read from the front or the back", () => {
  assert.deepEqual(splitQuantity("2 milk"), [2, "milk"]);
  assert.deepEqual(splitQuantity("3x eggs"), [3, "eggs"]);
  assert.deepEqual(splitQuantity("bread x 4"), [4, "bread"]);
  assert.deepEqual(splitQuantity("milk x2"), [2, "milk"]);
  assert.deepEqual(splitQuantity("6 × rolls"), [6, "rolls"]);
  assert.deepEqual(splitQuantity("7up"), [1, "7up"]);
  assert.deepEqual(splitQuantity("washing-up liquid"), [1, "washing-up liquid"]);
  assert.deepEqual(splitQuantity("  0 pears "), [1, "pears"]);
  assert.deepEqual(splitQuantity("1000 grapes"), [1, "1000 grapes"]);
});

const item = (id: string, qty = 1, extra: Partial<Item> = {}): Item => ({
  id, listId: "l", name: id, qty, note: "", done: false, ord: 0, added: "2026-10-25", ...extra,
});
const price = (itemId: string | null, shop: string, pence: number, day = "2026-10-25", extra: Partial<Price> = {}): Price => ({
  id: `${itemId}-${shop}-${pence}-${day}`, itemId, query: "", shop, title: "", pence, unitPrice: "", offer: "", url: "",
  inStock: true, day, source: "typed", ...extra,
});

test("a list is costed per shop from the latest price of each item", () => {
  const items = [item("milk", 2), item("bread")];
  const prices = [
    price("milk", "tesco", 150),
    price("bread", "tesco", 100),
    price("milk", "aldi", 120),
    // Older, cheaper: the newer day wins.
    price("bread", "aldi", 50, "2026-10-01"),
    price("bread", "aldi", 90, "2026-10-20"),
    // Same day: the cheaper one.
    price("milk", "asda", 130),
    price("milk", "asda", 125),
    // A free search price costs nothing.
    price(null, "lidl", 10),
  ];
  assert.deepEqual(
    costByShop(items, prices).map((c) => [c.shop, c.pence, c.priced, c.items]),
    [["aldi", 330, 2, 2], ["tesco", 400, 2, 2], ["asda", 250, 1, 2]],
  );
  assert.equal(bestPrice("milk", prices)?.shop, "aldi");
  assert.equal(bestPrice("milk", [...prices, price("milk", "aldi", 100, "2026-10-25", { inStock: false })])?.shop, "asda");
  assert.equal(bestPrice("eggs", prices), null);
  assert.deepEqual(costByShop([], prices), []);
});

test("pounds and typed prices read like a shelf label", () => {
  assert.equal(pounds(85), "85p");
  assert.equal(pounds(100), "£1.00");
  assert.equal(pounds(1250), "£12.50");
  assert.equal(parsePounds("1.25"), 125);
  assert.equal(parsePounds("£2"), 200);
  assert.equal(parsePounds("85p"), 85);
  assert.equal(parsePounds(".5"), 50);
  assert.equal(parsePounds("0"), null);
  assert.equal(parsePounds("abc"), null);
  assert.equal(parsePounds("1.234"), null);
});

test("postcodes, dates and the shop catalogue", () => {
  assert.equal(tidyPostcode(" bt74   7aa "), "BT74 7AA");
  assert.equal(tidyPostcode("SW1A1AA"), "SW1A1AA");
  assert.equal(tidyPostcode(""), "");
  assert.equal(tidyPostcode("12345"), null);
  assert.equal(niceDate("2026-10-05"), "5 Oct 2026");
  for (const s of SHOPS.filter(searchable)) {
    assert.match(searchUrl(s, "baked beans"), /baked%20beans/, s.name);
    assert.equal(new URL(searchUrl(s, "x")).protocol, "https:", s.name);
  }
  assert.match(searchUrl(shopById("tesco")!, "fish (frozen)!"), /fish%20%28frozen%29%21/);
  assert.equal(new Set(SHOPS.map((s) => s.id)).size, SHOPS.length);
  for (const id of DEFAULT_SHOPS) assert.ok(shopById(id));
  assert.deepEqual(myShops(null).map((s) => s.id), DEFAULT_SHOPS);
  assert.deepEqual(myShops("aldi,,tesco,gone").map((s) => s.id), ["tesco", "aldi"]);
  assert.deepEqual(myShops(""), []);
});

test("HLC stamps order by string, ties broken by device", () => {
  let t = 5;
  const a = new HlcClock("aaaa", () => t), b = new HlcClock("bbbb", () => t);
  const s1 = a.tick(), s2 = a.tick();
  assert.ok(s2 > s1);
  // b sees a's stamp and must stamp after it even with the same wall clock.
  b.receive(s2);
  const s3 = b.tick();
  assert.ok(s3 > s2);
  // Wall clock going backwards never makes an older stamp.
  t = 1;
  assert.ok(a.tick() > s2);
  // Same millis and counter: the device id decides, the same way everywhere.
  assert.ok("000000000000005-000000-bbbb" > "000000000000005-000000-aaaa");
  // Fixed width: 10 ms sorts after 9 ms as text too.
  t = 10;
  assert.ok(new HlcClock("z", () => 10).tick() > new HlcClock("z", () => 9).tick());
  assert.throws(() => new HlcClock("a-b"));
  assert.ok(HlcClock.seed < s1);
});

test("rows merge like SQLite's upsert: defaults, known columns, 0/1 booleans", () => {
  const fresh = mergeRow("food_items", undefined, { id: "i", list_id: "l", name: "milk", added: "2026-10-25", done: true, extra: "x", nested: {} });
  assert.deepEqual(fresh, { id: "i", hlc: "", deleted: 0, list_id: "l", name: "milk", qty: 1, note: "", done: 1, ord: 0, added: "2026-10-25" });
  assert.deepEqual(mergeRow("food_items", fresh, { id: "i", qty: "3" }).qty, 3);
  assert.throws(() => mergeRow("food_items", undefined, { id: "i", name: "milk" }), /incomplete/);
  assert.throws(() => mergeRow("food_lists", undefined, { id: "l", name: null, created: "x" }), /incomplete/);
  assert.equal(mergeRow("food_prices", undefined, { id: "p", query: "q", shop: "s", title: "t", pence: 1, day: "d" }).item_id, null);
});

test("the book writes through the outbox: add, tick, reorder, untick all, delete", async () => {
  const store = await Store.open("book-test");
  const book = new ShoppingBook(store);
  const list = await book.addList(" Weekly ", "2026-10-25");
  const milk = await book.addItem(list, "2 milk", "2026-10-25");
  const bread = await book.addItem(list, "bread", "2026-10-25");
  const eggs = await book.addItem(list, "eggs x6", "2026-10-25");
  let items = await book.items(list);
  assert.deepEqual(items.map((i) => [i.name, i.qty, i.ord]), [["milk", 2, 0], ["bread", 1, 1], ["eggs", 6, 2]]);

  await book.move(list, eggs, -1);
  assert.deepEqual((await book.items(list)).map((i) => i.name), ["milk", "eggs", "bread"]);
  await book.move(list, milk, -1);
  assert.deepEqual((await book.items(list)).map((i) => i.name), ["milk", "eggs", "bread"]);

  items = await book.items(list);
  await book.tick(items[0], true);
  assert.deepEqual((await book.items(list)).map((i) => i.name), ["eggs", "bread", "milk"]);
  await book.resetList(list);
  assert.ok((await book.items(list)).every((i) => !i.done));

  // Two items that ended up at the same position (added on two devices).
  const twin = await book.addItem(list, "jam", "2026-10-25");
  const jam = (await book.items(list)).find((i) => i.id === twin)!;
  await book.saveItem({ ...jam, ord: 0 });
  const before = sortItems(await book.items(list)).map((i) => i.name);
  await book.move(list, before[0] === "jam" ? twin : milk, 1);
  assert.equal(new Set((await book.items(list)).map((i) => i.ord)).size, 4);

  await book.keepTypedPrice({ itemId: bread, query: "bread", shop: "tesco", title: "Bread", pence: 99.6 });
  await book.removeList(list);
  const snap = await book.snapshot();
  assert.deepEqual(snap.lists, []);
  assert.deepEqual(snap.items, []);
  assert.equal(snap.prices[0].pence, 100);
  // Deletions are tombstones with a newer stamp, queued like any edit.
  const row = await store.get("food_lists", list);
  assert.equal(row?.deleted, 1);
  assert.equal(await store.pending(), 6);
  store.close();
});
