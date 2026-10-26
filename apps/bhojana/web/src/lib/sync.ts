// Moves encrypted changes between this browser and the server, exactly as
// brahma_core's SyncEngine (core/lib/src/sync/sync_engine.dart).
//
// Push: outbox rows go out in numbered batches, strictly in order; a batch is
// only removed from the outbox after the server holds it. Pull: each other
// device's batches are applied in order, the newest write (by HLC) winning
// per row; the cursor moves in the same transaction.
import { open, seal, VERSION } from "./crypto.ts";
import { mergeRow, RowError, SYNCED_TABLES, type Row, type Table } from "./schema.ts";
import { req, type OutboxItem, type Store } from "./store.ts";

export class SyncError extends Error {}

export interface RemoteChange {
  seq: number;
  payload: string;
}

/// The server side of sync, reduced to an append-only log per device.
export interface SyncRemote {
  /// Stores change [seq] of [device]. False when that slot already exists.
  push(device: string, seq: number, payload: string): Promise<boolean>;
  /// The stored payload of one change, or null.
  fetch(device: string, seq: number): Promise<string | null>;
  /// Highest stored seq of [device] (0 if none).
  lastSeq(device: string): Promise<number>;
  /// Every device of this account that has pushed anything.
  devices(): Promise<string[]>;
  /// Changes of [device] after [afterSeq], oldest first.
  pull(device: string, afterSeq: number, limit?: number): Promise<RemoteChange[]>;
}

export interface SyncResult {
  pushed: number;
  pulled: number;
}

interface WireRow {
  t: string;
  r: Row;
}

const BATCH_SIZE = 200;
const ASSIGNED = "sync.seq";
const SENT = "sync.sent";
const HLC = /^\d{15}-\d{6}-[A-Za-z0-9]+$/;
const isSynced = (t: unknown): t is Table => (SYNCED_TABLES as readonly unknown[]).includes(t);

const getSetting = async (t: IDBTransaction, key: string) =>
  Number(((await req(t.objectStore("local_settings").get(key))) as { value: string } | undefined)?.value ?? "0");
const putSetting = (t: IDBTransaction, key: string, value: number) =>
  req(t.objectStore("local_settings").put({ key, value: String(value) }));

export class SyncEngine {
  readonly store: Store;
  readonly remote: SyncRemote;
  readonly dataKey: Uint8Array;
  readonly owner: string;

  constructor(store: Store, remote: SyncRemote, dataKey: Uint8Array, owner: string) {
    this.store = store;
    this.remote = remote;
    this.dataKey = dataKey;
    this.owner = owner;
  }

  private aad(device: string, seq: number) {
    return `${VERSION}|${this.owner}|${device}|${seq}`;
  }

  async run(): Promise<SyncResult> {
    const pushed = await this.push();
    return { pushed, pulled: await this.pull() };
  }

  async push(): Promise<number> {
    const me = this.store.deviceId;
    // A restored copy may hold an older counter than the server: never reuse a slot.
    const serverLast = await this.remote.lastSeq(me);
    await this.store.tx(["outbox", "local_settings"], "readwrite", async (t) => {
      if (serverLast <= (await getSetting(t, ASSIGNED))) return;
      const sent = await getSetting(t, SENT);
      await this.updateOutbox(t, (o) => (o.seq !== null && o.seq > sent ? null : o.seq));
      await putSetting(t, ASSIGNED, serverLast);
      await putSetting(t, SENT, serverLast);
    });
    let pushed = 0;
    for (;;) {
      const seq = await this.nextBatch();
      if (seq === null) return pushed;
      const rows = await this.collect(seq);
      const payload = await seal({ v: 1, rows }, this.dataKey, this.aad(me, seq));
      if (!(await this.remote.push(me, seq, payload)) && !(await this.sameAsServer(seq, rows))) {
        // The slot holds something else (e.g. from a since-restored copy of
        // this device): move the batch to a fresh number and try again.
        await this.store.tx(["outbox", "local_settings"], "readwrite", async (t) => {
          const fresh = (await getSetting(t, ASSIGNED)) + 1;
          await this.updateOutbox(t, (o) => (o.seq === seq ? fresh : o.seq));
          await putSetting(t, ASSIGNED, fresh);
          await putSetting(t, SENT, seq);
        });
        continue;
      }
      await this.store.tx(["outbox", "local_settings"], "readwrite", async (t) => {
        const box = t.objectStore("outbox");
        for (const o of (await req(box.getAll())) as OutboxItem[]) {
          if (o.seq === seq) await req(box.delete([o.entity, o.row_id]));
        }
        await putSetting(t, SENT, seq);
      });
      pushed += rows.length;
    }
  }

