// Mastodon one-click sign-in and the setup wizard's credential checks.
import { test } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.ts";
import { mockFetch, testEnv } from "./shims.ts";

const env = () => ({ ...testEnv(), SUBREQUEST_BUDGET: "45" });
const exec = { waitUntil: () => {}, passThroughOnException: () => {} } as unknown as ExecutionContext;
const call = async (e: ReturnType<typeof env>, path: string, method = "GET", body?: unknown) => {
  const res = await worker.fetch(
    new Request(`https://hub.test${path}`, {
      method,
      headers: { authorization: "Bearer test-token", "content-type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
    }),
    e as never,
    exec,
  );
  return { status: res.status, body: (await res.json()) as any };
};

test("Mastodon: the hub registers itself once per server, then signs in with OAuth", async () => {
  const e = env();
  let registered = 0;
  let traded: URLSearchParams | null = null;
  const net = mockFetch({
    "https://social.example/api/v1/apps": (_u, init) => {
      registered++;
      const b = JSON.parse(String(init.body));
      assert.equal(b.redirect_uris, "https://hub.test/oauth/mastodon/callback");
      assert.equal(b.scopes, "read write");
      return { client_id: "cid", client_secret: "csecret" };
    },
    "https://social.example/oauth/token": (_u, init) => {
      traded = new URLSearchParams(String(init.body));
      return { access_token: "user-token" };
    },
    "https://social.example/api/v1/accounts/verify_credentials": (_u, init) => {
      assert.equal((init.headers as Record<string, string>).authorization, "Bearer user-token");
      return { id: "7", username: "sam", display_name: "Sam", avatar: null };
    },
  });
  try {
    const first = await call(e, "/social/connect/mastodon", "POST", { instance: "social.example" });
    assert.equal(first.status, 200);
    const url = new URL(first.body.url);
    assert.equal(url.origin + url.pathname, "https://social.example/oauth/authorize");
    assert.equal(url.searchParams.get("client_id"), "cid");
    assert.equal(url.searchParams.get("code_challenge_method"), "S256");
    await call(e, "/social/connect/mastodon", "POST", { instance: "https://social.example/" });
    assert.equal(registered, 1, "the app is kept for the next sign-in");
    assert.ok(!(await e.KV.get("social:mastodon-app:social.example"))!.includes("csecret"), "kept sealed");

    const state = url.searchParams.get("state");
    const cb = await worker.fetch(new Request(`https://hub.test/oauth/mastodon/callback?state=${state}&code=abc`), e as never, exec);
    assert.equal(cb.status, 200, await cb.text());
    assert.equal(traded!.get("client_secret"), "csecret");
    assert.ok(traded!.get("code_verifier"));
    const accounts = (await call(e, "/social/accounts")).body;
    assert.equal(accounts[0].handle, "@sam@social.example");
  } finally {
    net.restore();
  }
});

test("Mastodon: plain http servers are refused", async () => {
  const e = env();
  assert.equal((await call(e, "/social/connect/mastodon", "POST", { instance: "http://social.example" })).status, 400);
});

test("credential checks: Meta right and wrong", async () => {
  const e = env();
  const net = mockFetch({
    "https://graph.facebook.com/v24.0/oauth/access_token": (u) =>
      u.searchParams.get("client_secret") === "good"
        ? { access_token: "app|tok" }
        : Response.json({ error: { message: "Error validating client secret.", code: 1 } }, { status: 400 }),
    "https://graph.facebook.com/v24.0/123": () => ({ name: "Sam's Vani", id: "123" }),
  });
  try {
    const ok = await call(e, "/social/credentials/meta/check", "POST", { publicId: "123", secret: "good" });
    assert.equal(ok.status, 200);
    assert.equal(ok.body.detail, "Meta knows this app: Sam's Vani.");
    const bad = await call(e, "/social/credentials/meta/check", "POST", { publicId: "123", secret: "bad" });
    assert.equal(bad.status, 422);
    assert.match(bad.body.error, /did not accept.*validating client secret/);
  } finally {
    net.restore();
  }
});

test("credential checks: Google and LinkedIn tell a wrong client from a made-up code", async () => {
  const e = env();
  const net = mockFetch({
    "https://oauth2.googleapis.com/token": (_u, init) => {
      const b = new URLSearchParams(String(init.body));
      assert.equal(b.get("redirect_uri"), "https://hub.test/oauth/google/callback");
      return b.get("client_secret") === "good"
        ? Response.json({ error: "invalid_grant", error_description: "Malformed auth code." }, { status: 400 })
        : Response.json({ error: "invalid_client", error_description: "Unauthorized" }, { status: 401 });
    },
    "https://www.linkedin.com/oauth/v2/accessToken": () =>
      Response.json({ error: "invalid_request", error_description: "Unable to retrieve access token" }, { status: 400 }),
  });
  try {
    assert.equal((await call(e, "/social/credentials/google/check", "POST", { publicId: "c", secret: "good" })).status, 200);
    assert.equal((await call(e, "/social/credentials/google/check", "POST", { publicId: "c", secret: "bad" })).status, 422);
    // With no secret sent, the stored one is checked.
    await call(e, "/social/credentials/linkedin", "PUT", { publicId: "c", secret: "stored" });
    const li = await call(e, "/social/credentials/linkedin/check", "POST", { publicId: "c" });
    assert.equal(li.body.detail, "LinkedIn accepted the client ID and secret.");
    assert.equal((await call(e, "/social/credentials/anthropic/check", "POST", { publicId: "c", secret: "x" })).status, 400);
  } finally {
    net.restore();
  }
});
