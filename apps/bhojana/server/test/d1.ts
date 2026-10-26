// A D1 look-alike over node:sqlite, so the handler runs under `node --test`
// and in the dev server the Dart tests talk to.
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

export function memoryD1(): D1Database {
  const db = new DatabaseSync(":memory:");
  db.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  return { prepare: (sql: string) => new Statement(db, sql) } as unknown as D1Database;
}
