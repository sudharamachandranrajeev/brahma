// The web client against the real Worker handler (server/test/dev-server.ts on
// node:sqlite): sign-up, sign-in, lists and items through sync, pairing,
// password change, reset with the recovery key, and the push-safety paths.
import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { SignInAgain, WorkerApi } from "../src/lib/api.ts";
import { pounds } from "../src/lib/book.ts";
import { fromPassword } from "../src/lib/crypto.ts";
import { parseLink, pairingLinkText, type PairingLink } from "../src/lib/pairing.ts";
import { req } from "../src/lib/store.ts";
import { SyncEngine } from "../src/lib/sync.ts";
import { client, SETUP_CODE, startServer, sync } from "./support.ts";

const EMAIL = "me@example.com";
const PASSWORD = "correct horse battery";
let server: Awaited<ReturnType<typeof startServer>>;

before(async () => {
  server = await startServer();
});
after(() => server.stop());

const names = async (c: Awaited<ReturnType<typeof client>>) =>
  (await c.book.snapshot()).items.map((i) => `${i.qty}×${i.name}${i.done ? "✓" : ""}`).sort();

test("sign up, add a list, sync; a second browser signs in and sees it", async () => {
  assert.equal((await new WorkerApi(server.url).health()).needsSetup, true);
  const a = await client(server.url);
  await assert.rejects(a.account.signUp(EMAIL, PASSWORD, "wrong"), /setup code/);
  const recovery = await a.account.signUp(EMAIL, PASSWORD, SETUP_CODE);
  assert.match(recovery, /^[0-9A-Z]{4}(-[0-9A-Z]{4}){12}$/);
  assert.equal((await new WorkerApi(server.url).health()).needsSetup, false);

  const list = await a.book.addList("Weekly shop");
  await a.book.addItem(list, "2 milk");
  const bread = await a.book.addItem(list, "bread x3");
  await a.book.addItem(list, "eggs");
  const [b0] = (await a.book.items(list)).filter((i) => i.id === bread);
  await a.book.tick(b0, true);
  await a.book.setPref("bhojana.postcode", "SW1A 1AA");
  await a.book.keepTypedPrice({ itemId: bread, query: "bread", shop: "tesco", title: "Hovis 800g", pence: 145 });
  assert.equal(await a.store.pending(), 6);
  const pushed = await sync(a.account);
  assert.equal(pushed.pushed, 6);
  assert.equal(await a.store.pending(), 0);

  const b = await client(server.url);
  await b.account.signIn(EMAIL, PASSWORD);
  assert.equal((await sync(b.account)).pulled, 6);
  assert.deepEqual(await names(b), ["1×eggs", "2×milk", "3×bread✓"]);
  const snap = await b.book.snapshot();
  assert.equal(snap.lists[0].name, "Weekly shop");
  assert.equal(snap.prefs.get("bhojana.postcode"), "SW1A 1AA");
  assert.equal(pounds(snap.prices[0].pence * 3), "£4.35");

  // Edits and a deletion travel back; the newer write wins a conflict.
  const eggs = snap.items.find((i) => i.name === "eggs")!;
  await b.book.removeItem(snap.items.find((i) => i.name === "milk")!.id);
  await a.book.saveItem({ ...eggs, name: "eggs (A)" });
  // In the same millisecond the device id breaks the tie, so make B's write later in time.
  await new Promise((r) => setTimeout(r, 5));
  await b.book.saveItem({ ...eggs, name: "eggs (B, later)", note: "free range" });
  await sync(b.account);
  await sync(a.account);
  await sync(b.account);
  assert.deepEqual(await names(a), ["1×eggs (B, later)", "3×bread✓"]);
  assert.deepEqual(await names(b), await names(a));
  a.store.close();
  b.store.close();
});

test("pairing: a browser approves a new browser, which then syncs", async () => {
  const a = await client(server.url);
  await a.account.signIn(EMAIL, PASSWORD);
  await sync(a.account);
  const offer = await a.account.offerPairing();
  // The new device reads the link as text, like a pasted QR code.
  const link = parseLink(pairingLinkText(offer)) as PairingLink;
  assert.equal(await a.account.pairingRequest(offer), null);

  const c = await client(server.url);
  const ticket = await c.account.requestJoin(link);
  const request = (await a.account.pairingRequest(offer))!;
  assert.match(request.name, /^Test /);
  assert.equal(request.platform, "web");
  assert.equal(await c.account.joinGrant(ticket), null);
  await a.account.approvePairing(offer, request);
  const grant = (await c.account.joinGrant(ticket))!;
  assert.equal(grant.email, EMAIL);
  await c.account.join(ticket, grant);
  assert.equal(await a.account.pairingFinished(offer), true);
  await sync(c.account);
  assert.deepEqual(await names(c), ["1×eggs (B, later)", "3×bread✓"]);
  await assert.rejects(c.account.requestJoin(link), /already syncs/);
  a.store.close();
  c.store.close();
});

