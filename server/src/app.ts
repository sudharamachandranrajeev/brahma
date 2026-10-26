// The Brahma sync protocol over HTTP + D1. The server never sees a password,
// a data key or plaintext: clients send a login secret derived from the
// password, wrapped keys and encrypted change batches.

import { threats } from "./threats.ts";

export interface Env {
  DB: D1Database;
  /// Signs session tokens.
  TOKEN_KEY: string;
  /// Lets the first person create the owner account; unused after that.
  SETUP_CODE?: string;
  ASSETS?: Fetcher;
  /// "home" (src/home.ts) or "cloud" (the Worker); shown in the app's Settings.
  KIND?: string;
  /// A friendly server name, like the home computer's name.
  NAME?: string;
  /// When the last backup finished (ISO time), where the server makes them.
  lastBackup?: () => string | null;
}

export const VERSION = "1.0.0";
const PROTOCOL = 1;
const TOKEN_DAYS = 30;
const PAIRING_MINUTES = 10;
const CODE_DAYS = 7;
// Under D1's 2 MB row limit, so cloud and home refuse the same batches.
const MAX_PAYLOAD = 1_900_000;
// A page of changes stops growing past this, so it fits a Worker's memory.
const MAX_PAGE_BYTES = 8_000_000;
const ID_ALPHABET = "abcdefghijklmnopqrstuvwxyz0123456789";
const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTVWXYZ23456789";

class HttpError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

const enc = new TextEncoder();
const b64 = (bytes: ArrayBuffer | Uint8Array) =>
  btoa(String.fromCharCode(...new Uint8Array(bytes))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

const hmacKey = (secret: string) =>
  crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);

async function mac(env: Env, text: string): Promise<string> {
  return b64(await crypto.subtle.sign("HMAC", await hmacKey(env.TOKEN_KEY), enc.encode(text)));
}

function same(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

function randomFrom(alphabet: string, n: number): string {
  // Rejection sampling keeps every character equally likely.
  const limit = 256 - (256 % alphabet.length);
  let out = "";
  while (out.length < n) {
    for (const byte of crypto.getRandomValues(new Uint8Array(n * 2))) {
      if (byte < limit && out.length < n) out += alphabet[byte % alphabet.length];
    }
  }
  return out;
}

const newId = () => randomFrom(ID_ALPHABET, 15);
export const newCode = () => (randomFrom(CODE_ALPHABET, 12).match(/.{4}/g) as string[]).join("-");
const normaliseCode = (code: string) => code.toUpperCase().replace(/[^A-Z0-9]/g, "");
const now = () => Math.floor(Date.now() / 1000);
const iso = () => new Date().toISOString();

interface User {
  id: string;
  email: string;
  secret_hash: string;
  tokver: number;
  is_owner: number;
}

async function issueToken(env: Env, user: Pick<User, "id" | "tokver">): Promise<string> {
  const body = `${user.id}.${now() + TOKEN_DAYS * 86400}.${user.tokver}`;
  return `${body}.${await mac(env, `token:${body}`)}`;
}

async function authenticate(env: Env, req: Request): Promise<User> {
  const token = /^Bearer (\S+)$/.exec(req.headers.get("authorization") ?? "")?.[1];
  const parts = token?.split(".");
  if (!parts || parts.length !== 4) throw new HttpError(401, "Sign in again");
  const [id, exp, ver, sig] = parts;
  if (!same(sig, await mac(env, `token:${id}.${exp}.${ver}`)) || Number(exp) < now()) {
    throw new HttpError(401, "Sign in again");
  }
  const user = await env.DB.prepare("SELECT * FROM users WHERE id = ?").bind(id).first<User>();
  if (!user || user.tokver !== Number(ver)) throw new HttpError(401, "Sign in again");
  return user;
}

async function limit(env: Env, ip: string, name: string, max: number, seconds: number): Promise<void> {
  const window = Math.floor(now() / seconds);
  const key = `${name}:${ip}`;
  const row = await env.DB.prepare(
    "INSERT INTO rate (key, window, n) VALUES (?1, ?2, 1) " +
      "ON CONFLICT(key) DO UPDATE SET n = CASE WHEN window = ?2 THEN n + 1 ELSE 1 END, window = ?2 " +
      "RETURNING n",
  ).bind(key, window).first<{ n: number }>();
  // Now and then, forget old windows of this limit so the table stays small.
  if (Math.random() < 0.02) {
    await env.DB.prepare("DELETE FROM rate WHERE key LIKE ? AND window < ?").bind(`${name}:%`, window - 1).run();
  }
  if ((row?.n ?? 1) > max) throw new HttpError(429, "Too many attempts. Wait a minute and try again");
}

async function body(req: Request): Promise<Record<string, unknown>> {
  try {
    const v = await req.json();
    if (v && typeof v === "object" && !Array.isArray(v)) return v as Record<string, unknown>;
  } catch {
    // falls through
  }
  throw new HttpError(400, "Send a JSON object");
}

function text(v: unknown, name: string, max: number, min = 1): string {
  if (typeof v !== "string" || v.length < min || v.length > max) throw new HttpError(400, `Invalid ${name}`);
  return v;
}

const email = (v: unknown) => {
  const mail = text(v, "e-mail", 200).trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+$/.test(mail)) throw new HttpError(400, "Enter a valid e-mail");
  return mail;
};
const secret = (v: unknown, name = "secret") => text(v, name, 200, 20);
const hash = (env: Env, v: string) => mac(env, `secret:${v}`);
const codeHash = (env: Env, code: string) => mac(env, `code:${normaliseCode(code)}`);
const deviceId = (v: unknown) => {
  const d = text(v, "device", 32, 32);
  if (!/^[0-9a-f]{32}$/.test(d)) throw new HttpError(400, "Invalid device");
  return d;
};

