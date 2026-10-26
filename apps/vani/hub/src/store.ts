import { open, seal } from "./crypto.ts";
import { InputError } from "./http.ts";
import type {
  Account,
  AccountStats,
  Alert,
  Content,
  CredentialProvider,
  CredentialStatus,
  InboxItem,
  Media,
  Post,
  Profile,
  StatPoint,
} from "./types.ts";

export interface SocialEnv {
  KV: KVNamespace;
  DB: D1Database;
  MEDIA: R2Bucket;
  /** 32 random bytes, base64: seals tokens and signs media links. */
  TOKEN_KEY: string;
  /** This Worker's https origin (OAuth redirect URIs, media links). */
  PUBLIC_URL: string;
  API_TOKEN: string;
  NTFY_TOPIC: string;
  NTFY_SERVER?: string;
  NTFY_TOKEN?: string;
}

export const nowIso = () => new Date().toISOString();
export const newId = () => crypto.randomUUID();

const keepAlerts = 500;
const keepInboxDays = 120;

/** Provider credentials as stored: an id that may be shown, and the secret. */
export interface Credential {
  publicId: string | null;
  secret: string;
}

export const defaultProfile = "default";

/**
 * Every read and write of hub data. Rows hold the API's JSON shapes. A Store
 * works inside one profile: accounts, posts, media, inbox, content, alerts and
 * documents are that profile's. Credentials, profiles and the all* methods
 * are hub-wide.
 */
export class Store {
  readonly env: SocialEnv;
  readonly profile: string;
  constructor(env: SocialEnv, profile = defaultProfile) {
    this.env = env;
    this.profile = profile;
  }

  /** The same hub, inside another profile. */
  forProfile(profile: string): Store {
    return profile === this.profile ? this : new Store(this.env, profile);
  }

  private get db() {
    return this.env.DB;
  }

  // ---- profiles ----

  async profiles(): Promise<Profile[]> {
    const { results } = await this.db
      .prepare("SELECT id, name, created_at FROM profiles ORDER BY created_at, id")
      .all<{ id: string; name: string; created_at: string }>();
    return results.map((r) => ({ id: r.id, name: r.name, createdAt: r.created_at }));
  }

  async profileById(id: string): Promise<Profile | null> {
    return (await this.profiles()).find((p) => p.id === id) ?? null;
  }

  async putProfile(p: Profile): Promise<void> {
    await this.db
      .prepare("INSERT INTO profiles (id, name, created_at) VALUES (?, ?, ?) ON CONFLICT(id) DO UPDATE SET name = excluded.name")
      .bind(p.id, p.name, p.createdAt)
      .run();
  }

  /** Removes a profile and everything in it except media files in R2 (the caller deletes those first). */
  async deleteProfile(id: string): Promise<void> {
    const docs = `p:${id}:%`;
    await this.db.batch([
      ...["accounts", "media", "posts", "inbox", "content", "alerts"].map((t) =>
        this.db.prepare(`DELETE FROM ${t} WHERE profile = ?`).bind(id),
      ),
      this.db.prepare("DELETE FROM docs WHERE key LIKE ?").bind(docs),
      this.db.prepare("DELETE FROM profiles WHERE id = ?").bind(id),
    ]);
  }

  // ---- documents ----

  /** Documents of the default profile keep their old, unprefixed keys. */
  private docKey(key: string) {
    return this.profile === defaultProfile ? key : `p:${this.profile}:${key}`;
  }

  async doc<T>(key: string, fallback: T): Promise<T> {
    const row = await this.db.prepare("SELECT value FROM docs WHERE key = ?").bind(this.docKey(key)).first<{ value: string }>();
    return row ? (JSON.parse(row.value) as T) : fallback;
  }

  async putDoc(key: string, value: unknown): Promise<void> {
    await this.db
      .prepare("INSERT INTO docs (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value")
      .bind(this.docKey(key), JSON.stringify(value))
      .run();
  }

