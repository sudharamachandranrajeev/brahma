import assert from "node:assert/strict";
import { test } from "node:test";
import { handle, type Env } from "../src/app.ts";
import { memoryD1 } from "../src/sqlite.ts";
import { forgetThreats, KEV_URL, threats, trimKev } from "../src/threats.ts";

const kev = {
  vulnerabilities: [
    {
      cveID: "CVE-2026-0002",
      vendorProject: "Microsoft",
      product: "Win32k",
      vulnerabilityName: "Microsoft Win32k Privilege Escalation",
      dateAdded: "2026-10-20",
      knownRansomwareCampaignUse: "Known",
      shortDescription: "dropped",
    },
    { cveID: "CVE-2025-0001", vendorProject: "Linux", product: "Kernel", dateAdded: "2025-01-02" },
    { cveID: "CVE-2026-0001", vendorProject: "Linux", product: "Kernel", dateAdded: "2026-09-01" },
    { cveID: "CVE-2026-0003", vendorProject: "Odd", product: "Date", dateAdded: "soon" },
  ],
};

test("the catalogue is trimmed to recent entries, newest first, in the short form", () => {
  const t = trimKev(kev, new Date("2026-10-26T00:00:00Z"));
  assert.deepEqual(
    t.map((x) => x.cve),
    ["CVE-2026-0002", "CVE-2026-0001"],
  );
  assert.deepEqual(t[0], {
    cve: "CVE-2026-0002",
    vendor: "Microsoft",
    product: "Win32k",
    name: "Microsoft Win32k Privilege Escalation",
    added: "2026-10-20",
    ransomware: true,
  });
  assert.throws(() => trimKev({ nope: 1 }, new Date()));
});

test("the list is fetched once while fresh, and the last one serves when CISA is down", async () => {
  forgetThreats();
  let calls = 0;
  const ok = (async (url: string) => {
    calls++;
    assert.equal(url, KEV_URL);
    return new Response(JSON.stringify(kev));
  }) as unknown as typeof fetch;
  const down = (async () => new Response("", { status: 503 })) as unknown as typeof fetch;
  const t0 = new Date("2026-10-26T00:00:00Z");
  await assert.rejects(threats(t0, down));
  assert.equal((await threats(t0, ok)).threats.length, 2);
  await threats(new Date("2026-10-26T06:00:00Z"), ok);
  assert.equal(calls, 1);
  const later = await threats(new Date("2026-10-27T00:00:00Z"), down);
  assert.equal(later.fetched, t0.toISOString());
  forgetThreats();
});

test("only signed-in devices get the list", async (t) => {
  forgetThreats();
  t.after(forgetThreats);
  t.mock.method(globalThis, "fetch", async () => new Response(JSON.stringify(kev)));
  const env: Env = { DB: memoryD1(), TOKEN_KEY: "k", SETUP_CODE: "SETUP-CODE-1234" };
  const call = (method: string, path: string, body?: unknown, token?: string) =>
    handle(
      new Request(`https://x.test${path}`, {
        method,
        headers: { ...(token ? { authorization: `Bearer ${token}` } : {}), "content-type": "application/json" },
        body: body === undefined ? undefined : JSON.stringify(body),
      }),
      env,
    );
  assert.equal((await call("GET", "/api/threats")).status, 401);
  const reg = await call("POST", "/api/register", { email: "me@example.com", secret: "a".repeat(43), invite: "SETUP-CODE-1234" });
  const { token } = (await reg.json()) as { token: string };
  const res = await call("GET", "/api/threats", undefined, token);
  assert.equal(res.status, 200);
  const list = (await res.json()) as { threats: unknown[] };
  assert.ok(list.threats.length > 0);
});
