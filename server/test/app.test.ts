import assert from "node:assert/strict";
import { test } from "node:test";
import { handle, newCode, type Env } from "../src/app.ts";
import { memoryD1 } from "../src/sqlite.ts";

const secretA = "a".repeat(43), secretB = "b".repeat(43);
const dev1 = "1".repeat(32), dev2 = "2".repeat(32);

function server() {
  const env: Env = { DB: memoryD1(), TOKEN_KEY: "k", SETUP_CODE: "SETUP-CODE-1234" };
  const call = async (method: string, path: string, body?: unknown, token?: string) => {
    const res = await handle(
      new Request(`https://x.test${path}`, {
        method,
        headers: { ...(token ? { authorization: `Bearer ${token}` } : {}), "content-type": "application/json" },
        body: body === undefined ? undefined : JSON.stringify(body),
      }),
      env,
    );
    const text = await res.text();
    return { status: res.status, body: text ? JSON.parse(text) : null };
  };
  return { env, call };
}

async function owner(s: ReturnType<typeof server>) {
  const r = await s.call("POST", "/api/register", { email: "Me@Example.com", secret: secretA, invite: "setup-code-1234" });
  assert.equal(r.status, 200, JSON.stringify(r.body));
  return r.body.token as string;
}

test("health reports setup needed until the owner exists", async () => {
  const s = server();
  assert.equal((await s.call("GET", "/api/health")).body.needsSetup, true);
  await owner(s);
  assert.equal((await s.call("GET", "/api/health")).body.needsSetup, false);
});

test("owner needs the setup code; later people need an invite, once", async () => {
  const s = server();
  const bad = await s.call("POST", "/api/register", { email: "a@b.co", secret: secretA, invite: "WRONG" });
  assert.equal(bad.status, 403);
  const token = await owner(s);
  const me = await s.call("GET", "/api/me", undefined, token);
  assert.deepEqual([me.body.email, me.body.owner], ["me@example.com", true]);

  const noInvite = await s.call("POST", "/api/register", { email: "b@b.co", secret: secretB, invite: "SETUP-CODE-1234" });
  assert.equal(noInvite.status, 403);

  const { code } = (await s.call("POST", "/api/invites", {}, token)).body;
  const ok = await s.call("POST", "/api/register", { email: "b@b.co", secret: secretB, invite: code });
  assert.equal(ok.status, 200);
  const again = await s.call("POST", "/api/register", { email: "c@b.co", secret: secretB, invite: code });
  assert.equal(again.status, 403);
  const member = await s.call("GET", "/api/me", undefined, ok.body.token);
  assert.equal(member.body.owner, false);
  assert.equal((await s.call("POST", "/api/invites", {}, ok.body.token)).status, 403);
});

test("repeating a sign-up with the same secret signs in; another secret is refused", async () => {
  const s = server();
  await owner(s);
  const same = await s.call("POST", "/api/register", { email: "me@example.com", secret: secretA, invite: "x" });
  assert.equal(same.status, 200);
  const other = await s.call("POST", "/api/register", { email: "me@example.com", secret: secretB, invite: "x" });
  assert.equal(other.status, 409);
});

test("login rejects a wrong secret and unknown e-mail alike", async () => {
  const s = server();
  await owner(s);
  assert.equal((await s.call("POST", "/api/login", { email: "me@example.com", secret: secretA })).status, 200);
  const wrong = await s.call("POST", "/api/login", { email: "me@example.com", secret: secretB });
  const none = await s.call("POST", "/api/login", { email: "no@example.com", secret: secretB });
  assert.equal(wrong.status, 401);
  assert.deepEqual(wrong.body, none.body);
});

test("a tampered or missing token is refused", async () => {
  const s = server();
  const token = await owner(s);
  assert.equal((await s.call("GET", "/api/me")).status, 401);
  assert.equal((await s.call("GET", "/api/me", undefined, token + "x")).status, 401);
});