  // ---- credentials ----

  async credential(provider: CredentialProvider): Promise<Credential | null> {
    const row = await this.db
      .prepare("SELECT public_id, secret FROM credentials WHERE provider = ?")
      .bind(provider)
      .first<{ public_id: string | null; secret: string }>();
    if (!row) return null;
    return { publicId: row.public_id, secret: await open<string>(this.env.TOKEN_KEY, row.secret) };
  }

  async putCredential(provider: CredentialProvider, publicId: string | null, secret: string): Promise<void> {
    await this.db
      .prepare(
        "INSERT INTO credentials (provider, public_id, secret, updated_at) VALUES (?, ?, ?, ?) " +
          "ON CONFLICT(provider) DO UPDATE SET public_id = excluded.public_id, secret = excluded.secret, updated_at = excluded.updated_at",
      )
      .bind(provider, publicId, await seal(this.env.TOKEN_KEY, secret), nowIso())
      .run();
  }

  async deleteCredential(provider: CredentialProvider): Promise<void> {
    await this.db.prepare("DELETE FROM credentials WHERE provider = ?").bind(provider).run();
  }

  async credentialStatus(providers: CredentialProvider[]): Promise<CredentialStatus[]> {
    const { results } = await this.db
      .prepare("SELECT provider, public_id, updated_at FROM credentials")
      .all<{ provider: string; public_id: string | null; updated_at: string }>();
    return providers.map((p) => {
      const r = results.find((x) => x.provider === p);
      return { provider: p, set: !!r, publicId: r?.public_id ?? null, updatedAt: r?.updated_at ?? null };
    });
  }

  // ---- accounts ----

  async accounts(): Promise<Account[]> {
    const { results } = await this.db
      .prepare("SELECT body FROM accounts WHERE profile = ? ORDER BY rowid")
      .bind(this.profile)
      .all<{ body: string }>();
    return results.map((r) => JSON.parse(r.body));
  }

  /** Every profile's accounts, with the profile each is in. */
  async allAccounts(): Promise<{ profile: string; account: Account }[]> {
    const { results } = await this.db.prepare("SELECT profile, body FROM accounts ORDER BY rowid").all<{ profile: string; body: string }>();
    return results.map((r) => ({ profile: r.profile, account: JSON.parse(r.body) }));
  }

  async account(id: string): Promise<Account | null> {
    const row = await this.db
      .prepare("SELECT body FROM accounts WHERE id = ? AND profile = ?")
      .bind(id, this.profile)
      .first<{ body: string }>();
    return row ? JSON.parse(row.body) : null;
  }

  async secretOf<T>(id: string): Promise<T> {
    const row = await this.db
      .prepare("SELECT secret FROM accounts WHERE id = ? AND profile = ?")
      .bind(id, this.profile)
      .first<{ secret: string }>();
    if (!row) throw new Error(`no account ${id}`);
    return open<T>(this.env.TOKEN_KEY, row.secret);
  }

  /**
   * Adds or updates an account by platform + remote id (reconnecting keeps
   * its id, so posts and inbox rows still point at it). Returns the stored account.
   * An account is in one profile: one connected in another is refused (409).
   */
  async saveAccount(a: Omit<Account, "id"> & { id?: string }, secret: unknown): Promise<Account> {
    const existing = await this.db
      .prepare("SELECT a.id, a.profile, p.name FROM accounts a LEFT JOIN profiles p ON p.id = a.profile WHERE a.platform = ? AND a.remote_id = ?")
      .bind(a.platform, a.remoteId)
      .first<{ id: string; profile: string; name: string | null }>();
    if (existing && existing.profile !== this.profile) {
      throw new InputError(`${a.handle || a.name} is already connected in the profile "${existing.name ?? existing.profile}"`, [], 409);
    }
    const account: Account = { ...a, id: existing?.id ?? a.id ?? newId() };
    await this.db
      .prepare(
        "INSERT INTO accounts (id, platform, remote_id, body, secret, profile) VALUES (?, ?, ?, ?, ?, ?) " +
          "ON CONFLICT(id) DO UPDATE SET body = excluded.body, secret = excluded.secret",
      )
      .bind(account.id, account.platform, account.remoteId, JSON.stringify(account), await seal(this.env.TOKEN_KEY, secret), this.profile)
      .run();
    return account;
  }

