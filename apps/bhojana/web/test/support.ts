// Shared by the node tests: IndexedDB in memory, the real Worker handler on
// a local port, and a whole web client (store, account, book) without a page.
import "fake-indexeddb/auto";
import { spawn, type ChildProcess } from "node:child_process";
import { createServer } from "node:net";
import { AccountService, MemoryKeyStore } from "../src/lib/account.ts";
import { ShoppingBook } from "../src/lib/book.ts";
import { Store } from "../src/lib/store.ts";

export const SETUP_CODE = "TEST-SETUP-CODE";
const serverDir = new URL("../../server/", import.meta.url).pathname;

async function freePort(): Promise<number> {
  return new Promise((resolve) => {
    const s = createServer().listen(0, "127.0.0.1", () => {
      const port = (s.address() as { port: number }).port;
      s.close(() => resolve(port));
    });
  });
}

/// Starts server/test/dev-server.ts (in-memory D1) as the Dart tests do.
export async function startServer(script = "test/dev-server.ts", cwd = serverDir): Promise<{ url: string; stop: () => void; proc: ChildProcess }> {
  const port = await freePort();
  const proc = spawn(process.execPath, [script, String(port)], { cwd, stdio: ["ignore", "pipe", "inherit"] });
  await new Promise<void>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("dev server did not start")), 20_000);
    proc.stdout!.on("data", (d: Buffer) => {
      if (d.toString().includes("ready")) {
        clearTimeout(timer);
        resolve();
      }
    });
    proc.on("exit", (code) => reject(new Error(`dev server exited with ${code}`)));
  });
  return { url: `http://127.0.0.1:${port}`, stop: () => proc.kill(), proc };
}

let n = 0;

export async function client(server: string, name = `client-${process.pid}-${++n}`) {
  const store = await Store.open(name);
  const account = new AccountService(store, new MemoryKeyStore(), server, `Test ${name}`);
  return { store, account, book: new ShoppingBook(store) };
}

/// Pushes and pulls until nothing moves (one round normally does).
export async function sync(account: AccountService) {
  const engine = await account.engine();
  if (!engine) throw new Error("not signed in");
  return engine.run();
}