test("vault: create once, read, rewrap", async () => {
  const s = server();
  const t = await owner(s);
  assert.equal((await s.call("GET", "/api/vault", undefined, t)).status, 404);
  const v = { wrappedPassword: "wp", wrappedRecovery: "wr" };
  assert.equal((await s.call("POST", "/api/vault", v, t)).status, 201);
  assert.equal((await s.call("POST", "/api/vault", v, t)).status, 409);
  await s.call("PUT", "/api/vault", { wrappedPassword: "wp2" }, t);
  assert.deepEqual((await s.call("GET", "/api/vault", undefined, t)).body, {
    wrappedPassword: "wp2",
    wrappedRecovery: "wr",
    version: 1,
  });
});

test("changes are an append-only log per device, private per account", async () => {
  const s = server();
  const t = await owner(s);
  const { code } = (await s.call("POST", "/api/invites", {}, t)).body;
  const other = (await s.call("POST", "/api/register", { email: "b@b.co", secret: secretB, invite: code })).body.token;

  for (const seq of [1, 2, 3]) {
    assert.equal((await s.call("POST", "/api/changes", { device: dev1, seq, payload: `p${seq}` }, t)).status, 201);
  }
  assert.equal((await s.call("POST", "/api/changes", { device: dev1, seq: 2, payload: "evil" }, t)).status, 409);
  assert.equal((await s.call("GET", `/api/changes/last?device=${dev1}`, undefined, t)).body.seq, 3);
  assert.equal((await s.call("GET", `/api/changes/last?device=${dev2}`, undefined, t)).body.seq, 0);
  const page = await s.call("GET", `/api/changes?device=${dev1}&after=1&limit=1`, undefined, t);
  assert.deepEqual(page.body.items, [{ seq: 2, payload: "p2" }]);
  assert.equal((await s.call("GET", `/api/changes/one?device=${dev1}&seq=3`, undefined, t)).body.payload, "p3");

  assert.equal((await s.call("GET", `/api/changes/last?device=${dev1}`, undefined, other)).body.seq, 0);
  assert.deepEqual((await s.call("GET", `/api/changes?device=${dev1}`, undefined, other)).body.items, []);
});

test("devices register once and list", async () => {
  const s = server();
  const t = await owner(s);
  await s.call("POST", "/api/devices", { device: dev1, platform: "linux" }, t);
  await s.call("POST", "/api/devices", { device: dev1, platform: "linux" }, t);
  assert.deepEqual((await s.call("GET", "/api/devices", undefined, t)).body.devices, [dev1]);
  assert.equal((await s.call("POST", "/api/devices", { device: "short" }, t)).status, 400);
});

test("pairing: request once, owner answers once, only after a request", async () => {
  const s = server();
  const t = await owner(s);
  const { id } = (await s.call("POST", "/api/pairings", {}, t)).body;
  assert.match(id, /^[a-z0-9]{15}$/);

  assert.equal((await s.call("PUT", `/api/pairings/${id}/response`, { response: "r" }, t)).status, 409);
  assert.equal((await s.call("PUT", `/api/pairings/${id}/request`, { request: "req" })).status, 200);
  assert.equal((await s.call("PUT", `/api/pairings/${id}/request`, { request: "req2" })).status, 409);
  assert.equal((await s.call("GET", `/api/pairings/${id}`)).body.request, "req");

  assert.equal((await s.call("PUT", `/api/pairings/${id}/response`, { response: "grant" }, t)).status, 200);
  assert.equal((await s.call("PUT", `/api/pairings/${id}/response`, { response: "again" }, t)).status, 409);
  assert.equal((await s.call("GET", `/api/pairings/${id}`)).body.response, "grant");

  assert.equal((await s.call("DELETE", `/api/pairings/${id}`, undefined, t)).status, 204);
  assert.equal((await s.call("GET", `/api/pairings/${id}`)).status, 404);
});