  async updateAccount(a: Account, secret?: unknown): Promise<void> {
    if (secret === undefined) {
      await this.db.prepare("UPDATE accounts SET body = ? WHERE id = ? AND profile = ?").bind(JSON.stringify(a), a.id, this.profile).run();
    } else {
      await this.db
        .prepare("UPDATE accounts SET body = ?, secret = ? WHERE id = ? AND profile = ?")
        .bind(JSON.stringify(a), await seal(this.env.TOKEN_KEY, secret), a.id, this.profile)
        .run();
    }
  }

  async deleteAccount(id: string): Promise<void> {
    await this.db.batch([
      this.db.prepare("DELETE FROM accounts WHERE id = ? AND profile = ?").bind(id, this.profile),
      this.db.prepare("DELETE FROM content WHERE account_id = ? AND profile = ?").bind(id, this.profile),
      this.db.prepare("DELETE FROM stats WHERE account_id = ? AND account_id NOT IN (SELECT id FROM accounts)").bind(id),
    ]);
  }

  async pollState<T>(id: string): Promise<{ state: T | null; polledAt: string | null }> {
    const row = await this.db
      .prepare("SELECT poll_state, polled_at FROM accounts WHERE id = ? AND profile = ?")
      .bind(id, this.profile)
      .first<{ poll_state: string | null; polled_at: string | null }>();
    return { state: row?.poll_state ? JSON.parse(row.poll_state) : null, polledAt: row?.polled_at ?? null };
  }

  async setPollState(id: string, state: unknown, at: string): Promise<void> {
    await this.db
      .prepare("UPDATE accounts SET poll_state = ?, polled_at = ? WHERE id = ? AND profile = ?")
      .bind(JSON.stringify(state), at, id, this.profile)
      .run();
  }

  /** Accounts least recently polled first. */
  async accountsByPollAge(): Promise<Account[]> {
    const { results } = await this.db
      .prepare("SELECT body FROM accounts WHERE profile = ? ORDER BY polled_at IS NOT NULL, polled_at")
      .bind(this.profile)
      .all<{ body: string }>();
    return results.map((r) => JSON.parse(r.body));
  }

  // ---- media ----

  async media(id: string): Promise<(Omit<Media, "url"> & { uploadId: string | null }) | null> {
    const row = await this.db
      .prepare("SELECT body, upload_id FROM media WHERE id = ? AND profile = ?")
      .bind(id, this.profile)
      .first<{ body: string; upload_id: string | null }>();
    return row ? { ...JSON.parse(row.body), uploadId: row.upload_id } : null;
  }

  async allMedia(): Promise<Omit<Media, "url">[]> {
    const { results } = await this.db
      .prepare("SELECT body FROM media WHERE upload_id IS NULL AND profile = ? ORDER BY created_at DESC LIMIT 500")
      .bind(this.profile)
      .all<{ body: string }>();
    return results.map((r) => JSON.parse(r.body));
  }

  async putMedia(m: Omit<Media, "url">, uploadId: string | null): Promise<void> {
    await this.db
      .prepare(
        "INSERT INTO media (id, body, upload_id, created_at, profile) VALUES (?, ?, ?, ?, ?) " +
          "ON CONFLICT(id) DO UPDATE SET body = excluded.body, upload_id = excluded.upload_id",
      )
      .bind(m.id, JSON.stringify(m), uploadId, m.createdAt, this.profile)
      .run();
  }

  async deleteMedia(id: string): Promise<void> {
    await this.db.prepare("DELETE FROM media WHERE id = ? AND profile = ?").bind(id, this.profile).run();
  }

