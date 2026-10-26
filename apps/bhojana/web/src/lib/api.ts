// The Worker's HTTP API (server/src/app.ts), as brahma_core's WorkerApi.
import { SyncError, type RemoteChange, type SyncRemote } from "./sync.ts";

export interface VaultRecord {
  wrappedPassword: string;
  wrappedRecovery: string;
}

export interface PairingState {
  request: string;
  response: string;
}

/// The pairing record is gone: it expired, was used, or was cancelled.
export class PairingClosed extends SyncError {}

/// The server no longer takes this login (the password changed elsewhere).
export class SignInAgain extends SyncError {}

type Json = Record<string, unknown>;

export class WorkerApi {
  readonly server: string;
  private token: string | null = null;

  /// [server] is an origin such as https://bhojana.example.workers.dev; the
  /// web app passes its own.
  constructor(server: string) {
    this.server = server.replace(/\/+$/, "");
  }

  get signedIn(): boolean {
    const exp = Number(this.token?.split(".")[1]);
    return Number.isFinite(exp) && exp > Date.now() / 1000 + 60;
  }

  private async call(
    method: string,
    path: string,
    opts: { body?: Json; query?: Record<string, string>; auth?: boolean; allow?: number[] } = {},
  ): Promise<Json & { _status: number }> {
    const url = new URL(path, this.server);
    for (const [k, v] of Object.entries(opts.query ?? {})) url.searchParams.set(k, v);
    const headers: Record<string, string> = { "content-type": "application/json" };
    if ((opts.auth ?? true) && this.token) headers.authorization = `Bearer ${this.token}`;
    let res: Response;
    try {
      res = await fetch(url, {
        method,
        headers,
        body: opts.body ? JSON.stringify(opts.body) : undefined,
        signal: AbortSignal.timeout(30_000),
        cache: "no-store",
      });
    } catch {
      throw new SyncError("Sync server unreachable");
    }
    let data: Json = {};
    try {
      const text = await res.text();
      const v = text ? JSON.parse(text) : {};
      if (v && typeof v === "object" && !Array.isArray(v)) data = v as Json;
    } catch {
      // Not ours (a proxy error page): reported below by status.
    }
    if (res.status >= 400 && !(opts.allow ?? []).includes(res.status)) {
      const message = typeof data.message === "string" ? data.message : `Sync server error ${res.status}`;
      throw res.status === 401 ? new SignInAgain(message) : new SyncError(message);
    }
    return { ...data, _status: res.status };
  }

  private async session(p: Promise<Json>): Promise<string> {
    const r = await p;
    this.token = r.token as string;
    return r.userId as string;
  }

  async health(): Promise<{ needsSetup: boolean }> {
    const r = await this.call("GET", "/api/health", { auth: false });
    if (r.service !== "brahma-sync") throw new SyncError("This is not a Bhojana sync server");
    return { needsSetup: r.needsSetup === true };
  }

  register(email: string, secret: string, invite: string) {
    return this.session(this.call("POST", "/api/register", { body: { email, secret, invite }, auth: false }));
  }

  login(email: string, secret: string) {
    return this.session(this.call("POST", "/api/login", { body: { email, secret }, auth: false }));
  }

  async vault(): Promise<VaultRecord | null> {
    const r = await this.call("GET", "/api/vault", { allow: [404] });
    if (r._status === 404) return null;
    return { wrappedPassword: r.wrappedPassword as string, wrappedRecovery: r.wrappedRecovery as string };
  }

  async createVault(v: VaultRecord) {
    await this.call("POST", "/api/vault", { body: { ...v } });
  }

  async rewrapVault(wrappedPassword: string) {
    await this.call("PUT", "/api/vault", { body: { wrappedPassword } });
  }

  async addDevice(device: string, platform: string) {
    await this.call("POST", "/api/devices", { body: { device, platform } });
  }

  async changeSecret(oldSecret: string, newSecret: string) {
    await this.session(this.call("POST", "/api/password", { body: { oldSecret, newSecret } }));
  }

  confirmReset(email: string, code: string, secret: string) {
    return this.session(this.call("POST", "/api/reset", { body: { email, code, secret }, auth: false }));
  }

  async openPairing(): Promise<string> {
    return (await this.call("POST", "/api/pairings")).id as string;
  }

  async pairing(id: string): Promise<PairingState> {
    const r = await this.call("GET", `/api/pairings/${id}`, { auth: false, allow: [404] });
    if (r._status === 404) throw new PairingClosed("");
    return { request: r.request as string, response: r.response as string };
  }

  async writeRequest(id: string, sealed: string) {
    const r = await this.call("PUT", `/api/pairings/${id}/request`, { body: { request: sealed }, auth: false, allow: [404] });
    if (r._status === 404) throw new PairingClosed("");
  }

  async writeResponse(id: string, sealed: string) {
    const r = await this.call("PUT", `/api/pairings/${id}/response`, { body: { response: sealed }, allow: [404] });
    if (r._status === 404) throw new PairingClosed("");
  }

  async closePairing(id: string) {
    await this.call("DELETE", `/api/pairings/${id}`, { allow: [404] });
  }

  async me(): Promise<{ userId: string; email: string; owner: boolean }> {
    const r = await this.call("GET", "/api/me");
    return { userId: r.userId as string, email: r.email as string, owner: r.owner === true };
  }

  async createInvite(): Promise<{ code: string; expires: number }> {
    const r = await this.call("POST", "/api/invites");
    return { code: r.code as string, expires: r.expires as number };
  }

  async createResetCode(email: string): Promise<{ code: string; expires: number }> {
    const r = await this.call("POST", "/api/members/reset", { body: { email: email.trim().toLowerCase() } });
    return { code: r.code as string, expires: r.expires as number };
  }

  async members(): Promise<{ email: string; owner: boolean }[]> {
    return (await this.call("GET", "/api/members")).members as { email: string; owner: boolean }[];
  }

  async deviceIds(): Promise<string[]> {
    return (await this.call("GET", "/api/devices")).devices as string[];
  }

  remote(): SyncRemote {
    return {
      push: async (device, seq, payload) =>
        (await this.call("POST", "/api/changes", { body: { device, seq, payload }, allow: [409] }))._status !== 409,
      fetch: async (device, seq) => {
        const r = await this.call("GET", "/api/changes/one", { query: { device, seq: String(seq) }, allow: [404] });
        return r._status === 404 ? null : (r.payload as string);
      },
      lastSeq: async (device) => (await this.call("GET", "/api/changes/last", { query: { device } })).seq as number,
      devices: () => this.deviceIds(),
      pull: async (device, after, limit = 50) =>
        (
          await this.call("GET", "/api/changes", {
            query: { device, after: String(after), limit: String(limit) },
          })
        ).items as RemoteChange[],
    };
  }
}
