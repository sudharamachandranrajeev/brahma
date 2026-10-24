// Analytics from stored snapshots and content, plus the daily housekeeping run.

import { dailyAccounts } from "./accounts.ts";
import { hasAi, ideas as askIdeas, weekly } from "./ai.ts";
import { raise } from "./alerts.ts";
import { InputError } from "./http.ts";
import type { Ctx } from "./platforms/adapter.ts";
import { eachProfile } from "./profiles.ts";
import type { Store } from "./store.ts";
import type { Alert, Content, Stats } from "./types.ts";

const engagement = (c: Content) => c.likes + 2 * c.comments + (c.views ?? 0) / 100;

/**
 * When your posts do best, by weekday (0 = Monday) and UTC hour. Each post is
 * scored against its own account's median, so a big account doesn't drown
 * out a small one; scores are scaled so the best slot is 1.
 */
export function bestTimes(content: Content[]): Stats["bestTimes"] {
  const byAccount = new Map<string, number[]>();
  for (const c of content) byAccount.set(c.accountId, [...(byAccount.get(c.accountId) ?? []), engagement(c)]);
  const median = new Map(
    [...byAccount].map(([id, xs]) => {
      const s = [...xs].sort((a, b) => a - b);
      return [id, Math.max(1, s[Math.floor(s.length / 2)])];
    }),
  );
  const slots = new Map<string, { day: number; hour: number; total: number; posts: number }>();
  for (const c of content) {
    const at = new Date(c.at);
    const day = (at.getUTCDay() + 6) % 7;
    const hour = at.getUTCHours();
    const slot = slots.get(`${day}:${hour}`) ?? { day, hour, total: 0, posts: 0 };
    slot.total += engagement(c) / median.get(c.accountId)!;
    slot.posts++;
    slots.set(`${day}:${hour}`, slot);
  }
  const means = [...slots.values()].map((s) => ({ ...s, mean: s.total / s.posts }));
  const top = Math.max(0, ...means.map((s) => s.mean));
  return means
    .map((s) => ({ day: s.day, hour: s.hour, score: top ? Math.round((s.mean / top) * 100) / 100 : 0, posts: s.posts }))
    .sort((a, b) => b.score - a.score);
}

export async function getStats(store: Store, now = new Date()): Promise<Stats> {
  const accounts = await store.accounts();
  const since90 = new Date(now.getTime() - 90 * 86400_000).toISOString();
  const since30 = new Date(now.getTime() - 30 * 86400_000).toISOString();
  const content = (await store.content(undefined, 1000)).filter((c) => c.at >= since90);
  return {
    accounts: await Promise.all(accounts.map((a) => store.accountStats(a.id))),
    bestTimes: bestTimes(content),
    topContent: content
      .filter((c) => c.at >= since30)
      .sort((a, b) => engagement(b) - engagement(a))
      .slice(0, 10),
  };
}

export interface Ideas {
  ideas: { kind: string; title: string; body: string }[];
  generatedAt: string | null;
}

export const cachedIdeas = (store: Store) => store.doc<Ideas>("ideas", { ideas: [], generatedAt: null });

export async function refreshIdeas(store: Store, now = new Date()): Promise<Ideas> {
  const stats = await getStats(store, now);
  const top = stats.topContent.length ? stats.topContent : await store.content(undefined, 12);
  if (!top.length) return { ideas: [], generatedAt: null };
  const result: Ideas = { ideas: await askIdeas(store, top, stats.bestTimes), generatedAt: now.toISOString() };
  await store.putDoc("ideas", result);
  return result;
}

/** The last 7 days in a few lines, raised as a "summary" alert (so it reaches the phone too). */
export async function weeklySummary(ctx: Ctx): Promise<Alert> {
  const { store, now } = ctx;
  const since = new Date(now.getTime() - 7 * 86400_000).toISOString();
  const accounts = await store.accounts();
  if (!accounts.length) throw new InputError("connect an account first", [], 409);
  const posted = (await store.content(undefined, 200)).filter((c) => c.at >= since);
  const inbox = await store.inboxSummary(since);
  const stats = await Promise.all(accounts.map(async (a) => ({ ...(await store.accountStats(a.id)), name: a.name, platform: a.platform })));
  const note = await weekly(store, { accounts: stats, posted, inbox });
  const [alert] = await raise(ctx.env, store, [{ kind: "summary", title: note.title, body: note.body, url: null, image: null, ref: null }], now.toISOString());
  return alert;
}

/** 03:00 UTC, in every profile: account checks and snapshots, fresh ideas, on Mondays the weekly summary. Then pruning. */
export async function daily(ctx: Ctx): Promise<void> {
  await eachProfile(ctx, "daily", dailyProfile);
  await ctx.store.prune(ctx.now);
}

async function dailyProfile(ctx: Ctx): Promise<void> {
  await dailyAccounts(ctx);
  if (await hasAi(ctx.store)) {
    try {
      await refreshIdeas(ctx.store, ctx.now);
    } catch (err) {
      console.log(`ideas: ${err instanceof Error ? err.message : err}`);
    }
    if (ctx.now.getUTCDay() === 1) {
      try {
        await weeklySummary(ctx);
      } catch (err) {
        console.log(`weekly summary: ${err instanceof Error ? err.message : err}`);
      }
    }
  }
}
