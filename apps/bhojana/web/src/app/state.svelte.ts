// The running app: local database, account, sync schedule and what the pages
// show. One instance per tab; tabs tell each other about changes so they stay
// in step, and only one of them syncs at a time.
import { AccountService, IdbKeyStore, MemoryKeyStore, type KeyStore } from "../lib/account.ts";
import { SignInAgain } from "../lib/api.ts";
import { ShoppingBook, type Snapshot } from "../lib/book.ts";
import { Store } from "../lib/store.ts";

export type Route =
  | { page: "list" }
  | { page: "compare"; itemId: string }
  | { page: "shops" }
  | { page: "settings" };

export function parseHash(hash: string): Route {
  const m = /^#\/(\w+)(?:\/(.+))?$/.exec(hash);
  if (m?.[1] === "compare" && m[2]) return { page: "compare", itemId: decodeURIComponent(m[2]) };
  if (m?.[1] === "shops") return { page: "shops" };
  if (m?.[1] === "settings") return { page: "settings" };
  return { page: "list" };
}

export const href = (r: Route) => (r.page === "compare" ? `#/compare/${encodeURIComponent(r.itemId)}` : `#/${r.page}`);

export const errorText = (e: unknown) => (e instanceof Error ? e.message : String(e));

/// A short name for this browser, shown to the other device when pairing.
export function deviceName(ua = navigator.userAgent): string {
  const browser = /Edg\//.test(ua) ? "Edge" : /Firefox\//.test(ua) ? "Firefox" : /Chrome\//.test(ua) ? "Chrome"
    : /Safari\//.test(ua) ? "Safari" : "Web browser";
  const os = /Android/.test(ua) ? "Android" : /iPhone|iPad/.test(ua) ? "iOS" : /Windows/.test(ua) ? "Windows"
    : /Mac OS/.test(ua) ? "macOS" : /Linux|CrOS/.test(ua) ? "Linux" : "";
  return os ? `${browser} on ${os}` : browser;
}

const SYNC_EVERY = 15 * 60_000;
const SYNC_AFTER_WRITE = 1500;
const SYNC_ON_FOCUS_AFTER = 30_000;

const empty: Snapshot = { lists: [], items: [], prices: [], prefs: new Map() };

export interface SyncStatus {
  busy: boolean;
  error: string;
  /// The server no longer takes the stored login (password changed elsewhere).
  signInAgain: boolean;
  last: number;
  pending: number;
}

class AppState {
  phase = $state<"loading" | "onboarding" | "ready" | "failed">("loading");
  failure = $state("");
  snap = $state.raw<Snapshot>(empty);
  route = $state.raw<Route>(parseHash(location.hash));
  listId = $state<string | null>(null);
  remember = $state(true);
  email = $state("");
  sync = $state<SyncStatus>({ busy: false, error: "", signInAgain: false, last: 0, pending: 0 });
  /// Read out by the polite live region in App.svelte.
  notice = $state("");

  store!: Store;
  account!: AccountService;
  book!: ShoppingBook;
  private channel: BroadcastChannel | null = null;
  private timer: ReturnType<typeof setTimeout> | null = null;
  private again = false;

  async start() {
    try {
      this.store = await Store.open();
      this.remember = (await this.store.setting("keys.remember")) !== "0";
      this.account = new AccountService(this.store, this.keyStore(this.remember), location.origin, deviceName());
      this.book = new ShoppingBook(this.store);
      this.store.onChange(() => {
        void this.refresh();
        this.channel?.postMessage("changed");
      });
      this.channel = new BroadcastChannel(`bhojana-${this.store.name}`);
      this.channel.onmessage = (m) => {
        if (m.data === "signed-out") location.reload();
        else void this.refresh();
      };
      addEventListener("hashchange", () => (this.route = parseHash(location.hash)));
      const session = await this.account.session();
      if (!session) {
        // A "forget me" session ended when its tab closed: drop what it left.
        if (!this.remember) await this.store.wipe();
        this.phase = "onboarding";
        return;
      }
      await this.enter();
    } catch (e) {
      this.failure = errorText(e);
      this.phase = "failed";
    }
  }

  private keyStore(remember: boolean): KeyStore {
    return remember ? new IdbKeyStore(this.store) : new MemoryKeyStore();
  }

  /// Chosen on the sign-in form, before the keys exist.
  useMemoryKeys(remember: boolean) {
    this.remember = remember;
    this.account.keys = this.keyStore(remember);
  }

  /// Signed in (now or earlier): show the lists and start syncing.
  async enter() {
    // Written after sign-in: signing in as another account resets the device,
    // which clears local settings.
    await this.store.setSetting("keys.remember", this.remember ? "1" : "0");
    this.email = (await this.account.session())?.email ?? "";
    await this.refresh();
    this.phase = "ready";
    if (!this.started) this.schedule();
    void this.syncNow();
  }

  private started = false;

  private schedule() {
    this.started = true;
    setInterval(() => void this.syncNow(), SYNC_EVERY);
    const soon = () => {
      if (document.visibilityState === "visible" && Date.now() - this.sync.last > SYNC_ON_FOCUS_AFTER) void this.syncNow();
    };
    addEventListener("focus", soon);
    document.addEventListener("visibilitychange", soon);
    addEventListener("online", () => void this.syncNow());
  }

  async refresh() {
    this.snap = await this.book.snapshot();
    this.sync.pending = await this.store.pending();
    if (this.listId && !this.snap.lists.some((l) => l.id === this.listId)) this.listId = null;
  }

  /// Runs a local write, then syncs a moment later (several quick edits go out
  /// together).
  async act(write: () => Promise<unknown>, done = ""): Promise<boolean> {
    try {
      await write();
      if (done) this.notice = done;
      if (this.timer) clearTimeout(this.timer);
      this.timer = setTimeout(() => void this.syncNow(), SYNC_AFTER_WRITE);
      return true;
    } catch (e) {
      this.notice = `Could not save: ${errorText(e)}`;
      return false;
    }
  }

  async syncNow(): Promise<void> {
    if (this.phase !== "ready") return;
    if (this.sync.busy) {
      this.again = true;
      return;
    }
    this.sync.busy = true;
    try {
      const run = async () => {
        const engine = await this.account.engine();
        if (engine) await engine.run();
      };
      // Tabs share the database and the device's change numbers: one at a time.
      if (navigator.locks) await navigator.locks.request("bhojana-sync", run);
      else await run();
      this.sync.error = "";
      this.sync.signInAgain = false;
      this.sync.last = Date.now();
    } catch (e) {
      this.sync.error = navigator.onLine ? errorText(e) : "Offline: changes are kept here and sync when you are back online";
      this.sync.signInAgain = e instanceof SignInAgain;
    } finally {
      this.sync.busy = false;
      this.sync.pending = await this.store.pending();
    }
    if (this.again) {
      this.again = false;
      void this.syncNow();
    }
  }

  /// Keeps the keys in IndexedDB, or in this tab's memory only.
  async setRemember(remember: boolean) {
    const session = await this.account.session();
    const next = this.keyStore(remember);
    if (session) await next.save(session);
    if (!remember) await new IdbKeyStore(this.store).clear();
    this.account.keys = next;
    this.remember = remember;
    await this.store.setSetting("keys.remember", remember ? "1" : "0");
  }

  /// Forgets the keys and everything this browser holds; the account and the
  /// other devices keep the data.
  async signOut() {
    await this.account.signOut();
    await this.store.wipe(true);
    this.channel?.postMessage("signed-out");
    location.hash = "";
    location.reload();
  }
}

export const app = new AppState();
