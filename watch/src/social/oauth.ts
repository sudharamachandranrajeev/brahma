// The unauthenticated edges: OAuth returns and Meta/Threads webhooks. Each
// proves itself another way (a one-time state, a signature).

import { metaSignatureOk, pkce, randomToken, sameText, webhookVerifyToken } from "./crypto.ts";
import { InputError } from "./http.ts";
import { pollAll } from "./inbox.ts";
import { platformInfo, providerPlatforms, type Ctx } from "./platforms/adapter.ts";
import { oauthFlows } from "./platforms/index.ts";
import type { SocialEnv } from "./store.ts";
import type { Account, Provider } from "./types.ts";

const stateTtl = 600;

export const redirectUri = (env: SocialEnv, provider: Provider) => `${env.PUBLIC_URL}/oauth/${provider}/callback`;

/** Starts a sign-in: keeps a one-time state (and PKCE verifier) for 10 minutes, returns the URL to open. */
export async function startConnect(ctx: Ctx, provider: Provider): Promise<{ url: string }> {
  const cred = await ctx.store.credential(provider);
  if (!cred?.publicId) throw new InputError(`Add the ${provider} app credentials under Credentials first`, [], 412);
  const flow = oauthFlows[provider];
  const state = randomToken();
  const p = flow.pkce ? await pkce() : null;
  await ctx.env.KV.put(`social:oauth:${state}`, JSON.stringify({ provider, verifier: p?.verifier }), { expirationTtl: stateTtl });
  return { url: flow.authorizeUrl({ clientId: cred.publicId, redirectUri: redirectUri(ctx.env, provider), state, challenge: p?.challenge }) };
}

const esc = (s: string) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

function page(title: string, body: string, status = 200) {
  return new Response(
    `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${esc(title)}</title>` +
      `<style>body{font:16px/1.5 system-ui,sans-serif;background:#0d0d10;color:#eee;display:grid;place-items:center;min-height:100vh;margin:0;padding:16px;box-sizing:border-box}` +
      `main{max-width:420px}h1{font-size:22px}li{margin:4px 0}.muted{color:#999}</style></head>` +
      `<body><main><h1>${esc(title)}</h1>${body}</main></body></html>`,
    { status, headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" } },
  );
}

/** GET /oauth/:provider/callback */
export async function oauthCallback(ctx: Ctx, provider: string, url: URL): Promise<Response> {
  if (!(provider in oauthFlows)) return page("Unknown sign-in", "", 404);
  const state = url.searchParams.get("state") ?? "";
  const kvKey = `social:oauth:${state}`;
  const saved = state ? await ctx.env.KV.get<{ provider: string; verifier?: string }>(kvKey, "json") : null;
  if (!saved || saved.provider !== provider) {
    return page("This sign-in link has expired", `<p>Start again from Vani's Accounts page.</p>`, 400);
  }
  await ctx.env.KV.delete(kvKey);
  const denied = url.searchParams.get("error_description") ?? url.searchParams.get("error");
  const code = url.searchParams.get("code");
  if (denied || !code) return page("Not connected", `<p>${esc(denied ?? "No authorisation code came back.")}</p>`, 400);
  const p = provider as Provider;
  const cred = await ctx.store.credential(p);
  if (!cred?.publicId) return page("Not connected", "<p>The app credentials were removed.</p>", 400);
  try {
    const connected = await oauthFlows[p].exchange(ctx, {
      clientId: cred.publicId,
      clientSecret: cred.secret,
      redirectUri: redirectUri(ctx.env, p),
      code,
      verifier: saved.verifier,
    });
    if (!connected.length) {
      const hint = p === "meta" ? "No Facebook Pages came back. Instagram needs a Business or Creator account linked to a Page you manage." : "No account came back.";
      return page("Nothing to connect", `<p>${esc(hint)}</p>`, 400);
    }
    const accounts: Account[] = [];
    for (const c of connected) accounts.push(await ctx.store.saveAccount(c.account, c.secret));
    const list = accounts.map((a) => `<li>${esc(platformInfo[a.platform].name)}: ${esc(a.name)} <span class="muted">${esc(a.handle)}</span></li>`).join("");
    return page("Connected", `<ul>${list}</ul><p class="muted">You can close this tab and go back to Vani.</p>`);
  } catch (err) {
    console.log(`oauth ${provider}: ${err instanceof Error ? err.message : err}`);
    return page("Not connected", `<p>${esc(err instanceof Error ? err.message : String(err))}</p>`, 502);
  }
}

/**
 * GET|POST /webhooks/meta and /webhooks/threads. A verified event polls the
 * account it names (soon, in the background) so replies show up in seconds.
 */
export async function webhook(ctx: Ctx, which: string, req: Request, waitUntil: (p: Promise<unknown>) => void): Promise<Response> {
  if (which !== "meta" && which !== "threads") return new Response("not found", { status: 404 });
  const url = new URL(req.url);
  if (req.method === "GET") {
    const ok =
      url.searchParams.get("hub.mode") === "subscribe" &&
      sameText(url.searchParams.get("hub.verify_token") ?? "", await webhookVerifyToken(ctx.env.TOKEN_KEY));
    return ok ? new Response(url.searchParams.get("hub.challenge") ?? "") : new Response("forbidden", { status: 403 });
  }
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });
  const body = await req.text();
  const cred = await ctx.store.credential(which);
  if (!cred || !(await metaSignatureOk(cred.secret, body, req.headers.get("x-hub-signature-256")))) {
    return new Response("bad signature", { status: 401 });
  }
  let payload: any = null;
  try {
    payload = JSON.parse(body);
  } catch {
    return new Response("bad json", { status: 400 });
  }
  const platforms = providerPlatforms[which];
  const candidates = (await ctx.store.accounts()).filter((a) => platforms.includes(a.platform) && a.status !== "broken");
  const ids = new Set<string>((payload?.entry ?? []).map((e: any) => String(e?.id)));
  const named = candidates.filter((a) => ids.has(a.remoteId));
  const targets = named.length ? named : candidates;
  // Bursts of events (a busy live) poll each account at most once a minute.
  const due: Account[] = [];
  for (const a of targets) {
    const key = `social:webhook-poll:${a.id}`;
    if (await ctx.env.KV.get(key)) continue;
    await ctx.env.KV.put(key, "1", { expirationTtl: 60 });
    due.push(a);
  }
  if (due.length) waitUntil(pollAll(ctx, due).catch((err) => console.log(`webhook poll: ${err instanceof Error ? err.message : err}`)));
  return new Response("ok");
}