async function makeCode(env: Env, kind: "invite" | "reset", userId = ""): Promise<{ code: string; expires: number }> {
  const code = newCode();
  const expires = now() + CODE_DAYS * 86400;
  await env.DB.prepare("DELETE FROM codes WHERE expires < ?").bind(now()).run();
  await env.DB.prepare("INSERT INTO codes (hash, kind, user_id, expires) VALUES (?, ?, ?, ?)")
    .bind(await codeHash(env, code), kind, userId, expires)
    .run();
  return { code, expires };
}

/// Takes a code if it is live; false otherwise. One use only.
async function useCode(env: Env, code: string, kind: string, userId?: string): Promise<boolean> {
  const row = await env.DB.prepare(
    "DELETE FROM codes WHERE hash = ? AND kind = ? AND expires > ? AND (? IS NULL OR user_id = ?) RETURNING hash",
  ).bind(await codeHash(env, code), kind, now(), userId ?? null, userId ?? null).first();
  return row !== null;
}

async function session(env: Env, user: Pick<User, "id" | "tokver">) {
  return json({ userId: user.id, token: await issueToken(env, user) });
}

const BAD_LOGIN = "Wrong e-mail or password";

async function route(req: Request, env: Env, url: URL, ip: string): Promise<Response> {
  const path = url.pathname.replace(/\/+$/, "");
  const method = req.method;
  const is = (m: string, p: string) => method === m && path === p;

  if (is("GET", "/api/health")) {
    const n = await env.DB.prepare("SELECT COUNT(*) AS n FROM users").first<{ n: number }>();
    return json({
      service: "brahma-sync",
      protocol: PROTOCOL,
      version: VERSION,
      kind: env.KIND ?? "cloud",
      name: env.NAME ?? "",
      needsSetup: (n?.n ?? 0) === 0,
    });
  }

  if (is("POST", "/api/register")) {
    await limit(env, ip, "register", 10, 3600);
    const b = await body(req);
    const mail = email(b.email), sec = secret(b.secret);
    const existing = await env.DB.prepare("SELECT * FROM users WHERE email = ?").bind(mail).first<User>();
    if (existing) {
      // A sign-up that stopped half way is finished by repeating it.
      if (same(existing.secret_hash, await hash(env, sec))) return session(env, existing);
      throw new HttpError(409, "This e-mail already has an account: sign in instead");
    }
    const invite = text(b.invite, "invite code", 100);
    const first = ((await env.DB.prepare("SELECT COUNT(*) AS n FROM users").first<{ n: number }>())?.n ?? 0) === 0;
    if (first) {
      if (!env.SETUP_CODE || !same(normaliseCode(invite), normaliseCode(env.SETUP_CODE))) {
        throw new HttpError(403, "That setup code is not right");
      }
    } else if (!(await useCode(env, invite, "invite"))) {
      throw new HttpError(403, "That invite code is invalid or expired. Ask the owner for a new one");
    }
    const user = { id: newId(), tokver: 1 };
    await env.DB.prepare("INSERT INTO users (id, email, secret_hash, is_owner, created) VALUES (?, ?, ?, ?, ?)")
      .bind(user.id, mail, await hash(env, sec), first ? 1 : 0, iso())
      .run();
    return session(env, user);
  }

  if (is("POST", "/api/login")) {
    await limit(env, ip, "login", 20, 60);
    const b = await body(req);
    const mail = email(b.email);
    // Per account too, so changing address does not buy more guesses.
    await limit(env, mail, "login-mail", 10, 60);
    const user = await env.DB.prepare("SELECT * FROM users WHERE email = ?").bind(mail).first<User>();
    const given = await hash(env, secret(b.secret));
    if (!user || !same(user.secret_hash, given)) throw new HttpError(401, BAD_LOGIN);
    return session(env, user);
  }

  if (is("POST", "/api/reset")) {
    await limit(env, ip, "reset", 10, 3600);
    const b = await body(req);
    const newSecret = secret(b.secret);
    const user = await env.DB.prepare("SELECT * FROM users WHERE email = ?").bind(email(b.email)).first<User>();
    if (!user || !(await useCode(env, text(b.code, "code", 100), "reset", user.id))) {
      throw new HttpError(403, "That reset code is invalid or expired");
    }
    const next = { id: user.id, tokver: user.tokver + 1 };
    await env.DB.prepare("UPDATE users SET secret_hash = ?, tokver = ? WHERE id = ?")
      .bind(await hash(env, newSecret), next.tokver, user.id)
      .run();
    return session(env, next);
  }

  // Pairing: the new device has no account yet, so these two are open and
  // guarded by the record id in the QR code (unguessable, 10 minutes, one use).
  const pair = /^\/api\/pairings\/([a-z0-9]{15})(\/request)?$/.exec(path);
  if (pair && method === "GET" && !pair[2]) {
    const row = await livePairing(env, pair[1]);
    return json({ request: row.request, response: row.response });
  }
  if (pair && method === "PUT" && pair[2]) {
    await limit(env, ip, "pair", 20, 60);
    const request = text((await body(req)).request, "request", 2000);
    await livePairing(env, pair[1]);
    const done = await env.DB.prepare("UPDATE pairings SET request = ? WHERE id = ? AND request = '' RETURNING id")
      .bind(request, pair[1])
      .first();
    if (!done) throw new HttpError(409, "Someone already used this code");
    return json({ ok: true });
  }

  if (is("GET", "/api/me")) {
    const u = await authenticate(env, req);
    return json({ userId: u.id, email: u.email, owner: u.is_owner === 1, lastBackup: env.lastBackup?.() ?? null });
  }

  const user = await authenticate(env, req);

  if (is("GET", "/api/threats")) {
    try {
      return json(await threats());
    } catch {
      throw new HttpError(503, "Could not fetch the threat list");
    }
  }

  if (is("POST", "/api/invites")) {
    if (!user.is_owner) throw new HttpError(403, "Only the owner can invite people");
    return json(await makeCode(env, "invite"));
  }
  if (is("POST", "/api/members/reset")) {
    if (!user.is_owner) throw new HttpError(403, "Only the owner can reset a login");
    const target = await env.DB.prepare("SELECT id FROM users WHERE email = ?")
      .bind(email((await body(req)).email))
      .first<{ id: string }>();
    if (!target) throw new HttpError(404, "No one here has that e-mail");
    return json(await makeCode(env, "reset", target.id));
  }
  if (is("GET", "/api/members")) {
    if (!user.is_owner) throw new HttpError(403, "Only the owner can list people");
    const rows = await env.DB.prepare("SELECT email, is_owner FROM users ORDER BY created").all();
    return json({ members: rows.results.map((r) => ({ email: r.email, owner: r.is_owner === 1 })) });
  }

  if (is("POST", "/api/password")) {
    const b = await body(req);
    const current = await hash(env, secret(b.oldSecret, "old secret"));
    if (!same(user.secret_hash, current)) throw new HttpError(400, "The old password is not right");
    const next = { id: user.id, tokver: user.tokver + 1 };
    await env.DB.prepare("UPDATE users SET secret_hash = ?, tokver = ? WHERE id = ?")
      .bind(await hash(env, secret(b.newSecret, "new secret")), next.tokver, user.id)
      .run();
    return session(env, next);
  }

  if (path === "/api/vault") {
    if (method === "GET") {
      const v = await env.DB.prepare("SELECT * FROM vaults WHERE owner_id = ?").bind(user.id).first();
      if (!v) throw new HttpError(404, "No vault");
      return json({ wrappedPassword: v.wrapped_password, wrappedRecovery: v.wrapped_recovery, version: v.version });
    }
    if (method === "POST") {
      const b = await body(req);
      const made = await env.DB.prepare(
        "INSERT OR IGNORE INTO vaults (owner_id, wrapped_password, wrapped_recovery, version) VALUES (?, ?, ?, 1) RETURNING owner_id",
      ).bind(user.id, text(b.wrappedPassword, "vault", 500), text(b.wrappedRecovery, "vault", 500)).first();
      if (!made) throw new HttpError(409, "This account already has a vault");
      return json({ ok: true }, 201);
    }
    if (method === "PUT") {
      const b = await body(req);
      await env.DB.prepare("UPDATE vaults SET wrapped_password = ? WHERE owner_id = ?")
        .bind(text(b.wrappedPassword, "vault", 500), user.id)
        .run();
      return json({ ok: true });
    }
  }

  if (path === "/api/devices") {
    if (method === "POST") {
      const b = await body(req);
      await env.DB.prepare("INSERT OR IGNORE INTO devices (owner_id, device, platform, created) VALUES (?, ?, ?, ?)")
        .bind(user.id, deviceId(b.device), typeof b.platform === "string" ? b.platform.slice(0, 20) : "", iso())
        .run();
      return json({ ok: true }, 201);
    }
    if (method === "GET") {
      const rows = await env.DB.prepare("SELECT device FROM devices WHERE owner_id = ?").bind(user.id).all();
      return json({ devices: rows.results.map((r) => r.device) });
    }
  }

  if (is("POST", "/api/changes")) {
    await limit(env, ip, `push:${user.id}`, 600, 10);
    const b = await body(req);
    const seq = b.seq;
    if (!Number.isInteger(seq) || (seq as number) < 1) throw new HttpError(400, "Invalid seq");
    const made = await env.DB.prepare(
      "INSERT OR IGNORE INTO changes (owner_id, device, seq, payload, created) VALUES (?, ?, ?, ?, ?) RETURNING seq",
    ).bind(user.id, deviceId(b.device), seq, text(b.payload, "payload", MAX_PAYLOAD), iso()).first();
    if (!made) throw new HttpError(409, "That slot is taken");
    return json({ ok: true }, 201);
  }
  if (is("GET", "/api/changes")) {
    const device = deviceId(url.searchParams.get("device"));
    const after = Math.max(0, Number(url.searchParams.get("after")) || 0);
    const count = Math.min(200, Math.max(1, Number(url.searchParams.get("limit")) || 50));
    const rows = await env.DB.prepare(
      "SELECT seq, payload FROM changes WHERE owner_id = ? AND device = ? AND seq > ? ORDER BY seq LIMIT ?",
    ).bind(user.id, device, after, count).all();
    // Always at least one, so a device with only large batches still moves on.
    const items = [];
    let bytes = 0;
    for (const r of rows.results) {
      bytes += String(r.payload).length;
      if (items.length && bytes > MAX_PAGE_BYTES) break;
      items.push(r);
    }
    return json({ items });
  }
  if (is("GET", "/api/changes/last")) {
    const row = await env.DB.prepare("SELECT MAX(seq) AS seq FROM changes WHERE owner_id = ? AND device = ?")
      .bind(user.id, deviceId(url.searchParams.get("device")))
      .first<{ seq: number | null }>();
    return json({ seq: row?.seq ?? 0 });
  }
  if (is("GET", "/api/changes/one")) {
    const row = await env.DB.prepare("SELECT payload FROM changes WHERE owner_id = ? AND device = ? AND seq = ?")
      .bind(user.id, deviceId(url.searchParams.get("device")), Number(url.searchParams.get("seq")))
      .first<{ payload: string }>();
    if (!row) throw new HttpError(404, "No such change");
    return json({ payload: row.payload });
  }

  if (is("POST", "/api/pairings")) {
    await limit(env, ip, "offer", 20, 60);
    const id = newId();
    await env.DB.prepare("DELETE FROM pairings WHERE expires < ?").bind(now()).run();
    await env.DB.prepare("INSERT INTO pairings (id, owner_id, expires) VALUES (?, ?, ?)")
      .bind(id, user.id, now() + PAIRING_MINUTES * 60)
      .run();
    return json({ id }, 201);
  }
  const owned = /^\/api\/pairings\/([a-z0-9]{15})(\/response)?$/.exec(path);
  if (owned && method === "PUT" && owned[2]) {
    const response = text((await body(req)).response, "response", 4000);
    const row = await livePairing(env, owned[1]);
    if (row.owner_id !== user.id) throw new HttpError(404, "This code has expired");
    const done = await env.DB.prepare(
      "UPDATE pairings SET response = ? WHERE id = ? AND request != '' AND response = '' RETURNING id",
    ).bind(response, owned[1]).first();
    if (!done) throw new HttpError(409, "Nothing to answer");
    return json({ ok: true });
  }
  if (owned && method === "DELETE" && !owned[2]) {
    await env.DB.prepare("DELETE FROM pairings WHERE id = ? AND owner_id = ?").bind(owned[1], user.id).run();
    return new Response(null, { status: 204 });
  }

  throw new HttpError(404, "Not found");
}

