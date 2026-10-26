// Talks to the Bhojana browser extension (extension/ in the repository) through
// window messages. A web page cannot read shop sites; the extension can, in the
// user's own signed-in browser. See extension/README.md for the protocol.

export interface Offer {
  title: string;
  pence: number;
  unit: string;
  offer: string;
  url: string;
  inStock: boolean;
}

type Reply = { ok: boolean; message?: string; version?: string; offers?: Offer[]; result?: string };

let counter = 0;

function ask(type: string, body: Record<string, unknown>, timeoutMs: number, win: Window = window): Promise<Reply> {
  const id = `${Date.now()}-${++counter}`;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      win.removeEventListener("message", listener);
      reject(new Error("The Bhojana extension did not answer"));
    }, timeoutMs);
    function listener(event: MessageEvent) {
      const m = event.data;
      if (event.source !== win || !m || m.source !== "bhojana-ext" || m.id !== id) return;
      clearTimeout(timer);
      win.removeEventListener("message", listener);
      resolve(m as Reply);
    }
    win.addEventListener("message", listener);
    win.postMessage({ source: "bhojana-web", id, type, ...body }, win.location.origin);
  });
}

/// The extension's version when it is installed and allowed on this server, else null.
export async function extensionVersion(win: Window = window): Promise<string | null> {
  try {
    const r = await ask("hello", {}, 800, win);
    return r.ok ? (r.version ?? "") : null;
  } catch {
    return null;
  }
}

/// Reads a shop's search page in a background tab of the user's browser.
export async function searchWithExtension(url: string, win: Window = window): Promise<Offer[]> {
  const r = await ask("search", { url }, 90_000, win);
  if (!r.ok) throw new Error(r.message ?? "The shop could not be read");
  return r.offers ?? [];
}

/// Opens a shop page in a new tab; with [addFirst] the extension presses its first Add button.
export async function openWithExtension(url: string, addFirst: boolean, win: Window = window): Promise<string> {
  const r = await ask("open", { url, addFirst }, 60_000, win);
  if (!r.ok) throw new Error(r.message ?? "The shop could not be opened");
  return r.result ?? "opened";
}

const words = (s: string) =>
  s
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((w) => w.length > 1 || /\d/.test(w));

/// The share of the query's words the title holds (relevance in lib/domain/reader.dart).
export function relevance(query: string, title: string): number {
  const q = words(query);
  if (!q.length) return 0;
  const t = new Set(words(title));
  return q.filter((w) => t.has(w)).length / q.length;
}

/// Offers worth showing for [query]: best match first, then cheapest (rank in reader.dart).
export function rank(query: string, offers: Offer[]): Offer[] {
  return offers
    .map((o) => [o, relevance(query, o.title)] as const)
    .filter(([, r]) => r >= 0.5)
    .sort((a, b) => b[1] - a[1] || a[0].pence - b[0].pence)
    .map(([o]) => o);
}
