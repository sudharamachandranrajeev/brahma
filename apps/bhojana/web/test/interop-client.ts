// The web client as a command, for test/web_interop_test.dart (Dart) to run
// against the same dev server as the native SyncEngine:
//
//   node test/interop-client.ts <server> signup-push <email> <password> <setup-code>
//   node test/interop-client.ts <server> pull <email> <password>
//
// Prints one JSON line with what it did or saw.
import { client, sync } from "./support.ts";

const [server, cmd, email, password, code] = process.argv.slice(2);
const c = await client(server, `interop-${cmd}`);

if (cmd === "signup-push") {
  const recovery = await c.account.signUp(email, password, code);
  const list = await c.book.addList("From the web");
  await c.book.addItem(list, "2 oat milk");
  const bread = await c.book.addItem(list, "bread x3");
  const item = (await c.book.items(list)).find((i) => i.id === bread)!;
  await c.book.saveItem({ ...item, done: true, note: "seeded" });
  await c.book.setPref("bhojana.shops", "tesco,aldi");
  await c.book.keepTypedPrice({ itemId: bread, query: "bread", shop: "aldi", title: "White bread", pence: 75 });
  const r = await sync(c.account);
  console.log(JSON.stringify({ recovery, list, pushed: r.pushed }));
} else if (cmd === "pull") {
  await c.account.signIn(email, password);
  const r = await sync(c.account);
  const s = await c.book.snapshot();
  console.log(JSON.stringify({ pulled: r.pulled, lists: s.lists, items: s.items, prices: s.prices, prefs: Object.fromEntries(s.prefs) }));
} else {
  console.error("usage: interop-client.ts <server> signup-push|pull …");
  process.exit(2);
}
c.store.close();
