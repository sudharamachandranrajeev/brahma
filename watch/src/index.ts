import PostalMime from "postal-mime";
import { fetchSearch } from "./propertypal.ts";
import { ntfyMessage, sendNtfy } from "./notify.ts";
import { parseAlertEmail, portalForSender, senderAddress } from "./email.ts";
import { locate } from "./geo.ts";
import { diff, diffEmail, type Seen, type Watch, type WatchEvent } from "./watch.ts";

export interface Env {
  KV: KVNamespace;
  /** Secret ntfy topic name (long and random: anyone who knows it can read it). */
  NTFY_TOPIC: string;
  NTFY_SERVER?: string;
  NTFY_TOKEN?: string;
  /** Bearer token for the HTTP API that Anveshana uses. */
  API_TOKEN: string;
  /**
   * Mailboxes allowed to forward alert emails in, comma separated (e.g.
   * "you@gmail.com"). Gmail's "+caf_" forwarding tags are ignored. Email from
   * anyone else is refused, so a stranger cannot push fake adverts to you.
   */
  ALLOWED_FORWARDERS?: string;
}

export interface WatchStatus {
  lastRun: string;
  lastOk: string | null;
  failures: number;
  lastError: string | null;
  listings: number;
}

/** What the email side last did, for GET /email. */
export interface EmailStatus {
  at: string;
  from: string;
  subject: string;
  portal: string | null;
  adverts: number;
  events: number;
  error: string | null;
}

const keepEvents = 500;
/** Consecutive failed runs before the phone hears about it (about an hour). */
const failuresBeforeWarning = 6;
/** How stale a healthy search's stored status may get before it is rewritten. */
const statusRefreshMs = 60 * 60 * 1000;
/** Characters of a puzzling email kept for fixing the reader. */
const keepEmailChars = 60_000;

/**
 * Whether a search's status is worth a KV write. The free plan allows 1,000
 * writes a day and the cron runs 144 times, so a healthy search rewrites
 * its status at most hourly; any change in health is written at once.
 */
export function statusWorthWriting(prev: WatchStatus | null, next: WatchStatus): boolean {
  if (!prev) return true;
  if (prev.failures !== next.failures || prev.lastError !== next.lastError || prev.listings !== next.listings) {
    return true;
  }
  const last = Date.parse(prev.lastOk ?? prev.lastRun);
  return !Number.isFinite(last) || Date.parse(next.lastRun) - last >= statusRefreshMs;
}

async function loadWatches(env: Env): Promise<Watch[]> {
  return (await env.KV.get<Watch[]>("watches", "json")) ?? [];
}

async function push(env: Env, body: object) {
  await sendNtfy(env.NTFY_SERVER ?? "https://ntfy.sh", env.NTFY_TOKEN, body);
}

async function recordEvents(env: Env, events: WatchEvent[]) {
  if (!events.length) return;
  const old = (await env.KV.get<WatchEvent[]>("events", "json")) ?? [];
  await env.KV.put("events", JSON.stringify([...old, ...events].slice(-keepEvents)));
}

export async function runWatches(env: Env, now = new Date().toISOString()) {
  const summary: Record<string, { listings?: number; events?: number; error?: string }> = {};
  const newEvents: WatchEvent[] = [];
  for (const w of await loadWatches(env)) {
    // Email searches wait for mail; there is nothing to fetch.
    if (w.paused || w.source === "email") continue;
    const prev = await env.KV.get<WatchStatus>(`status:${w.id}`, "json");
    const status: WatchStatus = prev
      ? { ...prev }
      : { lastRun: now, lastOk: null, failures: 0, lastError: null, listings: 0 };
    try {
      const listings = await fetchSearch(w.path);
      const before = await env.KV.get<Record<string, Seen>>(`seen:${w.id}`, "json");
      const { events, seen } = diff(w, listings, before, now);
      // Push before recording: if ntfy fails, the next run alerts again
      // rather than never.
      for (const e of events) await push(env, ntfyMessage(env.NTFY_TOPIC, e, w.name));
      if (JSON.stringify(seen) !== JSON.stringify(before)) await env.KV.put(`seen:${w.id}`, JSON.stringify(seen));
      newEvents.push(...events);
      Object.assign(status, { lastRun: now, lastOk: now, failures: 0, lastError: null, listings: listings.length });
      summary[w.id] = { listings: listings.length, events: events.length };
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      Object.assign(status, { lastRun: now, failures: status.failures + 1, lastError: message });
      summary[w.id] = { error: message };
      if (status.failures === failuresBeforeWarning) {
        await push(env, {
          topic: env.NTFY_TOPIC,
          title: `Brahma Watch: "${w.name}" is failing`,
          message: `${failuresBeforeWarning} runs in a row failed. Last error: ${message}`,
          tags: ["warning"],
        }).catch(() => {});
      }
    }
    if (statusWorthWriting(prev, status)) await env.KV.put(`status:${w.id}`, JSON.stringify(status));
  }
  await recordEvents(env, newEvents);
  return summary;
}

