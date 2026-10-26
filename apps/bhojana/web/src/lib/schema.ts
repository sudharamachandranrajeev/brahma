// Bhojana's synced tables as the native app's SQLite holds them
// (lib/db/tables.dart). Rows travel in that SQL shape: snake_case columns,
// booleans as 0/1, dates as yyyy-MM-dd text and prices in pence, so a row
// pushed from here is exactly what a native device would push.

export type Value = string | number | null;
export type Row = Record<string, Value>;

interface Column {
  type: "text" | "int" | "bool";
  /// Absent: the column is required on insert (NOT NULL without a default).
  def?: Value;
  nullable?: boolean;
}

const synced: Record<string, Column> = {
  id: { type: "text" },
  hlc: { type: "text", def: "" },
  deleted: { type: "bool", def: 0 },
};

export const TABLES: Record<string, Record<string, Column>> = {
  food_lists: { ...synced, name: { type: "text" }, created: { type: "text" } },
  food_items: {
    ...synced,
    list_id: { type: "text" },
    name: { type: "text" },
    qty: { type: "int", def: 1 },
    note: { type: "text", def: "" },
    done: { type: "bool", def: 0 },
    ord: { type: "int", def: 0 },
    added: { type: "text" },
  },
  food_prices: {
    ...synced,
    item_id: { type: "text", def: null, nullable: true },
    query: { type: "text" },
    shop: { type: "text" },
    title: { type: "text" },
    pence: { type: "int" },
    unit_price: { type: "text", def: "" },
    offer: { type: "text", def: "" },
    url: { type: "text", def: "" },
    in_stock: { type: "bool", def: 1 },
    day: { type: "text" },
    source: { type: "text", def: "web" },
  },
  // Shared by every Brahma app on the account; keys are prefixed per app.
  prefs: { ...synced, value: { type: "text" } },
};

/// Tables whose rows sync, by SQL name; every other table in a change batch
/// belongs to another Brahma app and is skipped, as the native apps do.
export const SYNCED_TABLES = ["food_lists", "food_items", "food_prices", "prefs"] as const;
export type Table = (typeof SYNCED_TABLES)[number];

export class RowError extends Error {}

/// [incoming] laid over [base] the way SQLite's upsert does it: only known
/// columns with plain values are written, booleans become 0/1, and a column
/// SQLite would refuse (NOT NULL without a value) fails the whole row.
export function mergeRow(table: Table, base: Row | undefined, incoming: Record<string, unknown>): Row {
  const cols = TABLES[table];
  const out: Row = {};
  if (!base) for (const [k, c] of Object.entries(cols)) if (c.def !== undefined) out[k] = c.def;
  Object.assign(out, base);
  for (const [k, raw] of Object.entries(incoming)) {
    const c = cols[k];
    if (!c || !(raw === null || ["string", "number", "boolean"].includes(typeof raw))) continue;
    out[k] = coerce(c, typeof raw === "boolean" ? (raw ? 1 : 0) : (raw as Value));
  }
  for (const [k, c] of Object.entries(cols)) {
    if (out[k] === undefined || (out[k] === null && !c.nullable)) throw new RowError("A synced row is incomplete");
  }
  return out;
}

function coerce(c: Column, v: Value): Value {
  if (v === null) return null;
  if (c.type === "text") return typeof v === "number" ? String(v) : v;
  // INTEGER affinity: numeric text becomes a number, as SQLite stores it.
  if (typeof v === "string" && /^-?\d+$/.test(v.trim())) return Number(v);
  return v;
}
