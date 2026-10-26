// The browser's local database: IndexedDB with one object store per synced
// table plus the native app's local-only tables (outbox, sync_cursors,
// local_settings), and a `keys` store for the signed-in session.
//
// Like brahma_core's Store, every write of a synced row stamps it with an HLC
// and queues it in the outbox in the same transaction, so a change is never
// saved without being scheduled for sync.
import { HlcClock } from "./hlc.ts";
import { mergeRow, SYNCED_TABLES, type Row, type Table } from "./schema.ts";

const LOCAL = ["outbox", "sync_cursors", "local_settings", "keys"] as const;
export const ALL_STORES = [...SYNCED_TABLES, ...LOCAL] as string[];

export interface OutboxItem {
  entity: string;
  row_id: string;
  seq: number | null;
}

export const req = <T>(r: IDBRequest<T>) =>
  new Promise<T>((resolve, reject) => {
    r.onsuccess = () => resolve(r.result);
    r.onerror = () => reject(r.error);
  });

/// Runs [fn] in one IndexedDB transaction and resolves once it committed.
/// [fn] may only await IndexedDB requests: awaiting anything else (network,
/// crypto) lets the transaction commit early, so that work stays outside.
export async function inTx<T>(
  db: IDBDatabase,
  stores: string[],
  mode: IDBTransactionMode,
  fn: (t: IDBTransaction) => Promise<T>,
): Promise<T> {
  const t = db.transaction(stores, mode);
  const done = new Promise<void>((resolve, reject) => {
    t.oncomplete = () => resolve();
    t.onerror = () => reject(t.error);
    t.onabort = () => reject(t.error ?? new Error("The local database refused a write"));
  });
  done.catch(() => {});
  let out: T;
  try {
    out = await fn(t);
  } catch (e) {
    try {
      t.abort();
    } catch {
      // Already finished.
    }
    throw e;
  }
  await done;
  return out;
}

export function openDatabase(name: string): Promise<IDBDatabase> {
  const r = indexedDB.open(name, 1);
  r.onupgradeneeded = () => {
    const db = r.result;
    for (const t of SYNCED_TABLES) db.createObjectStore(t, { keyPath: "id" });
    db.createObjectStore("outbox", { keyPath: ["entity", "row_id"] });
    db.createObjectStore("sync_cursors", { keyPath: "device_id" });
    db.createObjectStore("local_settings", { keyPath: "key" });
    db.createObjectStore("keys", { keyPath: "key" });
  };
  return req(r);
}

/// New random row id (UUID v4, as the native apps use).
export const newId = () => crypto.randomUUID();

export class Store {
  readonly db: IDBDatabase;
  clock: HlcClock;
  readonly name: string;
  private listeners = new Set<() => void>();

  private constructor(db: IDBDatabase, clock: HlcClock, name: string) {
    this.db = db;
    this.clock = clock;
    this.name = name;
  }

  get deviceId() {
    return this.clock.node;
  }

  static async open(name = "bhojana"): Promise<Store> {
    const db = await openDatabase(name);
    const deviceId = await inTx(db, ["local_settings"], "readwrite", async (t) => {
      const s = t.objectStore("local_settings");
      const had = (await req(s.get("device.id"))) as { value: string } | undefined;
      if (had) return had.value;
      // 32 lowercase hex characters: what the server's device check expects.
      const id = newId().replace(/-/g, "");
      await req(s.put({ key: "device.id", value: id }));
      return id;
    });
    const clock = new HlcClock(deviceId);
    // Never stamp below what this database already holds, even if the wall
    // clock moved backwards since the last run.
    let latest = "";
    for (const t of SYNCED_TABLES) {
      for (const r of await inTx(db, [t], "readonly", (x) => req(x.objectStore(t).getAll()))) {
        if (typeof r.hlc === "string" && r.hlc > latest) latest = r.hlc;
      }
    }
    if (latest) clock.receive(latest);
    return new Store(db, clock, name);
  }

  close() {
    this.db.close();
  }

  /// Called after every local write and every applied sync batch.
  onChange(fn: () => void): () => void {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  }

  changed() {
    for (const fn of this.listeners) fn();
  }

  tx<T>(stores: string[], mode: IDBTransactionMode, fn: (t: IDBTransaction) => Promise<T>) {
    return inTx(this.db, stores, mode, fn);
  }

  async all(table: Table): Promise<Row[]> {
    return this.tx([table], "readonly", (t) => req(t.objectStore(table).getAll()));
  }

  async get(table: Table, id: string): Promise<Row | undefined> {
    return this.tx([table], "readonly", (t) => req(t.objectStore(table).get(id)));
  }

  /// Inserts or updates a row and records the change. Fields left out keep
  /// what the row holds (or the column default for a new row), like a drift
  /// companion; give every field to replace the row whole.
  async save(table: Table, row: Record<string, unknown> & { id: string }): Promise<void> {
    await this.saveMany([[table, row]]);
  }

  /// Several saves in one transaction (a list and its items, a reorder).
  async saveMany(rows: [Table, Record<string, unknown> & { id: string }][]): Promise<void> {
    const tables = [...new Set(rows.map(([t]) => t))];
    await this.tx([...tables, "outbox"], "readwrite", async (t) => {
      for (const [table, row] of rows) {
        const s = t.objectStore(table);
        const merged = mergeRow(table, await req(s.get(row.id)), row);
        merged.hlc = this.clock.tick();
        await req(s.put(merged));
        await req(t.objectStore("outbox").put({ entity: table, row_id: row.id, seq: null } satisfies OutboxItem));
      }
    });
    this.changed();
  }

  /// Tombstones a row: deletions sync like edits.
  async remove(table: Table, id: string): Promise<void> {
    await this.removeMany([[table, id]]);
  }

  async removeMany(rows: [Table, string][]): Promise<void> {
    const tables = [...new Set(rows.map(([t]) => t))];
    await this.tx([...tables, "outbox"], "readwrite", async (t) => {
      for (const [table, id] of rows) {
        const s = t.objectStore(table);
        const had = await req(s.get(id));
        if (!had) continue;
        await req(s.put({ ...had, deleted: 1, hlc: this.clock.tick() }));
        await req(t.objectStore("outbox").put({ entity: table, row_id: id, seq: null } satisfies OutboxItem));
      }
    });
    this.changed();
  }

  async setting(key: string): Promise<string | undefined> {
    const r = await this.tx(["local_settings"], "readonly", (t) => req(t.objectStore("local_settings").get(key)));
    return (r as { value: string } | undefined)?.value;
  }

  async setSetting(key: string, value: string): Promise<void> {
    await this.tx(["local_settings"], "readwrite", (t) => req(t.objectStore("local_settings").put({ key, value })));
  }

  /// How many changes wait to be pushed.
  async pending(): Promise<number> {
    return this.tx(["outbox"], "readonly", (t) => req(t.objectStore("outbox").count()));
  }

  /// Starts over as a new device with nothing in it: for when another account
  /// signs in here, whose change log must not continue this device's numbers.
  async resetDevice(): Promise<void> {
    await this.wipe(true);
    const id = newId().replace(/-/g, "");
    await this.setSetting("device.id", id);
    this.clock = new HlcClock(id);
  }

  /// Empties the synced tables, the outbox and the cursors; keeps the device
  /// id and push counters unless [everything].
  async wipe(everything = false): Promise<void> {
    const stores = [...SYNCED_TABLES, "outbox", "sync_cursors", ...(everything ? ["local_settings", "keys"] : [])];
    await this.tx(stores, "readwrite", async (t) => {
      for (const s of stores) await req(t.objectStore(s).clear());
    });
    this.changed();
  }
}
