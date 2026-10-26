// Headless Chromium against the built app on the local Worker (test/serve.ts):
// creates the owner account through the real wizard, adds items, and saves
// screenshots of the sign-up and list pages at phone and desktop widths into
// docs/. Fails on page errors or a horizontal scrollbar.
//   npm run build && npm run smoke       (CHROMIUM=/path/to/chrome to override)
import { spawn } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { serve } from "./serve.ts";

const docs = new URL("../docs/", import.meta.url).pathname;
if (!existsSync(new URL("../../server/public/index.html", import.meta.url))) throw new Error("Run npm run build first.");

const port = 20000 + Math.floor(Math.random() * 20000);
const server = await serve(port);
const origin = `http://localhost:${port}`;

const profile = mkdtempSync(join(tmpdir(), "bhojana-smoke-"));
const chrome = spawn(
  process.env.CHROMIUM ?? "chromium",
  ["--headless=new", "--remote-debugging-port=0", `--user-data-dir=${profile}`, "--no-first-run", "--hide-scrollbars", "about:blank"],
  { stdio: "ignore" },
);

async function until<T>(what: string, check: () => T | Promise<T>, ms = 20000): Promise<NonNullable<T>> {
  const end = Date.now() + ms;
  for (;;) {
    try {
      const v = await check();
      if (v) return v as NonNullable<T>;
    } catch {
      // not yet
    }
    if (Date.now() > end) throw new Error(`Timed out waiting for ${what}`);
    await new Promise((r) => setTimeout(r, 100));
  }
}

const portFile = join(profile, "DevToolsActivePort");
const [debugPort, path] = (
  await until("Chromium", () => {
    const text = readFileSync(portFile, "utf8");
    return text.trim().includes("\n") ? text : "";
  })
).split("\n");
const ws = new WebSocket(`ws://127.0.0.1:${debugPort}${path}`);
await new Promise((r, e) => ((ws.onopen = r), (ws.onerror = e)));

// A minimal DevTools protocol client: commands by id, page errors collected.
let next = 0;
const waiting = new Map<number, { ok: (v: any) => void; fail: (e: Error) => void }>();
const errors: string[] = [];
ws.onmessage = (m) => {
  const msg = JSON.parse(String(m.data));
  if (msg.id && waiting.has(msg.id)) {
    const w = waiting.get(msg.id)!;
    waiting.delete(msg.id);
    if (msg.error) w.fail(new Error(msg.error.message));
    else w.ok(msg.result);
  } else if (msg.method === "Runtime.exceptionThrown") {
    errors.push(msg.params.exceptionDetails.exception?.description ?? msg.params.exceptionDetails.text);
  } else if (msg.method === "Log.entryAdded" && msg.params.entry.level === "error") {
    // A new account has no vault yet: the 404 that says so is expected.
    if (msg.params.entry.url?.endsWith("/api/vault") && msg.params.entry.text.includes("404")) return;
    errors.push(`${msg.params.entry.text} ${msg.params.entry.url ?? ""}`);
  }
};
const send = (method: string, params: object = {}, sessionId?: string): Promise<any> =>
  new Promise((ok, fail) => {
    const id = ++next;
    waiting.set(id, { ok, fail });
    ws.send(JSON.stringify({ id, method, params, sessionId }));
  });

const { targetId } = await send("Target.createTarget", { url: "about:blank" });
const { sessionId } = await send("Target.attachToTarget", { targetId, flatten: true });
const page = (method: string, params: object = {}) => send(method, params, sessionId);
await page("Runtime.enable");
await page("Log.enable");
await page("Page.enable");

const js = async (expression: string) => {
  const r = await page("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description ?? r.exceptionDetails.text);
  return r.result.value;
};
const visible = (text: string) => until(`"${text}"`, () => js(`document.body.innerText.includes(${JSON.stringify(text)})`));
const click = (selector: string, text?: string) =>
  js(`(() => {
    const el = [...document.querySelectorAll(${JSON.stringify(selector)})]
      .find((e) => ${text ? `e.textContent.trim() === ${JSON.stringify(text)}` : "true"});
    if (!el) throw new Error("No ${selector} ${text ?? ""}");
    el.click();
  })()`);
// Svelte's bind:value listens for input events.
const type = (selector: string, value: string) =>
  js(`(() => {
    const el = document.querySelector(${JSON.stringify(selector)});
    el.value = ${JSON.stringify(value)};
    el.dispatchEvent(new Event("input", { bubbles: true }));
    el.dispatchEvent(new Event("change", { bubbles: true }));
  })()`);

const sizes = { phone: { width: 390, height: 844, mobile: true }, desktop: { width: 1280, height: 860, mobile: false } };
const shots: string[] = [];
async function shoot(name: string) {
  for (const [label, s] of Object.entries(sizes)) {
    await page("Emulation.setDeviceMetricsOverride", { ...s, deviceScaleFactor: 1 });
    await new Promise((r) => setTimeout(r, 300));
    const overflow = await js("document.documentElement.scrollWidth - window.innerWidth");
    if (overflow > 0) throw new Error(`${name} scrolls sideways by ${overflow}px at ${label} width`);
    const { data } = await page("Page.captureScreenshot", { format: "png" });
    const file = `${name}-${label}.png`;
    writeFileSync(join(docs, file), Buffer.from(data, "base64"));
    shots.push(file);
  }
}

try {
  await page("Page.navigate", { url: origin });
  await visible("Create the owner account");
  await click("button", "Create the owner account");
  await visible("Setup code");
  await type("#email", "owner@example.com");
  await type("#password", "correct horse battery staple");
  await type("#repeat", "correct horse battery staple");
  await type("#code", "TEST-SETUP-CODE");
  await shoot("sign-up");

  await click("button[type=submit]");
  await visible("Save your recovery key");
  const key = await js(`document.querySelector(".recovery").textContent.trim()`);
  if (!/^([0-9A-Z]{4}-){12}[0-9A-Z]{4}$/.test(key)) throw new Error(`Odd recovery key: ${key}`);
  await click("label.check input");
  await click("button", "Continue");

  await visible("New list");
  await click("button", "New list");
  await until("list name field", () => js(`!!document.querySelector("#list-name")`));
  await type("#list-name", "Weekly shop");
  await js(`document.querySelector("#list-name").form.requestSubmit()`);
  for (const item of ["2 milk", "bread", "6 eggs", "washing-up liquid", "basmati rice 1kg"]) {
    await until("add field", () => js(`!!document.querySelector("#add-item")`));
    await type("#add-item", item);
    await js(`document.querySelector("#add-item").form.requestSubmit()`);
    await visible(item.replace(/^(\d+) /, "$1 × "));
  }
  await click(`.items input[type=checkbox]`); // tick the first one
  await until("the sync", () => js(`document.querySelector(".sync-state")?.getAttribute("aria-label")?.startsWith("Synced")`), 30000);
  await until("the toast to go", () => js(`!document.querySelector(".toast.show")`), 10000);
  await shoot("list");

  if (errors.length) throw new Error(`Page errors:\n${errors.join("\n")}`);
  console.log(`Smoke test passed. Screenshots in docs/: ${shots.join(", ")}`);
} finally {
  ws.close();
  chrome.kill();
  server.close();
  await new Promise((r) => setTimeout(r, 300));
  rmSync(profile, { recursive: true, force: true });
}