  private async updateOutbox(t: IDBTransaction, next: (o: OutboxItem) => number | null) {
    const box = t.objectStore("outbox");
    for (const o of (await req(box.getAll())) as OutboxItem[]) {
      const seq = next(o);
      if (seq !== o.seq) await req(box.put({ ...o, seq }));
    }
  }

  /// The batch to send next: an unconfirmed one first, else a new one.
  private nextBatch(): Promise<number | null> {
    return this.store.tx(["outbox", "local_settings"], "readwrite", async (t) => {
      const assigned = await getSetting(t, ASSIGNED), sent = await getSetting(t, SENT);
      if (sent < assigned) return sent + 1;
      const waiting = ((await req(t.objectStore("outbox").getAll())) as OutboxItem[]).filter((o) => o.seq === null);
      if (waiting.length === 0) return null;
      const seq = assigned + 1;
      for (const o of waiting.slice(0, BATCH_SIZE)) await req(t.objectStore("outbox").put({ ...o, seq }));
      await putSetting(t, ASSIGNED, seq);
      return seq;
    });
  }

  private collect(seq: number): Promise<WireRow[]> {
    return this.store.tx(["outbox", ...SYNCED_TABLES], "readonly", async (t) => {
      const items = ((await req(t.objectStore("outbox").getAll())) as OutboxItem[]).filter((o) => o.seq === seq);
      const rows: WireRow[] = [];
      for (const it of items) {
        if (!isSynced(it.entity)) continue;
        const row = (await req(t.objectStore(it.entity).get(it.row_id))) as Row | undefined;
        if (row) rows.push({ t: it.entity, r: row });
      }
      return rows;
    });
  }

  /// Whether the server's copy of [seq] already carries these row versions.
  private async sameAsServer(seq: number, rows: WireRow[]): Promise<boolean> {
    const me = this.store.deviceId;
    const stored = await this.remote.fetch(me, seq);
    if (stored === null) return false;
    try {
      const data = (await open(stored, this.dataKey, this.aad(me, seq))) as { rows: WireRow[] };
      const key = (r: WireRow) => `${r.t}/${r.r.id}/${r.r.hlc}`;
      const theirs = new Set(data.rows.map(key));
      return rows.every((r) => theirs.has(key(r)));
    } catch {
      return false;
    }
  }

  async pull(): Promise<number> {
    let applied = 0;
    for (const device of await this.remote.devices()) {
      if (device === this.store.deviceId) continue;
      let cursor = await this.cursor(device);
      stream: for (;;) {
        const batch = await this.remote.pull(device, cursor);
        if (batch.length === 0) break;
        for (const change of batch) {
          // Batches are pushed strictly in order, so a gap means the server
          // is still catching up (or holding something back): stop here.
          if (change.seq !== cursor + 1) break stream;
          const data = await open(change.payload, this.dataKey, this.aad(device, change.seq));
          const rows = data && typeof data === "object" && Array.isArray((data as { rows?: unknown }).rows)
            ? ((data as { rows: unknown[] }).rows)
            : null;
          if (!rows) throw new SyncError("A change from another device is malformed");
          await this.store.tx([...SYNCED_TABLES, "sync_cursors"], "readwrite", async (t) => {
            for (const r of rows) await this.apply(t, r);
            await req(t.objectStore("sync_cursors").put({ device_id: device, seq: change.seq }));
          });
          cursor = change.seq;
          applied += rows.length;
        }
      }
    }
    if (applied > 0) this.store.changed();
    return applied;
  }

  private async cursor(device: string): Promise<number> {
    const r = await this.store.tx(["sync_cursors"], "readonly", (t) => req(t.objectStore("sync_cursors").get(device)));
    return (r as { seq: number } | undefined)?.seq ?? 0;
  }

  /// Writes one remote row if it is newer than the local copy. Columns this
  /// version does not know are ignored, so newer app versions can add some.
  private async apply(t: IDBTransaction, change: unknown): Promise<void> {
    const c = change as { t?: unknown; r?: unknown } | null;
    if (!c || typeof c !== "object" || typeof c.t !== "string" || !c.r || typeof c.r !== "object" || Array.isArray(c.r)) {
      throw new SyncError("A change from another device is malformed");
    }
    // Another Brahma app's table: not ours to keep.
    if (!isSynced(c.t)) return;
    const row = c.r as Record<string, unknown>;
    const { id, hlc } = row;
    if (typeof id !== "string" || typeof hlc !== "string" || !HLC.test(hlc)) {
      throw new SyncError("A change from another device is malformed");
    }
    const s = t.objectStore(c.t);
    const local = (await req(s.get(id))) as Row | undefined;
    this.store.clock.receive(hlc);
    if (local && String(local.hlc) >= hlc) return;
    try {
      await req(s.put(mergeRow(c.t, local, row)));
    } catch (e) {
      throw e instanceof RowError ? new SyncError(e.message) : e;
    }
  }
}
