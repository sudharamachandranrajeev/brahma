// Runs src/home.ts as a real process on a throwaway data folder.
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { mkdtempSync, readdirSync, rmSync, statSync } from "node:fs";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, before, test } from "node:test";

const script = new URL("../src/home.ts", import.meta.url).pathname;
const dir = mkdtempSync(join(tmpdir(), "brahma-home-"));
const env = { ...process.env, BRAHMA_SERVER_HOME: join(dir, "data") };
const run = (...args: string[]) => spawnSync("node", [script, ...args], { env, encoding: "utf8" });
let port = 0;
let server: ReturnType<typeof spawn>;
const url = (path: string) => `http://127.0.0.1:${port}${path}`;

async function freePort(): Promise<number> {
  return new Promise((resolve) => {
    const s = createServer().listen(0, "127.0.0.1", () => {
      const p = (s.address() as { port: number }).port;
      s.close(() => resolve(p));
    });
  });
}

async function start() {
  server = spawn("node", [script, "serve"], { env, stdio: ["ignore", "pipe", "inherit"] });
  await new Promise<void>((resolve) => server.stdout!.on("data", (t) => String(t).includes("listening") && resolve()));
}

async function stop() {
  const done = new Promise((r) => server.once("exit", r));
  server.kill("SIGTERM");
  await done;
}

before(async () => {
  port = await freePort();
  assert.equal(run("init", String(port)).status, 0);
  await start();
});

after(async () => {
  await stop();
  rmSync(dir, { recursive: true, force: true });
});

test("secrets and data are private to the server's user", () => {
  const mode = (f: string) => statSync(join(dir, "data", f)).mode & 0o777;
  assert.equal(mode(""), 0o700);
  assert.equal(mode("server.env"), 0o600);
  assert.equal(mode("brahma.db"), 0o600);
});

test("health says it is a home server waiting for its owner", async () => {
  const h = (await (await fetch(url("/api/health"))).json()) as { service: string; kind: string; needsSetup: boolean };
  assert.equal(h.service, "brahma-sync");
  assert.equal(h.kind, "home");
  assert.equal(h.needsSetup, true);
});

test("link prints a brahma:// setup link while no one has signed up", () => {
  const out = run("link").stdout;
  assert.match(out, /SETUP-LINK brahma:\/\/setup\?s=http%3A%2F%2F[\d.]+%3A\d+&i=[A-Z0-9-]{14}/);
});

test("a forged client-address header does not escape the rate limit", async () => {
  let last = 0;
  for (let i = 0; i < 12; i++) {
    const res = await fetch(url("/api/register"), {
      method: "POST",
      headers: { "content-type": "application/json", "cf-connecting-ip": `10.0.0.${i}` },
      body: JSON.stringify({ email: `x${i}@test`, secret: "s".repeat(43), invite: "WRONG" }),
    });
    last = res.status;
  }
  assert.equal(last, 429);
});

test("oversized requests are refused before they are read in full", async () => {
  const res = await fetch(url("/api/login"), { method: "POST", body: "a".repeat(3_100_000) }).catch(() => null);
  assert.ok(res === null || res.status === 413);
});

test("backup refuses to keep fewer than one; restore refuses while the server runs", () => {
  assert.notEqual(run("backup", "0").status, 0);
  assert.notEqual(run("backup", "many").status, 0);
  const r = run("restore", join(dir, "data", "brahma.db"));
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /Stop the server first/);
});

test("backup, then restore, brings the database back and keeps the old one", async () => {
  assert.equal(run("backup").status, 0);
  const backups = join(dir, "data", "backups");
  const file = readdirSync(backups).find((f) => f.startsWith("brahma-"))!;
  assert.match(run("status").stdout, /check: ok/);
  await stop();
  const r = run("restore", join(backups, file));
  assert.equal(r.status, 0, r.stderr);
  assert.ok(readdirSync(backups).some((f) => f.startsWith("before-restore-")));
  assert.notEqual(run("restore", join(dir, "data", "server.env")).status, 0);
  await start();
  assert.equal((await fetch(url("/api/health"))).status, 200);
});