test("restored counters never reuse a slot, and a retried batch is not pushed twice", async () => {
  const a = await client(server.url);
  await a.account.signIn(EMAIL, PASSWORD);
  await sync(a.account);
  const api = await a.account.api();
  const remote = api.remote();
  const me = a.store.deviceId;
  const list = (await a.book.snapshot()).lists[0].id;

  await a.book.addItem(list, "apples");
  await sync(a.account);
  const last = await remote.lastSeq(me);
  assert.equal(last, 1);

  // The confirmation of batch 1 was lost: the same rows go out again and the
  // server's copy is recognised instead of taking a new slot.
  const item = (await a.book.snapshot()).items.find((i) => i.name === "apples")!;
  await a.store.tx(["outbox", "local_settings"], "readwrite", async (t) => {
    await req(t.objectStore("outbox").put({ entity: "food_items", row_id: item.id, seq: 1 }));
    await req(t.objectStore("local_settings").put({ key: "sync.sent", value: "0" }));
  });
  await sync(a.account);
  assert.equal(await remote.lastSeq(me), 1);
  assert.equal(await a.store.pending(), 0);

  // A restored copy with old counters: the next write lands after the server's last.
  await a.store.setSetting("sync.seq", "0");
  await a.store.setSetting("sync.sent", "0");
  await a.book.addItem(list, "pears");
  await sync(a.account);
  assert.equal(await remote.lastSeq(me), 2);

  // Slot 3 taken by something else (a since-restored copy): the batch moves on.
  await remote.push(me, 3, "not this device's batch");
  await a.store.setSetting("sync.seq", "2");
  await a.store.setSetting("sync.sent", "2");
  await a.book.addItem(list, "plums");
  // lastSeq (3) is above the counter, so the push skips past it.
  await sync(a.account);
  assert.equal(await remote.lastSeq(me), 4);

  // The slot fills between the counter check and the push (another copy
  // racing): the 409 and a server copy that differs move the batch to slot 6.
  await remote.push(me, 5, "raced in");
  const stale = { ...remote, lastSeq: async () => 4 };
  const s = (await a.account.session())!;
  await a.book.addItem(list, "figs");
  await new SyncEngine(a.store, stale, s.dataKey, s.userId).push();
  assert.equal(await remote.lastSeq(me), 6);
  assert.equal(await a.store.setting("sync.sent"), "6");

  const b = await client(server.url);
  await b.account.signIn(EMAIL, PASSWORD);
  // Slot 3 is garbage under this account's key: pulling it must fail loudly,
  // not skip it (native behaviour).
  await assert.rejects(sync(b.account), /integrity/);
  a.store.close();
  b.store.close();
});

test("change password, sign in again elsewhere; reset with a code and the recovery key", async () => {
  // A fresh account, so the garbage slot above does not get in the way.
  const owner = await client(server.url);
  await owner.account.signIn(EMAIL, PASSWORD);
  const invite = (await (await owner.account.api()).createInvite()).code;
  assert.equal((await (await owner.account.api()).me()).owner, true);

  const x = await client(server.url);
  await assert.rejects(x.account.signUp("other@example.com", "first password 1", "AAAA-BBBB-CCCC"), /invite code/);
  const recovery = await x.account.signUp("other@example.com", "first password 1", invite);
  const list = await x.book.addList("Party");
  await x.book.addItem(list, "6 balloons");
  await sync(x.account);

  const y = await client(server.url);
  await y.account.signIn("other@example.com", "first password 1");
  await x.account.changePassword("first password 1", "second password 2");
  // y's stored login secret is now stale.
  await assert.rejects(sync(y.account), SignInAgain);
  await y.account.signOut();
  await assert.rejects(y.account.signIn("other@example.com", "first password 1"), /Wrong e-mail or password/);
  await y.account.signIn("other@example.com", "second password 2");
  await sync(y.account);
  assert.deepEqual(await names(y), ["6×balloons"]);

  // Forgotten password: the owner hands out a reset code.
  const code = (await (await owner.account.api()).createResetCode("Other@Example.com")).code;
  const z = await client(server.url);
  await assert.rejects(z.account.resetPassword("other@example.com", code, "third password 3", "nonsense"), /recovery key/);
  await z.account.resetPassword("other@example.com", code, "third password 3", recovery);
  await sync(z.account);
  assert.deepEqual(await names(z), ["6×balloons"]);
  // The vault is re-wrapped: the new password now opens it directly.
  const w = await client(server.url);
  await w.account.signIn("other@example.com", "third password 3");
  assert.deepEqual((await w.account.session())!.dataKey, (await x.account.session())!.dataKey);

  // The login secret the server holds is the Argon2id-derived one, never the password.
  const k = await fromPassword("other@example.com", "third password 3");
  assert.equal((await w.account.session())!.secret, k.authSecret);
  for (const c of [owner, x, y, z, w]) c.store.close();
});
