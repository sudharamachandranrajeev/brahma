// Vani's hub: a Cloudflare Worker on the user's own account that holds the
// platform tokens, publishes on schedule, collects replies and runs the
// discovery watches while every device is off. Vani deploys and updates it
// (lib/domain/cloudflare.dart); the API is in README.md.
import { handleSocial } from "./api.ts";
import { mediaSignatureOk } from "./crypto.ts";
import { runDue } from "./discovery.ts";
import { Budget } from "./http.ts";
import { pollAll } from "./inbox.ts";
import { serve } from "./media.ts";
import { sendNtfy } from "./notify.ts";
import { oauthCallback, webhook } from "./oauth.ts";
import type { Ctx } from "./platforms/adapter.ts";
import { eachProfile } from "./profiles.ts";
import { publishDue } from "./publish.ts";
import { daily } from "./stats.ts";
import { Store, type SocialEnv } from "./store.ts";
import { hubVersion } from "./version.ts";

export interface Env extends SocialEnv {
  /**
   * Outbound requests one run may make: 50 on the Workers free plan (the
   * default leaves headroom), 1000 on Workers Paid.
   */
  SUBREQUEST_BUDGET?: string;
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

function hubCtx(env: Env, now = new Date()): Ctx {
  return { env, store: new Store(env), budget: new Budget(Number(env.SUBREQUEST_BUDGET) || 45), now };
}

async function handle(req: Request, env: Env, waitUntil: (p: Promise<unknown>) => void): Promise<Response> {
  const { pathname, searchParams } = new URL(req.url);
  // Unauthenticated edges; each checks a state or signature.
  const oauth = pathname.match(/^\/oauth\/([a-z]+)\/callback$/);
  if (oauth && req.method === "GET") return oauthCallback(hubCtx(env), oauth[1], new URL(req.url));
  const hook = pathname.match(/^\/webhooks\/([a-z]+)$/);
  if (hook) return webhook(hubCtx(env), hook[1], req, waitUntil);
  const media = pathname.match(/^\/media\/([\w-]{1,64})$/);
  if (media && (req.method === "GET" || req.method === "HEAD")) {
    if (!(await mediaSignatureOk(env.TOKEN_KEY, media[1], searchParams.get("exp"), searchParams.get("sig")))) {
      return new Response("forbidden", { status: 403 });
    }
    return serve(new Store(env), media[1], req);
  }
  if (!(await authorised(req, env))) return json({ error: "unauthorised" }, 401);
  if (pathname.startsWith("/social/")) return handleSocial(hubCtx(env), req);
  if (pathname === "/version" && req.method === "GET") return json({ version: hubVersion });
  if (pathname === "/test-notify" && req.method === "POST") {
    await sendNtfy(env.NTFY_SERVER ?? "https://ntfy.sh", env.NTFY_TOKEN, {
      topic: env.NTFY_TOPIC,
      title: "Vani",
      message: "Test alert: your phone is set up.",
      tags: ["white_check_mark"],
    });
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
 * The cron fires every minute. Publishing runs every time; the inbox and
 * discovery every 10 minutes (each pass goes through every profile on the
 * one budget); account checks daily at 03:05 UTC (its own run, so it gets a
 * whole subrequest budget).
 */
export async function runCron(env: Env, now: Date) {
  const minute = now.getUTCMinutes();
  const ctx = hubCtx(env, now);
  await step("publish", () => eachProfile(ctx, "publish", publishDue));
  if (minute % 10 === 0) {
    await step("inbox", () => eachProfile(ctx, "inbox", (c) => pollAll(c)));
    await step("discovery", () => eachProfile(ctx, "discovery", runDue));
  }
  if (now.getUTCHours() === 3 && minute === 5) await step("daily", () => daily(ctx));
}

export default {
  fetch: (req: Request, env: Env, ctx: ExecutionContext) => handle(req, env, (p) => ctx.waitUntil(p)),
  scheduled: async (controller: ScheduledController, env: Env, ctx: ExecutionContext) => {
    ctx.waitUntil(runCron(env, new Date(controller.scheduledTime)));
  },
} satisfies ExportedHandler<Env>;