  /** Ids of every media file in this profile, finished or not (for deleting the profile). */
  async mediaIds(): Promise<string[]> {
    const { results } = await this.db.prepare("SELECT id FROM media WHERE profile = ?").bind(this.profile).all<{ id: string }>();
    return results.map((r) => r.id);
  }

  // ---- posts ----

  async posts(filter: { from?: string; to?: string; status?: string } = {}): Promise<Post[]> {
    const where = ["profile = ?"];
    const args = [this.profile];
    if (filter.status) {
      where.push("status = ?");
      args.push(filter.status);
    }
    if (filter.from) {
      where.push("COALESCE(scheduled_at, updated_at) >= ?");
      args.push(filter.from);
    }
    if (filter.to) {
      where.push("COALESCE(scheduled_at, updated_at) < ?");
      args.push(filter.to);
    }
    const sql =
      `SELECT body FROM posts WHERE ${where.join(" AND ")}` +
      " ORDER BY COALESCE(scheduled_at, updated_at) DESC LIMIT 1000";
    const { results } = await this.db.prepare(sql).bind(...args).all<{ body: string }>();
    return results.map((r) => JSON.parse(r.body));
  }

  async post(id: string): Promise<Post | null> {
    const row = await this.db
      .prepare("SELECT body FROM posts WHERE id = ? AND profile = ?")
      .bind(id, this.profile)
      .first<{ body: string }>();
    return row ? JSON.parse(row.body) : null;
  }

  async savePost(p: Post): Promise<void> {
    await this.db
      .prepare(
        "INSERT INTO posts (id, body, status, scheduled_at, updated_at, profile) VALUES (?, ?, ?, ?, ?, ?) " +
          "ON CONFLICT(id) DO UPDATE SET body = excluded.body, status = excluded.status, " +
          "scheduled_at = excluded.scheduled_at, updated_at = excluded.updated_at",
      )
      .bind(p.id, JSON.stringify(p), p.status, p.scheduledAt, p.updatedAt, this.profile)
      .run();
  }

  async deletePost(id: string): Promise<void> {
    await this.db.prepare("DELETE FROM posts WHERE id = ? AND profile = ?").bind(id, this.profile).run();
  }

  /** Scheduled posts whose time has come and that no other run holds. */
  async duePosts(now: string, limit = 10): Promise<Post[]> {
    const { results } = await this.db
      .prepare(
        "SELECT body FROM posts WHERE profile = ? AND status = 'scheduled' AND scheduled_at <= ? " +
          "AND (lock_until IS NULL OR lock_until < ?) ORDER BY scheduled_at LIMIT ?",
      )
      .bind(this.profile, now, now, limit)
      .all<{ body: string }>();
    return results.map((r) => JSON.parse(r.body));
  }

  /** Takes a post for publishing; false when another run already has it. */
  async lockPost(id: string, now: string, until: string): Promise<boolean> {
    const r = await this.db
      .prepare("UPDATE posts SET lock_until = ? WHERE id = ? AND (lock_until IS NULL OR lock_until < ?)")
      .bind(until, id, now)
      .run();
    return (r.meta.changes ?? 0) > 0;
  }

  /** Releases a post (null) or holds it back until a time (retry backoff). */
  async setLock(id: string, until: string | null): Promise<void> {
    await this.db.prepare("UPDATE posts SET lock_until = ? WHERE id = ?").bind(until, id).run();
  }

  /** Scheduled times already taken (for queue slots). */
  async scheduledTimes(from: string): Promise<string[]> {
    const { results } = await this.db
      .prepare("SELECT scheduled_at FROM posts WHERE profile = ? AND status = 'scheduled' AND scheduled_at >= ?")
      .bind(this.profile, from)
      .all<{ scheduled_at: string }>();
    return results.map((r) => r.scheduled_at);
  }

  // ---- inbox ----

