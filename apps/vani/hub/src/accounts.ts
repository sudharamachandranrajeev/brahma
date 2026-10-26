// Account health: broken tokens, expiry warnings, the daily check and snapshot.

import { raise, type NewAlert } from "./alerts.ts";
import { OutOfBudget, PlatformError } from "./http.ts";
import { platformInfo, type Ctx } from "./platforms/adapter.ts";
import { adapters } from "./platforms/index.ts";
import type { Account } from "./types.ts";

const warnDays = 7;

const label = (a: Account) => `${platformInfo[a.platform].name} (${a.handle})`;

/** Marks an account as needing reconnection and queues one alert (not again while it stays broken). */
export async function markBroken(ctx: Ctx, account: Account, message: string, alerts: NewAlert[]) {
  if (account.status === "broken") return;
  account.status = "broken";
  account.statusMessage = message;
  await ctx.store.updateAccount(account);
  alerts.push({ kind: "account", title: `Reconnect ${label(account)}`, body: message, url: null, image: null, ref: account.id });
}

/** "ok" or "expiring" from the token's expiry. */
function health(a: Account, now: Date): Account["status"] {
  if (!a.expiresAt) return "ok";
  return new Date(a.expiresAt).getTime() - now.getTime() < warnDays * 86400_000 ? "expiring" : "ok";
}

/**
 * Re-verifies an account with its platform and saves the result. Auth failures
 * mark it broken; other failures leave it as it was and are rethrown.
 */
export async function checkAccount(ctx: Ctx, account: Account, alerts: NewAlert[]): Promise<Account> {
  try {
    const fresh = await adapters[account.platform].check(ctx, account);
    const status = health(fresh, ctx.now);
    if (status === "expiring" && account.status !== "expiring") {
      alerts.push({
        kind: "account",
        title: `${label(account)} disconnects soon`,
        body: `Its access runs out on ${fresh.expiresAt!.slice(0, 10)}. Reconnect it in Accounts to keep posting.`,
        url: null,
        image: null,
        ref: account.id,
      });
    }
    const saved: Account = { ...fresh, id: account.id, status, statusMessage: null, checkedAt: ctx.now.toISOString() };
    await ctx.store.updateAccount(saved);
    return saved;
  } catch (err) {
    if (err instanceof PlatformError && err.auth) {
      await markBroken(ctx, account, err.message, alerts);
      return account;
    }
    throw err;
  }
}

/** The 03:00 pass: renew tokens, re-check every account, store a stats snapshot. */
export async function dailyAccounts(ctx: Ctx): Promise<void> {
  const alerts: NewAlert[] = [];
  const day = ctx.now.toISOString().slice(0, 10);
  for (let account of await ctx.store.accounts()) {
    if (ctx.budget.left < 4) break;
    const adapter = adapters[account.platform];
    try {
      if (account.status !== "broken") await adapter.refresh?.(ctx, account);
      account = await checkAccount(ctx, account, alerts);
      if (account.status === "broken") continue;
      const snap = await adapter.snapshot(ctx, account);
      await ctx.store.putSnapshot(account.id, day, snap.followers, { posts: snap.posts, views28d: snap.views28d });
    } catch (err) {
      if (err instanceof OutOfBudget) break;
      if (err instanceof PlatformError && err.auth) await markBroken(ctx, account, err.message, alerts);
      else console.log(`daily ${account.platform} ${account.handle}: ${err instanceof Error ? err.message : err}`);
    }
  }
  if (alerts.length) await raise(ctx.env, ctx.store, alerts);
}