// ---- Alert emails ----

/** "you+caf_=homes=example.org@gmail.com" becomes "you@gmail.com". */
export function mailbox(address: string): string {
  const a = address.trim().toLowerCase();
  const at = a.lastIndexOf("@");
  if (at < 0) return a;
  return `${a.slice(0, at).split("+")[0]}${a.slice(at)}`;
}

export function forwarderAllowed(envelopeFrom: string, allowed: string | undefined): boolean {
  const list = (allowed ?? "").split(",").map(mailbox).filter(Boolean);
  return list.includes(mailbox(envelopeFrom));
}

/** Runs every email search over one alert email. */
export async function handleAlert(
  env: Env,
  mail: { from: string; subject: string; html?: string; text?: string },
  now = new Date().toISOString(),
  locator: typeof locate = locate,
): Promise<EmailStatus> {
  const parsed = parseAlertEmail(mail);
  const status: EmailStatus = {
    at: now,
    from: senderAddress(mail.from),
    subject: mail.subject.slice(0, 200),
    portal: parsed.portal?.label ?? null,
    adverts: parsed.listings.length,
    events: 0,
    error: null,
  };
  if (!parsed.listings.length) {
    status.error = "No adverts found in this email. A copy is kept for fixing the reader (GET /email).";
    await env.KV.put(
      "email:puzzling",
      JSON.stringify({
        ...status,
        html: (mail.html ?? "").slice(0, keepEmailChars),
        text: (mail.text ?? "").slice(0, keepEmailChars),
      }),
    );
    await push(env, {
      topic: env.NTFY_TOPIC,
      title: "Brahma Watch could not read an alert email",
      message: `${status.portal ?? status.from}: "${status.subject}". Your alerts still arrive by email.`,
      tags: ["warning"],
    }).catch(() => {});
    return status;
  }
  await locator(parsed.listings);
  const events: WatchEvent[] = [];
  for (const w of await loadWatches(env)) {
    if (w.paused || w.source !== "email") continue;
    const before = await env.KV.get<Record<string, Seen>>(`seen:${w.id}`, "json");
    const out = diffEmail(w, parsed.listings, before, now);
    for (const e of out.events) await push(env, ntfyMessage(env.NTFY_TOPIC, e, w.name));
    await env.KV.put(`seen:${w.id}`, JSON.stringify(out.seen));
    events.push(...out.events);
  }
  // The same home can match two searches; the app imports it once.
  await recordEvents(env, events);
  status.events = events.length;
  return status;
}

async function receiveEmail(message: ForwardableEmailMessage, env: Env) {
  const mail = await PostalMime.parse(message.raw);
  const from = mail.from?.address ?? message.headers.get("from") ?? "";
  const subject = mail.subject ?? "";
  // Gmail asks the forwarding address to confirm before it forwards. Pass on
  // the code only: a link in a push could be a fake.
  if (senderAddress(from) === "forwarding-noreply@google.com") {
    const code = /confirmation code:\s*(\d{6,12})/i.exec(mail.text ?? "")?.[1];
    await push(env, {
      topic: env.NTFY_TOPIC,
      title: "Gmail forwarding to Brahma Watch",
      message: code
        ? `Confirmation code ${code}. Type it into Gmail's forwarding settings yourself.`
        : "Gmail sent a confirmation email, but no code was found in it.",
      tags: ["envelope"],
    });
    return;
  }
  if (!forwarderAllowed(message.from, env.ALLOWED_FORWARDERS)) {
    message.setReject("This address only takes alert emails forwarded by its owner.");
    return;
  }
  if (!portalForSender(from)) {
    message.setReject("Only Rightmove, Zoopla, OnTheMarket, OpenRent and SpareRoom alerts are read here.");
    return;
  }
  const status = await handleAlert(env, { from, subject, html: mail.html, text: mail.text });
  await env.KV.put("email:last", JSON.stringify(status));
}

