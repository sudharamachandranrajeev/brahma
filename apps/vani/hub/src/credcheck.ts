// Checks a developer app's ID and secret with the platform before they are
// saved, so the setup wizard can say "that's right" or what is wrong. No
// account signs in: each check uses what the platform offers an app alone.

import { InputError } from "./http.ts";
import { graphVersion } from "./platforms/meta.ts";

export type CheckedProvider = "meta" | "threads" | "google" | "linkedin" | "ebay";

const wrong = (message: string) => new InputError(message, [], 422);

async function send(label: string, url: string, init: RequestInit = {}): Promise<{ ok: boolean; body: any }> {
  let res: Response;
  try {
    res = await fetch(url, init);
  } catch (err) {
    throw new InputError(`Cannot reach ${label}: ${err instanceof Error ? err.message : err}`, [], 502);
  }
  const text = await res.text();
  let body: any = null;
  try {
    body = JSON.parse(text);
  } catch {
    body = text;
  }
  return { ok: res.ok, body };
}

const said = (body: any): string =>
  String(body?.error?.message ?? body?.error_description ?? (typeof body?.error === "string" ? body.error : "") ?? "").slice(0, 300);

/** A sentence for the wizard when the ID and secret are right; throws (422) when not. */
export async function checkCredential(provider: CheckedProvider, publicId: string, secret: string, redirectUri: string | null): Promise<string> {
  switch (provider) {
    case "meta": {
      // An app access token comes only for a matching ID and secret.
      const q = new URLSearchParams({ client_id: publicId, client_secret: secret, grant_type: "client_credentials" });
      const tok = await send("Meta", `https://graph.facebook.com/${graphVersion}/oauth/access_token?${q}`);
      if (!tok.ok || !tok.body?.access_token) throw wrong(`Meta did not accept the App ID and App secret: ${said(tok.body)}`);
      const app = await send("Meta", `https://graph.facebook.com/${graphVersion}/${encodeURIComponent(publicId)}?fields=name&access_token=${encodeURIComponent(tok.body.access_token)}`);
      return app.ok && app.body?.name ? `Meta knows this app: ${app.body.name}.` : "Meta accepted the App ID and App secret.";
    }
    case "threads": {
      const q = new URLSearchParams({ client_id: publicId, client_secret: secret, grant_type: "client_credentials" });
      const tok = await send("Threads", `https://graph.threads.net/oauth/access_token?${q}`);
      if (!tok.ok || !tok.body?.access_token) throw wrong(`Threads did not accept the app ID and secret: ${said(tok.body)}`);
      return "Threads accepted the app ID and secret.";
    }
    case "google":
    case "linkedin": {
      // Trading a made-up code: a wrong client fails as invalid_client, a
      // right one gets as far as the code (invalid_grant / invalid_request).
      const url = provider === "google" ? "https://oauth2.googleapis.com/token" : "https://www.linkedin.com/oauth/v2/accessToken";
      const name = provider === "google" ? "Google" : "LinkedIn";
      const r = await send(name, url, {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ grant_type: "authorization_code", code: "vani-check", client_id: publicId, client_secret: secret, redirect_uri: redirectUri ?? "" }),
      });
      const error = typeof r.body?.error === "string" ? r.body.error : "";
      if (error === "invalid_client" || error === "unauthorized_client") {
        throw wrong(`${name} did not accept the client ID and secret. Copy both again from the console.`);
      }
      if (error === "redirect_uri_mismatch") throw wrong(`${name} accepted the client but not the redirect URI. Add it exactly as shown.`);
      if (r.ok || error) return `${name} accepted the client ID and secret.`;
      throw wrong(`${name} answered unexpectedly: ${said(r.body)}`);
    }
    case "ebay": {
      const r = await send("eBay", "https://api.ebay.com/identity/v1/oauth2/token", {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded", authorization: `Basic ${btoa(`${publicId}:${secret}`)}` },
        body: new URLSearchParams({ grant_type: "client_credentials", scope: "https://api.ebay.com/oauth/api_scope" }),
      });
      if (!r.ok || !r.body?.access_token) throw wrong(`eBay did not accept the App ID and Cert ID: ${said(r.body)}`);
      return "eBay accepted the App ID and Cert ID.";
    }
  }
}
