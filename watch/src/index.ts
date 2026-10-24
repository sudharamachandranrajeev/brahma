import { fetchSearch } from "./propertypal.ts";
import { ntfyMessage, sendNtfy } from "./notify.ts";
import { diff, type Seen, type Watch, type WatchEvent } from "./watch.ts";
import { handleSocial } from "./social/api.ts";
import { mediaSignatureOk } from "./social/crypto.ts";
import { runDue } from "./social/discovery.ts";
import { Budget } from "./social/http.ts";
import { pollAll } from "./social/inbox.ts";
import { serve } from "./social/media.ts";
import { oauthCallback, webhook } from "./social/oauth.ts";
import type { Ctx } from "./social/platforms/adapter.ts";
import { eachProfile } from "./social/profiles.ts";
import { publishDue } from "./social/publish.ts";
import { daily } from "./social/stats.ts";
import { Store, type SocialEnv } from "./social/store.ts";

export interface Env extends SocialEnv {
  KV: KVNamespace;
  /** Secret ntfy topic name (long and random: anyone who knows it can read it). */
  NTFY_TOPIC: string;
  NTFY_SERVER?: string;
  NTFY_TOKEN?: string;
  /** Bearer token for the HTTP API that Anveshana and Vani use. */
  API_TOKEN: string;
  /**
   * Outbound requests one run may make: 50 on the Workers free plan (the
   * default leaves headroom), 1000 on Workers Paid.
   */
  SUBREQUEST_BUDGET?: string;
}

interface WatchStatus {
  lastRun: string;
  lastOk: string | null;
  failures: number;
  lastError: string | null;
  listings: number;
}

const keepEvents = 500;
/** Consecutive failed runs before the phone hears about it (about an hour). */
const failuresBeforeWarning = 6;

async function loadWatches(env: Env): Promise<Watch[]> {
  return (await env.KV.get<Watch[]>("watches", "json")) ?? [];
}

async function push(env: Env, body: object) {
  await sendNtfy(env.NTFY_SERVER ?? "https://ntfy.sh", env.NTFY_TOKEN, body);
}

export async function runWatches(env: Env, now = new Date().toISOString()) {
  const summary: Record<string, { listings?: number; events?: number; error?: string }> = {};
  const newEvents: WatchEvent[] = [];
  for (const w of await loadWatches(env)) {
    if (w.paused) continue;
    const status = (await env.KV.get<WatchStatus>(`status:${w.id}`, "json")) ?? {
      lastRun: now,
      lastOk: null,
      failures: 0,
      lastError: null,
      listings: 0,
    };
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
    await env.KV.put(`status:${w.id}`, JSON.stringify(status));
  }
  if (newEvents.length) {
    const old = (await env.KV.get<WatchEvent[]>("events", "json")) ?? [];
    await env.KV.put("events", JSON.stringify([...old, ...newEvents].slice(-keepEvents)));
  }
  return summary;
}

// ---- HTTP API (for Anveshana and for testing) ----

