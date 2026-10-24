// Analytics from stored snapshots and content, plus the daily housekeeping run.

import { dailyAccounts } from "./accounts.ts";
import { hasAi, ideas as askIdeas } from "./ai.ts";
import type { Ctx } from "./platforms/adapter.ts";
import type { Store } from "./store.ts";
import type { Content, Stats } from "./types.ts";

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

/** 03:00 UTC: account checks and snapshots, fresh ideas, pruning. */
export async function daily(ctx: Ctx): Promise<void> {
  await dailyAccounts(ctx);
  if (await hasAi(ctx.store)) {
    try {
      await refreshIdeas(ctx.store, ctx.now);
    } catch (err) {
      console.log(`ideas: ${err instanceof Error ? err.message : err}`);
    }
  }
  await ctx.store.prune(ctx.now);
}