// ---- HTTP API (for Anveshana and for testing) ----

export function validWatch(x: unknown): x is Watch {
  if (!x || typeof x !== "object") return false;
  const w = x as Record<string, unknown>;
  const num = (v: unknown) => v === undefined || (typeof v === "number" && Number.isFinite(v) && v >= 0);
  const c = w.centre as Record<string, unknown> | undefined;
  const email = w.source === "email";
  return (
    typeof w.id === "string" &&
    /^[a-z0-9-]{1,64}$/.test(w.id) &&
    typeof w.name === "string" &&
    w.name.length <= 200 &&
    (w.source === "propertypal" || email) &&
    typeof w.path === "string" &&
    (email ? w.path === "" : /^\/property-(to-rent|for-sale)\/[a-z0-9-]+(\/[a-z0-9-]+)*$/.test(w.path)) &&
    (w.kind === undefined || w.kind === "rent" || w.kind === "buy") &&
    num(w.maxPrice) &&
    num(w.minBeds) &&
    num(w.maxBeds) &&
    num(w.radiusKm) &&
    (c === undefined ||
      (typeof c.lat === "number" && typeof c.lon === "number" && typeof c.label === "string")) &&
    (w.keywords === undefined ||
      (Array.isArray(w.keywords) &&
        w.keywords.length <= 20 &&
        w.keywords.every((k) => typeof k === "string" && k.length <= 40))) &&
    (w.includeUnpriced === undefined || typeof w.includeUnpriced === "boolean") &&
    (w.paused === undefined || typeof w.paused === "boolean")
  );
}

async function authorised(req: Request, env: Env): Promise<boolean> {
  const given = new TextEncoder().encode(req.headers.get("authorization") ?? "");
  const want = new TextEncoder().encode(`Bearer ${env.API_TOKEN}`);
  if (!env.API_TOKEN || given.byteLength !== want.byteLength) return false;
  // Constant time, so response timing does not leak the token.
  let diff = 0;
  for (let i = 0; i < want.byteLength; i++) diff |= given[i] ^ want[i];
  return diff === 0;
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body, null, 2), { status, headers: { "content-type": "application/json" } });

async function handle(req: Request, env: Env): Promise<Response> {
  if (!(await authorised(req, env))) return json({ error: "unauthorised" }, 401);
  const { pathname, searchParams } = new URL(req.url);
  if (pathname === "/watches" && req.method === "GET") return json(await loadWatches(env));
  if (pathname === "/watches" && req.method === "PUT") {
    const body = await req.json().catch(() => null);
    if (!Array.isArray(body) || body.length > 50 || !body.every(validWatch)) {
      return json({ error: "expected an array of up to 50 valid watches" }, 400);
    }
    await env.KV.put("watches", JSON.stringify(body));
    return json(body);
  }
  if (pathname === "/events" && req.method === "GET") {
    const since = searchParams.get("since") ?? "";
    const events = (await env.KV.get<WatchEvent[]>("events", "json")) ?? [];
    return json(events.filter((e) => e.at > since));
  }
  if (pathname === "/status" && req.method === "GET") {
    const out: Record<string, unknown> = {};
    for (const w of await loadWatches(env)) out[w.id] = await env.KV.get(`status:${w.id}`, "json");
    return json(out);
  }
  if (pathname === "/email" && req.method === "GET") {
    return json({
      last: await env.KV.get("email:last", "json"),
      puzzling: await env.KV.get("email:puzzling", "json"),
    });
  }
  if (pathname === "/run" && req.method === "POST") return json(await runWatches(env));
  if (pathname === "/test-notify" && req.method === "POST") {
    await push(env, {
      topic: env.NTFY_TOPIC,
      title: "Brahma Watch",
      message: "Test alert: your phone is set up.",
      tags: ["white_check_mark"],
    });
    return json({ sent: true });
  }
  return json({ error: "not found" }, 404);
}

export default {
  fetch: (req: Request, env: Env) => handle(req, env),
  scheduled: async (_controller: ScheduledController, env: Env, ctx: ExecutionContext) => {
    ctx.waitUntil(runWatches(env));
  },
  email: (message: ForwardableEmailMessage, env: Env) => receiveEmail(message, env),
} satisfies ExportedHandler<Env>;
