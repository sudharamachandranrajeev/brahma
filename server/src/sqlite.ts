// A D1 look-alike over node:sqlite, so the same handler runs on a home
// server (a database file) and under `node --test` (in memory).
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";

class Statement {
  db: DatabaseSync;
  sql: string;
  args: unknown[];
  constructor(db: DatabaseSync, sql: string, args: unknown[] = []) {
    this.db = db;
    this.sql = sql;
    this.args = args;
  }
  bind(...args: unknown[]) {
    return new Statement(this.db, this.sql, args);
  }
  async first<T>(): Promise<T | null> {
    return (this.db.prepare(this.sql).get(...(this.args as never[])) as T | undefined) ?? null;
  }
  async all() {
    return { results: this.db.prepare(this.sql).all(...(this.args as never[])) };
  }
  async run() {
    this.db.prepare(this.sql).run(...(this.args as never[]));
    return { success: true };
  }
}

/// Opens (or creates) the database at [path] and applies the schema, which
/// only creates what is missing. ":memory:" gives a throwaway one.
export function openDatabase(path = ":memory:"): DatabaseSync {
  const db = new DatabaseSync(path);
  if (path !== ":memory:") {
    // WAL lets a backup read while the server writes; FULL keeps every
    // acknowledged change through a power cut.
    db.exec("PRAGMA journal_mode = WAL; PRAGMA synchronous = FULL; PRAGMA busy_timeout = 5000;");
  }
  db.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  return db;
}

export const asD1 = (db: DatabaseSync) =>
  ({ prepare: (sql: string) => new Statement(db, sql) }) as unknown as D1Database;

export const memoryD1 = () => asD1(openDatabase());