function validWatch(x: unknown): x is Watch {
  if (!x || typeof x !== "object") return false;
  const w = x as Record<string, unknown>;
  const num = (v: unknown) => v === undefined || (typeof v === "number" && Number.isFinite(v) && v >= 0);
  const c = w.centre as Record<string, unknown> | undefined;
  return (
    typeof w.id === "string" &&
    /^[a-z0-9-]{1,64}$/.test(w.id) &&
    typeof w.name === "string" &&
    w.name.length <= 200 &&
    w.source === "propertypal" &&
    typeof w.path === "string" &&
    /^\/property-(to-rent|for-sale)\/[a-z0-9-]+(\/[a-z0-9-]+)*$/.test(w.path) &&
    num(w.maxPrice) &&
    num(w.minBeds) &&
    num(w.maxBeds) &&
    num(w.radiusKm) &&
    (c === undefined ||
      (typeof c.lat === "number" && typeof c.lon === "number" && typeof c.label === "string")) &&
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

const socialReady = (env: Env) => !!(env.DB && env.MEDIA && env.TOKEN_KEY && env.PUBLIC_URL);

function socialCtx(env: Env, now = new Date()): Ctx {
  return { env, store: new Store(env), budget: new Budget(Number(env.SUBREQUEST_BUDGET) || 45), now };
}

async function handle(req: Request, env: Env, waitUntil: (p: Promise<unknown>) => void): Promise<Response> {
  const { pathname, searchParams } = new URL(req.url);
  // Unauthenticated edges of the social hub; each checks a state or signature.
  if (socialReady(env)) {
    const oauth = pathname.match(/^\/oauth\/([a-z]+)\/callback$/);
    if (oauth && req.method === "GET") return oauthCallback(socialCtx(env), oauth[1], new URL(req.url));
    const hook = pathname.match(/^\/webhooks\/([a-z]+)$/);
    if (hook) return webhook(socialCtx(env), hook[1], req, waitUntil);
    const media = pathname.match(/^\/media\/([\w-]{1,64})$/);
    if (media && (req.method === "GET" || req.method === "HEAD")) {
      if (!(await mediaSignatureOk(env.TOKEN_KEY, media[1], searchParams.get("exp"), searchParams.get("sig")))) {
        return new Response("forbidden", { status: 403 });
      }
      return serve(new Store(env), media[1], req);
    }
  }
  if (!(await authorised(req, env))) return json({ error: "unauthorised" }, 401);
  if (pathname.startsWith("/social/")) {
    if (!socialReady(env)) return json({ error: "the social hub is not set up: run npm run setup" }, 503);
    return handleSocial(socialCtx(env), req);
  }
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
  if (pathname === "/run" && req.method === "POST") return json(await runWatches(env));
  if (pathname === "/test-notify" && req.method === "POST") {
    await push(env, { topic: env.NTFY_TOPIC, title: "Brahma Watch", message: "Test alert: your phone is set up.", tags: ["white_check_mark"] });
    return json({ sent: true });
  }
  return json({ error: "not found" }, 404);
}

async function step(name: string, run: () => Promise<unknown>) {
  try {
    await run();
  } catch (err) {
    console.log(`${name}: ${err instanceof Error ? (err.stack ?? err.message) : err}`);
  }
}

/**
 * The cron fires every minute. Publishing runs every time; property watches,
 * the inbox and discovery every 10 minutes (each social pass goes through
 * every profile on the one budget); account checks daily at 03:05 UTC
 * (its own run, so it gets a whole subrequest budget).
 */
export async function runCron(env: Env, now: Date) {
  const minute = now.getUTCMinutes();
  const daySlot = now.getUTCHours() === 3 && minute === 5;
  const ctx = socialCtx(env, now);
  if (socialReady(env)) await step("publish", () => eachProfile(ctx, "publish", publishDue));
  if (minute % 10 === 0) {
    // Property watches fetch outside the budget; set aside what they use.
    const watches = (await loadWatches(env)).filter((w) => !w.paused).length;
    ctx.budget.take(Math.min(ctx.budget.left, watches * 3));
    await step("property watches", () => runWatches(env, now.toISOString()));
    if (socialReady(env)) {
      await step("inbox", () => eachProfile(ctx, "inbox", (c) => pollAll(c)));
      await step("discovery", () => eachProfile(ctx, "discovery", runDue));
    }
  }
  if (daySlot && socialReady(env)) await step("daily", () => daily(ctx));
}

export default {
  fetch: (req: Request, env: Env, ctx: ExecutionContext) => handle(req, env, (p) => ctx.waitUntil(p)),
  scheduled: async (controller: ScheduledController, env: Env, ctx: ExecutionContext) => {
    ctx.waitUntil(runCron(env, new Date(controller.scheduledTime)));
  },
} satisfies ExportedHandler<Env>;