test("pairing: another account cannot answer, an expired one is gone", async () => {
  const s = server();
  const t = await owner(s);
  const { code } = (await s.call("POST", "/api/invites", {}, t)).body;
  const other = (await s.call("POST", "/api/register", { email: "b@b.co", secret: secretB, invite: code })).body.token;
  const { id } = (await s.call("POST", "/api/pairings", {}, t)).body;
  await s.call("PUT", `/api/pairings/${id}/request`, { request: "req" });
  assert.equal((await s.call("PUT", `/api/pairings/${id}/response`, { response: "x" }, other)).status, 404);

  await s.env.DB.prepare("UPDATE pairings SET expires = 1").run();
  assert.equal((await s.call("GET", `/api/pairings/${id}`)).status, 404);
  assert.equal((await s.call("PUT", `/api/pairings/${id}/request`, { request: "late" })).status, 404);
});

test("changing the password signs out old tokens and keeps the new one", async () => {
  const s = server();
  const t = await owner(s);
  const bad = await s.call("POST", "/api/password", { oldSecret: secretB, newSecret: "c".repeat(43) }, t);
  assert.equal(bad.status, 400);
  const ok = await s.call("POST", "/api/password", { oldSecret: secretA, newSecret: "c".repeat(43) }, t);
  assert.equal(ok.status, 200);
  assert.equal((await s.call("GET", "/api/me", undefined, t)).status, 401);
  assert.equal((await s.call("GET", "/api/me", undefined, ok.body.token)).status, 200);
});

test("owner reset code sets a new secret once", async () => {
  const s = server();
  const t = await owner(s);
  const { code } = (await s.call("POST", "/api/invites", {}, t)).body;
  await s.call("POST", "/api/register", { email: "b@b.co", secret: secretB, invite: code });
  const reset = (await s.call("POST", "/api/members/reset", { email: "b@b.co" }, t)).body.code;

  const wrongUser = await s.call("POST", "/api/reset", { email: "me@example.com", code: reset, secret: "d".repeat(43) });
  assert.equal(wrongUser.status, 403);
  const ok = await s.call("POST", "/api/reset", { email: "b@b.co", code: reset, secret: "d".repeat(43) });
  assert.equal(ok.status, 200);
  assert.equal((await s.call("POST", "/api/login", { email: "b@b.co", secret: "d".repeat(43) })).status, 200);
  assert.equal((await s.call("POST", "/api/reset", { email: "b@b.co", code: reset, secret: secretA })).status, 403);
});

test("codes look like XXXX-XXXX-XXXX without confusable letters", () => {
  for (let i = 0; i < 50; i++) assert.match(newCode(), /^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$/);
  assert.doesNotMatch(newCode(), /[ILOU01]/);
});

test("register is rate limited per address", async () => {
  const s = server();
  let last = 0;
  for (let i = 0; i < 12; i++) {
    last = (await s.call("POST", "/api/register", { email: `x${i}@b.co`, secret: secretA, invite: "no" })).status;
  }
  assert.equal(last, 429);
});

test("sign-in is limited per account as well as per address", async () => {
  const s = server();
  await owner(s);
  let last = 0;
  for (let i = 0; i < 12; i++) {
    const res = await handle(
      new Request("https://x.test/api/login", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email: "me@example.com", secret: secretB }),
      }),
      s.env,
      `2001:db8::${i}`,
    );
    last = res.status;
  }
  assert.equal(last, 429);
});

test("a page of changes stops before it grows too large, but always moves on", async () => {
  const s = server();
  const token = await owner(s);
  const big = "x".repeat(1_800_000);
  for (let seq = 1; seq <= 6; seq++) {
    assert.equal((await s.call("POST", "/api/changes", { device: dev1, seq, payload: big }, token)).status, 201);
  }
  const page = await s.call("GET", `/api/changes?device=${dev1}&after=0&limit=200`, undefined, token);
  assert.equal(page.body.items.length, 4);
  const rest = await s.call("GET", `/api/changes?device=${dev1}&after=4&limit=200`, undefined, token);
  assert.equal(rest.body.items.length, 2);
  assert.equal((await s.call("POST", "/api/changes", { device: dev1, seq: 7, payload: "y".repeat(1_950_000) }, token)).status, 400);
});