  /** Stores items not seen before and returns just those. */
  async addInbox(items: InboxItem[]): Promise<InboxItem[]> {
    if (!items.length) return [];
    const known = new Set<string>();
    for (let i = 0; i < items.length; i += 50) {
      const chunk = items.slice(i, i + 50);
      const { results } = await this.db
        .prepare(`SELECT id FROM inbox WHERE id IN (${chunk.map(() => "?").join(",")})`)
        .bind(...chunk.map((x) => x.id))
        .all<{ id: string }>();
      for (const r of results) known.add(r.id);
    }
    const fresh = items.filter((x, i) => !known.has(x.id) && items.findIndex((y) => y.id === x.id) === i);
    for (let i = 0; i < fresh.length; i += 50) {
      await this.db.batch(
        fresh
          .slice(i, i + 50)
          .map((x) =>
            this.db
              .prepare("INSERT INTO inbox (id, account_id, platform, kind, status, at, body, profile) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
              .bind(x.id, x.accountId, x.platform, x.kind, x.status, x.at, JSON.stringify(x), this.profile),
          ),
      );
    }
    return fresh;
  }

  async inboxItem(id: string): Promise<InboxItem | null> {
    const row = await this.db
      .prepare("SELECT body FROM inbox WHERE id = ? AND profile = ?")
      .bind(id, this.profile)
      .first<{ body: string }>();
    return row ? JSON.parse(row.body) : null;
  }

  async saveInboxItem(x: InboxItem): Promise<void> {
    await this.db
      .prepare("UPDATE inbox SET status = ?, body = ? WHERE id = ? AND profile = ?")
      .bind(x.status, JSON.stringify(x), x.id, this.profile)
      .run();
  }

  async inbox(f: {
    status?: string;
    platform?: string;
    kind?: string;
    accountId?: string;
    /** A mood, or "urgent" for high priority. */
    triage?: string;
    before?: string;
    limit?: number;
  }): Promise<InboxItem[]> {
    const where = ["profile = ?"];
    const args: (string | number)[] = [this.profile];
    if (f.status === "open") where.push("status IN ('new', 'read')");
    else if (f.status) (where.push("status = ?"), args.push(f.status));
    if (f.platform) (where.push("platform = ?"), args.push(f.platform));
    if (f.kind) (where.push("kind = ?"), args.push(f.kind));
    if (f.accountId) (where.push("account_id = ?"), args.push(f.accountId));
    if (f.triage === "urgent") where.push("json_extract(body, '$.triage.priority') = 'high'");
    else if (f.triage) (where.push("json_extract(body, '$.triage.mood') = ?"), args.push(f.triage));
    if (f.before) (where.push("at < ?"), args.push(f.before));
    args.push(Math.min(Math.max(f.limit ?? 50, 1), 200));
    const { results } = await this.db
      .prepare(`SELECT body FROM inbox WHERE ${where.join(" AND ")} ORDER BY at DESC LIMIT ?`)
      .bind(...args)
      .all<{ body: string }>();
    return results.map((r) => JSON.parse(r.body));
  }

  async inboxCounts(): Promise<{ new: number; read: number; done: number }> {
    const { results } = await this.db
      .prepare("SELECT status, COUNT(*) AS n FROM inbox WHERE profile = ? GROUP BY status")
      .bind(this.profile)
      .all<{ status: string; n: number }>();
    const n = (s: string) => results.find((r) => r.status === s)?.n ?? 0;
    return { new: n("new"), read: n("read"), done: n("done") };
  }

  /** Items that arrived since [since], counted by Claude's mood ("untriaged" when none) and whether they are still open. */
  async inboxSummary(since: string): Promise<{ total: number; byMood: Record<string, number>; unanswered: number }> {
    const { results } = await this.db
      .prepare(
        "SELECT COALESCE(json_extract(body, '$.triage.mood'), 'untriaged') AS mood, status != 'done' AS open, COUNT(*) AS n " +
          "FROM inbox WHERE profile = ? AND at >= ? GROUP BY 1, 2",
      )
      .bind(this.profile, since)
      .all<{ mood: string; open: number; n: number }>();
    const byMood: Record<string, number> = {};
    let total = 0;
    let unanswered = 0;
    for (const r of results) {
      byMood[r.mood] = (byMood[r.mood] ?? 0) + r.n;
      total += r.n;
      if (r.open) unanswered += r.n;
    }
    return { total, byMood, unanswered };
  }

  async setInboxStatus(ids: string[], status: InboxItem["status"]): Promise<void> {
    for (let i = 0; i < ids.length; i += 50) {
      const chunk = ids.slice(i, i + 50);
      await this.db.batch(
        chunk.map((id) =>
          this.db
            .prepare("UPDATE inbox SET status = ?, body = json_set(body, '$.status', ?) WHERE id = ? AND profile = ?")
            .bind(status, status, id, this.profile),
        ),
      );
    }
  }

  // ---- content ----

  async saveContent(items: Content[]): Promise<void> {
    for (let i = 0; i < items.length; i += 50) {
      await this.db.batch(
        items
          .slice(i, i + 50)
          .map((c) =>
            this.db
              .prepare(
                "INSERT INTO content (id, account_id, at, body, profile) VALUES (?, ?, ?, ?, ?) " +
                  "ON CONFLICT(id) DO UPDATE SET body = excluded.body, at = excluded.at",
              )
              .bind(c.id, c.accountId, c.at, JSON.stringify(c), this.profile),
          ),
      );
    }
  }

  async content(accountId?: string, limit = 50): Promise<Content[]> {
    const stmt = accountId
      ? this.db
          .prepare("SELECT body FROM content WHERE profile = ? AND account_id = ? ORDER BY at DESC LIMIT ?")
          .bind(this.profile, accountId, limit)
      : this.db.prepare("SELECT body FROM content WHERE profile = ? ORDER BY at DESC LIMIT ?").bind(this.profile, limit);
    const { results } = await stmt.all<{ body: string }>();
    return results.map((r) => JSON.parse(r.body));
  }

  async contentById(id: string): Promise<Content | null> {
    const row = await this.db
      .prepare("SELECT body FROM content WHERE id = ? AND profile = ?")
      .bind(id, this.profile)
      .first<{ body: string }>();
    return row ? JSON.parse(row.body) : null;
  }

  // ---- alerts ----

  async addAlerts(alerts: Alert[]): Promise<void> {
    if (!alerts.length) return;
    await this.db.batch(
      alerts.map((a) =>
        this.db
          .prepare("INSERT OR IGNORE INTO alerts (id, at, read, body, profile) VALUES (?, ?, 0, ?, ?)")
          .bind(a.id, a.at, JSON.stringify(a), this.profile),
      ),
    );
  }

  async alerts(f: { since?: string; unread?: boolean; limit?: number } = {}): Promise<Alert[]> {
    const where = ["profile = ?"];
    const args: (string | number)[] = [this.profile];
    if (f.since) (where.push("at > ?"), args.push(f.since));
    if (f.unread) where.push("read = 0");
    args.push(f.limit ?? keepAlerts);
    const { results } = await this.db
      .prepare(
        `SELECT body, read FROM alerts WHERE ${where.join(" AND ")} ORDER BY at DESC LIMIT ?`,
      )
      .bind(...args)
      .all<{ body: string; read: number }>();
    return results.map((r) => ({ ...JSON.parse(r.body), read: r.read === 1 }));
  }

  async markAlertsRead(ids?: string[]): Promise<void> {
    if (!ids) {
      await this.db.prepare("UPDATE alerts SET read = 1 WHERE profile = ?").bind(this.profile).run();
      return;
    }
    if (!ids.length) return;
    await this.db.batch(
      ids.map((id) => this.db.prepare("UPDATE alerts SET read = 1 WHERE id = ? AND profile = ?").bind(id, this.profile)),
    );
  }

  // ---- discovery memory ----

  async unseen(watchId: string, itemIds: string[]): Promise<Set<string>> {
    const known = new Set<string>();
    for (let i = 0; i < itemIds.length; i += 50) {
      const chunk = itemIds.slice(i, i + 50);
      const { results } = await this.db
        .prepare(`SELECT item_id FROM seen WHERE watch_id = ? AND item_id IN (${chunk.map(() => "?").join(",")})`)
        .bind(watchId, ...chunk)
        .all<{ item_id: string }>();
      for (const r of results) known.add(r.item_id);
    }
    return new Set(itemIds.filter((id) => !known.has(id)));
  }

  async markSeen(watchId: string, itemIds: string[], at: string): Promise<void> {
    for (let i = 0; i < itemIds.length; i += 50) {
      await this.db.batch(
        itemIds
          .slice(i, i + 50)
          .map((id) => this.db.prepare("INSERT OR IGNORE INTO seen (watch_id, item_id, at) VALUES (?, ?, ?)").bind(watchId, id, at)),
      );
    }
  }

  async hasSeen(watchId: string): Promise<boolean> {
    return !!(await this.db.prepare("SELECT 1 FROM seen WHERE watch_id = ? LIMIT 1").bind(watchId).first());
  }

  async forgetWatch(watchId: string): Promise<void> {
    await this.db.prepare("DELETE FROM seen WHERE watch_id = ?").bind(watchId).run();
  }

  // ---- stats ----

  async putSnapshot(accountId: string, day: string, followers: number | null, extra: object): Promise<void> {
    await this.db
      .prepare(
        "INSERT INTO stats (account_id, day, followers, body) VALUES (?, ?, ?, ?) " +
          "ON CONFLICT(account_id, day) DO UPDATE SET followers = excluded.followers, body = excluded.body",
      )
      .bind(accountId, day, followers, JSON.stringify(extra))
      .run();
  }

  async accountStats(accountId: string, days = 90): Promise<AccountStats> {
    const { results } = await this.db
      .prepare("SELECT day, followers, body FROM stats WHERE account_id = ? ORDER BY day DESC LIMIT ?")
      .bind(accountId, days)
      .all<{ day: string; followers: number | null; body: string }>();
    const series: StatPoint[] = results
      .filter((r) => r.followers != null)
      .map((r) => ({ day: r.day, followers: r.followers! }))
      .reverse();
    const latest = results[0];
    const extra = latest ? (JSON.parse(latest.body) as { posts?: number | null; views28d?: number | null }) : {};
    const weekAgo = results.find((r, i) => i >= 7 && r.followers != null);
    return {
      accountId,
      followers: latest?.followers ?? null,
      followersDelta7d:
        latest?.followers != null && weekAgo?.followers != null ? latest.followers - weekAgo.followers : null,
      posts: extra.posts ?? null,
      views28d: extra.views28d ?? null,
      series,
    };
  }

  // ---- housekeeping ----

  /** Hub-wide: old finished inbox items, old discovery memory, and each profile's alerts beyond the newest 500. */
  async prune(now: Date): Promise<void> {
    const inboxCutoff = new Date(now.getTime() - keepInboxDays * 86400_000).toISOString();
    const seenCutoff = new Date(now.getTime() - 180 * 86400_000).toISOString();
    await this.db.batch([
      this.db.prepare("DELETE FROM inbox WHERE status = 'done' AND at < ?").bind(inboxCutoff),
      this.db.prepare("DELETE FROM seen WHERE at < ?").bind(seenCutoff),
      this.db.prepare(
        "DELETE FROM alerts WHERE id IN (SELECT id FROM " +
          `(SELECT id, ROW_NUMBER() OVER (PARTITION BY profile ORDER BY at DESC) AS n FROM alerts) WHERE n > ${keepAlerts})`,
      ),
    ]);
  }
}
