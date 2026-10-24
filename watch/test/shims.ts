// In-memory stand-ins for the Worker bindings: D1 on node:sqlite, KV and R2
// on Maps, and a scripted fetch. Enough of each API for the hub's code paths.

import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import type { SocialEnv } from "../src/social/store.ts";

class Statement {
  private db: DatabaseSync;
  private sql: string;
  private args: unknown[];
  constructor(db: DatabaseSync, sql: string, args: unknown[] = []) {
    this.db = db;
    this.sql = sql;
    this.args = args;
  }
  bind(...args: unknown[]) {
    return new Statement(this.db, this.sql, args);
  }
  private prepared() {
    return this.db.prepare(this.sql);
  }
  async first<T>(): Promise<T | null> {
    return (this.prepared().get(...(this.args as never[])) as T) ?? null;
  }
  async all<T>(): Promise<{ results: T[] }> {
    return { results: this.prepared().all(...(this.args as never[])) as T[] };
  }
  async run() {
    const r = this.prepared().run(...(this.args as never[]));
    return { meta: { changes: Number(r.changes) } };
  }
}

export function d1(): D1Database {
  const db = new DatabaseSync(":memory:");
  db.exec(readFileSync(new URL("../migrations/0001_social.sql", import.meta.url), "utf8"));
  return {
    prepare: (sql: string) => new Statement(db, sql),
    batch: async (stmts: Statement[]) => {
      db.exec("BEGIN");
      try {
        const out = [];
        for (const s of stmts) out.push(await s.run());
        db.exec("COMMIT");
        return out;
      } catch (err) {
        db.exec("ROLLBACK");
        throw err;
      }
    },
  } as unknown as D1Database;
}

export function kv(): KVNamespace & { data: Map<string, string> } {
  const data = new Map<string, string>();
  return {
    data,
    get: async (key: string, type?: string | { type: string }) => {
      const v = data.get(key);
      if (v === undefined) return null;
      return (typeof type === "string" ? type : type?.type) === "json" ? JSON.parse(v) : v;
    },
    put: async (key: string, value: string) => void data.set(key, value),
    delete: async (key: string) => void data.delete(key),
  } as unknown as KVNamespace & { data: Map<string, string> };
}

export function r2(): R2Bucket {
  const objects = new Map<string, { body: Uint8Array; contentType?: string }>();
  return {
    get: async (key: string) => {
      const o = objects.get(key);
      if (!o) return null;
      return {
        body: new Response(o.body as Uint8Array<ArrayBuffer>).body,
        size: o.body.byteLength,
        httpEtag: '"etag"',
        writeHttpMetadata: (h: Headers) => o.contentType && h.set("content-type", o.contentType),
      };
    },
    put: async (key: string, body: string | Uint8Array, opts?: { httpMetadata?: { contentType?: string } }) =>
      void objects.set(key, { body: typeof body === "string" ? new TextEncoder().encode(body) : body, contentType: opts?.httpMetadata?.contentType }),
    delete: async (key: string) => void objects.delete(key),
  } as unknown as R2Bucket;
}

export const tokenKey = Buffer.alloc(32, 7).toString("base64");

export function testEnv(): SocialEnv & { KV: ReturnType<typeof kv> } {
  return {
    KV: kv(),
    DB: d1(),
    MEDIA: r2(),
    TOKEN_KEY: tokenKey,
    PUBLIC_URL: "https://hub.test",
    API_TOKEN: "test-token",
    NTFY_TOPIC: "topic",
  };
}

export interface Sent {
  url: string;
  method: string;
  body: string | null;
}

/**
 * Replaces global fetch. [routes] maps a URL prefix to a responder; ntfy
 * pushes are accepted and recorded. Unknown URLs fail the test loudly.
 */
export function mockFetch(routes: Record<string, (url: URL, init: RequestInit) => unknown | Response | Promise<unknown>>) {
  const sent: Sent[] = [];
  const pushes: any[] = [];
  const original = globalThis.fetch;
  globalThis.fetch = (async (input: string | URL | Request, init: RequestInit = {}) => {
    const url = new URL(input instanceof Request ? input.url : input.toString());
    const body = typeof init.body === "string" ? init.body : null;
    sent.push({ url: url.toString(), method: init.method ?? "GET", body });
    if (url.hostname === "ntfy.sh") {
      pushes.push(body ? JSON.parse(body) : null);
      return Response.json({ id: "x" });
    }
    const key = Object.keys(routes).find((k) => url.toString().startsWith(k));
    if (!key) throw new Error(`unexpected fetch ${url}`);
    const out = await routes[key](url, init);
    return out instanceof Response ? out : Response.json(out);
  }) as typeof fetch;
  return { sent, pushes, restore: () => void (globalThis.fetch = original) };
}