async function livePairing(env: Env, id: string): Promise<{ owner_id: string; request: string; response: string }> {
  const row = await env.DB.prepare("SELECT owner_id, request, response FROM pairings WHERE id = ? AND expires > ?")
    .bind(id, now())
    .first<{ owner_id: string; request: string; response: string }>();
  if (!row) throw new HttpError(404, "This code has expired or was already used");
  return row;
}

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, content-type",
  "access-control-allow-methods": "GET, POST, PUT, DELETE, OPTIONS",
  "access-control-max-age": "86400",
};

/// [ip] keys the rate limits: Cloudflare's client address on the Worker, the
/// socket's peer address on a home server.
export async function handle(
  req: Request,
  env: Env,
  ip = req.headers.get("cf-connecting-ip") ?? "local",
): Promise<Response> {
  const url = new URL(req.url);
  if (!url.pathname.startsWith("/api/")) {
    return env.ASSETS ? env.ASSETS.fetch(req) : new Response("Brahma sync server", { status: 200 });
  }
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  let res: Response;
  try {
    res = await route(req, env, url, ip);
  } catch (e) {
    if (e instanceof HttpError) res = json({ message: e.message }, e.status);
    else {
      console.error(e);
      res = json({ message: "Server error" }, 500);
    }
  }
  const out = new Response(res.body, res);
  for (const [k, v] of Object.entries(CORS)) out.headers.set(k, v);
  out.headers.set("cache-control", "no-store");
  return out;
}
