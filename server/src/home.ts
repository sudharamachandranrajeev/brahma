// The Brahma sync server on a computer at home: the same protocol as the
// Cloudflare Worker (src/app.ts), on Node's built-in SQLite. No packages to
// install, only Node 24 or newer.
//
//   node src/home.ts init       create the data folder and its secrets
//   node src/home.ts serve      run the server (systemd runs this)
//   node src/home.ts link       print the server's addresses and setup link
//   node src/home.ts status     health, accounts, last backup, database check
//   node src/home.ts backup     copy the database to backups/ (keeps 14)
//   node src/home.ts restore F  put backup F back (stop the server first)
//
// The data folder is $BRAHMA_SERVER_HOME, else ~/.local/share/brahma-server.
// It holds server.env (signing key, setup code; mode 600), brahma.db and
// backups/. Data in it is end-to-end encrypted except e-mails and device ids.
import { randomBytes } from "node:crypto";
import { chmodSync, copyFileSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { homedir, hostname, networkInterfaces } from "node:os";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { handle, newCode, VERSION, type Env } from "./app.ts";
import { asD1, openDatabase } from "./sqlite.ts";

const MAX_BODY = 3_000_000;
const KEEP_BACKUPS = 14;

const home = process.env.BRAHMA_SERVER_HOME || join(homedir(), ".local/share/brahma-server");
const envFile = join(home, "server.env");
const dbFile = join(home, "brahma.db");
const backups = join(home, "backups");

type Config = { TOKEN_KEY: string; SETUP_CODE: string; PORT: string; HOST: string; NAME: string };

function readConfig(): Config {
  if (!existsSync(envFile)) fail(`No server set up in ${home}. Run: node src/home.ts init`);
  const cfg: Record<string, string> = {};
  for (const line of readFileSync(envFile, "utf8").split("\n")) {
    const m = /^([A-Z_]+)=(.*)$/.exec(line.trim());
    if (m) cfg[m[1]] = m[2];
  }
  if (!cfg.TOKEN_KEY || cfg.TOKEN_KEY.length < 32) fail(`${envFile} has no TOKEN_KEY`);
  return { SETUP_CODE: "", PORT: "8090", HOST: "0.0.0.0", NAME: hostname(), ...cfg } as Config;
}

function fail(message: string): never {
  console.error(message);
  process.exit(1);
  throw new Error(message);
}

function init(port?: string) {
  process.umask(0o077);
  mkdirSync(backups, { recursive: true, mode: 0o700 });
  chmodSync(home, 0o700);
  if (existsSync(envFile)) {
    if (port) setConfig("PORT", port);
    console.log(`Already set up in ${home}.`);
  } else {
    const lines = [
      "# Brahma sync server. Keep this file private: TOKEN_KEY signs every login.",
      `TOKEN_KEY=${randomBytes(32).toString("base64url")}`,
      `SETUP_CODE=${newCode()}`,
      `PORT=${port ?? "8090"}`,
      "HOST=0.0.0.0",
      `NAME=${hostname()}`,
    ];
    writeFileSync(envFile, lines.join("\n") + "\n", { mode: 0o600 });
    console.log(`Set up a new server in ${home}.`);
  }
  openDatabase(dbFile).close();
  chmodSync(dbFile, 0o600);
}

function setConfig(key: string, value: string) {
  const text = readFileSync(envFile, "utf8");
  const line = `${key}=${value}`;
  const next = new RegExp(`^${key}=.*$`, "m").test(text)
    ? text.replace(new RegExp(`^${key}=.*$`, "m"), line)
    : `${text.trimEnd()}\n${line}\n`;
  writeFileSync(envFile, next, { mode: 0o600 });
}

/// Addresses other devices can use: home network first, then Tailscale.
function addresses(port: string): { url: string; where: "home" | "tailscale" }[] {
  const out: { url: string; where: "home" | "tailscale" }[] = [];
  for (const list of Object.values(networkInterfaces())) {
    for (const a of list ?? []) {
      if (a.family !== "IPv4" || a.internal) continue;
      const [p, q] = a.address.split(".").map(Number);
      const lan = p === 10 || (p === 172 && q >= 16 && q < 32) || (p === 192 && q === 168);
      const tailscale = p === 100 && q >= 64 && q < 128;
      if (lan || tailscale) out.push({ url: `http://${a.address}:${port}`, where: lan ? "home" : "tailscale" });
    }
  }
  return out.sort((x, y) => (x.where === y.where ? 0 : x.where === "home" ? -1 : 1));
}

const users = (db: DatabaseSync) => (db.prepare("SELECT COUNT(*) AS n FROM users").get() as { n: number }).n;

function lastBackup(): string | null {
  if (!existsSync(backups)) return null;
  const times = readdirSync(backups)
    .filter((f) => /^brahma-.*\.db$/.test(f))
    .map((f) => statSync(join(backups, f)).mtimeMs);
  return times.length ? new Date(Math.max(...times)).toISOString() : null;
}

function link() {
  const cfg = readConfig();
  const db = openDatabase(dbFile);
  const fresh = users(db) === 0;
  db.close();
  const list = addresses(cfg.PORT);
  if (!list.length) console.log(`No network found. On this computer: http://127.0.0.1:${cfg.PORT}`);
  for (const a of list) {
    console.log(`${a.where === "home" ? "At home (same Wi-Fi):" : "Anywhere (Tailscale):"} ${a.url}`);
  }
  if (fresh && cfg.SETUP_CODE && list.length) {
    // The Tailscale address works at home too, so it makes the better link.
    const best = list.find((a) => a.where === "tailscale") ?? list[0];
    console.log(`\nSetup code: ${cfg.SETUP_CODE}`);
    console.log(`SETUP-LINK brahma://setup?s=${encodeURIComponent(best.url)}&i=${cfg.SETUP_CODE}`);
  } else if (!fresh) {
    console.log("\nThe owner account exists. Invite people from the app: Settings, Sync, Invite someone.");
  }
}

function check(db: DatabaseSync): string {
  return (db.prepare("PRAGMA quick_check").get() as { quick_check: string }).quick_check;
}

function status() {
  const cfg = readConfig();
  const db = openDatabase(dbFile);
  const count = (t: string) => (db.prepare(`SELECT COUNT(*) AS n FROM ${t}`).get() as { n: number }).n;
  console.log(`Brahma sync server ${VERSION} "${cfg.NAME}" in ${home}`);
  console.log(`Accounts: ${count("users")}, devices: ${count("devices")}, changes: ${count("changes")}`);
  console.log(`Database: ${(statSync(dbFile).size / 1e6).toFixed(1)} MB, check: ${check(db)}`);
  console.log(`Last backup: ${lastBackup() ?? "never"}`);
  db.close();
}

function backup(keep = KEEP_BACKUPS) {
  if (!Number.isInteger(keep) || keep < 1) fail("Keep at least 1 backup: node src/home.ts backup [count]");
  readConfig();
  process.umask(0o077);
  mkdirSync(backups, { recursive: true, mode: 0o700 });
  const db = openDatabase(dbFile);
  const result = check(db);
  if (result !== "ok") fail(`Database check failed (${result}); not overwriting older backups.`);
  const stamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
  const file = join(backups, `brahma-${stamp}.db`);
  db.prepare("VACUUM INTO ?").run(file);
  db.close();
  const old = readdirSync(backups).filter((f) => /^brahma-.*\.db$/.test(f)).sort().reverse().slice(keep);
  for (const f of old) rmSync(join(backups, f));
  console.log(`Backed up to ${file}`);
}

async function running(port: string): Promise<boolean> {
  try {
    await fetch(`http://127.0.0.1:${port}/api/health`, { signal: AbortSignal.timeout(1500) });
    return true;
  } catch {
    return false;
  }
}

async function restore(file: string | undefined) {
  if (!file || !existsSync(file)) fail("Name the backup file to restore.");
  const cfg = readConfig();
  if (await running(cfg.PORT)) fail("Stop the server first: systemctl --user stop brahma-server");
  const probe = new DatabaseSync(file, { readOnly: true });
  try {
    if (check(probe) !== "ok") fail("That backup fails the database check.");
    probe.prepare("SELECT COUNT(*) FROM users").get();
  } catch {
    fail("That file is not a Brahma server backup.");
  } finally {
    probe.close();
  }
  process.umask(0o077);
  const stamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
  if (existsSync(dbFile)) {
    // Through SQLite, so changes still in the write-ahead log are kept too.
    const current = openDatabase(dbFile);
    current.prepare("VACUUM INTO ?").run(join(backups, `before-restore-${stamp}.db`));
    current.close();
  }
  for (const f of [`${dbFile}-wal`, `${dbFile}-shm`]) rmSync(f, { force: true });
  copyFileSync(file, dbFile);
  chmodSync(dbFile, 0o600);
  console.log(`Restored ${file}. The previous database is in backups/before-restore-${stamp}.db`);
}

function serve() {
  const cfg = readConfig();
  const db = openDatabase(dbFile);
  const env: Env = {
    DB: asD1(db),
    TOKEN_KEY: cfg.TOKEN_KEY,
    SETUP_CODE: cfg.SETUP_CODE || undefined,
    KIND: "home",
    NAME: cfg.NAME,
    lastBackup,
  };
  const server = createServer(async (req, res) => {
    const chunks: Buffer[] = [];
    let size = 0;
    for await (const c of req) {
      size += (c as Buffer).length;
      if (size > MAX_BODY) {
        res.writeHead(413, { "content-type": "application/json" }).end('{"message":"Too large"}');
        req.destroy();
        return;
      }
      chunks.push(c as Buffer);
    }
    const method = req.method ?? "GET";
    const headers = new Headers();
    for (const [k, v] of Object.entries(req.headers)) {
      // The client address comes from the socket, never from a header.
      if (k !== "cf-connecting-ip" && typeof v === "string") headers.set(k, v);
    }
    try {
      const out = await handle(
        new Request(`http://${cfg.HOST}:${cfg.PORT}${req.url ?? "/"}`, {
          method,
          headers,
          body: method === "GET" || method === "HEAD" || !chunks.length ? undefined : Buffer.concat(chunks),
        }),
        env,
        req.socket.remoteAddress ?? "unknown",
      );
      res.writeHead(out.status, Object.fromEntries(out.headers));
      res.end(Buffer.from(await out.arrayBuffer()));
    } catch (e) {
      console.error(e);
      if (!res.headersSent) res.writeHead(400).end();
    }
  });
  server.headersTimeout = 10_000;
  server.requestTimeout = 60_000;
  server.listen(Number(cfg.PORT), cfg.HOST, () => {
    console.log(`Brahma sync server ${VERSION} listening on ${cfg.HOST}:${cfg.PORT} (data in ${home})`);
  });
  const stop = () => {
    server.close(() => {
      db.close();
      process.exit(0);
    });
    server.closeAllConnections();
  };
  process.on("SIGTERM", stop);
  process.on("SIGINT", stop);
}

const [cmd, arg] = process.argv.slice(2);
switch (cmd) {
  case "init":
    init(arg);
    break;
  case "serve":
    serve();
    break;
  case "link":
    link();
    break;
  case "status":
    status();
    break;
  case "backup":
    backup(arg === undefined ? undefined : Number(arg));
    break;
  case "restore":
    await restore(arg);
    break;
  default:
    console.log("Usage: node src/home.ts init [port] | serve | link | status | backup [keep] | restore FILE");
    process.exit(cmd ? 1 : 0);
}
