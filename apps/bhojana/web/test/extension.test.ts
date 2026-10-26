import assert from "node:assert/strict";
import { test } from "node:test";
import { extensionVersion, rank, relevance, searchWithExtension } from "../src/lib/extension.ts";

/// A window whose postMessage is answered by a fake extension, as bridge.js does.
function fakeWindow(answer: ((msg: Record<string, unknown>) => Record<string, unknown>) | null) {
  const target = new EventTarget();
  const win = {
    location: { origin: "https://bhojana.example.com" },
    addEventListener: target.addEventListener.bind(target),
    removeEventListener: target.removeEventListener.bind(target),
    postMessage(msg: Record<string, unknown>) {
      if (!answer || msg.source !== "bhojana-web") return;
      const reply = { source: "bhojana-ext", id: msg.id, type: msg.type, ...answer(msg) };
      setTimeout(() => {
        const e = new Event("message") as Event & { data: unknown; source: unknown };
        Object.assign(e, { data: reply, source: win });
        target.dispatchEvent(e);
      }, 1);
    },
  };
  return win as unknown as Window;
}

test("no extension: version is null after a short wait", async () => {
  assert.equal(await extensionVersion(fakeWindow(null)), null);
});

test("the extension answers hello and searches", async () => {
  const offers = [{ title: "Milk 4 pints", pence: 155, unit: "", offer: "", url: "", inStock: true }];
  const win = fakeWindow((m) => (m.type === "hello" ? { ok: true, version: "0.1.0" } : { ok: true, offers }));
  assert.equal(await extensionVersion(win), "0.1.0");
  assert.deepEqual(await searchWithExtension("https://www.aldi.co.uk/results?q=milk", win), offers);
});

test("an extension refusal becomes an error", async () => {
  const win = fakeWindow(() => ({ ok: false, message: "That is not a page of a shop Bhojana knows" }));
  await assert.rejects(searchWithExtension("https://example.com/", win), /not a page of a shop/);
});

test("ranking matches the app: relevant first, then cheapest", () => {
  assert.equal(relevance("semi skimmed milk", "Tesco Semi Skimmed Milk 2.272L"), 1);
  assert.equal(relevance("", "x"), 0);
  const o = (title: string, pence: number) => ({ title, pence, unit: "", offer: "", url: "", inStock: true });
  const ranked = rank("semi skimmed milk", [
    o("Whole Milk 4 Pints", 120),
    o("Semi Skimmed Milk 4 Pints", 165),
    o("Semi Skimmed Milk 2 Pints", 95),
    o("Bread", 50),
  ]);
  assert.deepEqual(
    ranked.map((r) => r.title),
    ["Semi Skimmed Milk 2 Pints", "Semi Skimmed Milk 4 Pints"],
  );
});
