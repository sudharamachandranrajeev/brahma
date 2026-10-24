// The unified inbox: polling accounts, applying rules to what is new, replying.

import { markBroken } from "./accounts.ts";
import { hasAi, judgeRules, translate, triage } from "./ai.ts";
import { raise, type NewAlert } from "./alerts.ts";
import { InputError, OutOfBudget, PlatformError } from "./http.ts";
import { platformInfo, type Ctx } from "./platforms/adapter.ts";
import { adapters } from "./platforms/index.ts";
import { getRules, getSettings } from "./settings.ts";
import type { Account, InboxItem, InboxRule, ModerateAction } from "./types.ts";

/** Rules only act on items this recent, so a long outage doesn't trigger a burst of late auto-replies. */
const actWithinMs = 24 * 3600_000;

/** Only this much history is triaged, so a first poll doesn't send months of comments to Claude. */
const triageWithinMs = 7 * 86400_000;

/** Polls one account; returns the items it had not seen before. */
export async function pollAccount(ctx: Ctx, account: Account): Promise<InboxItem[]> {
  const { store } = ctx;
  const { state, polledAt } = await store.pollState(account.id);
  const result = await adapters[account.platform].poll(ctx, account, state);
  const fresh = await store.addInbox(result.items);
  await store.saveContent(result.content);
  await store.setPollState(account.id, result.state, ctx.now.toISOString());
  await triageFresh(ctx, fresh);
  // The first poll brings history; rules are for what arrives from now on.
  if (polledAt && fresh.length) await applyRules(ctx, account, fresh);
  return fresh;
}

/** The cron's inbox pass: least recently polled accounts first, while the budget lasts. */
export async function pollAll(ctx: Ctx, only?: Account[]): Promise<{ polled: number; items: number }> {
  const alerts: NewAlert[] = [];
  let polled = 0;
  let items = 0;
  for (const account of only ?? (await ctx.store.accountsByPollAge())) {
    if (account.status === "broken") continue;
    if (ctx.budget.left < 6) break;
    try {
      items += (await pollAccount(ctx, account)).length;
      polled++;
    } catch (err) {
      if (err instanceof OutOfBudget) break;
      if (err instanceof PlatformError && err.auth) await markBroken(ctx, account, err.message, alerts);
      else console.log(`poll ${account.platform} ${account.handle}: ${err instanceof Error ? err.message : err}`);
    }
  }
  if (alerts.length) await raise(ctx.env, ctx.store, alerts);
  return { polled, items };
}

/** Tags recent new items with Claude's mood, priority and language. Best effort: the inbox works without it. */
async function triageFresh(ctx: Ctx, fresh: InboxItem[]) {
  const recent = fresh.filter((x) => ctx.now.getTime() - new Date(x.at).getTime() < triageWithinMs).slice(0, 60);
  if (!recent.length || ctx.budget.left < 8 || !(await hasAi(ctx.store))) return;
  ctx.budget.take(Math.ceil(recent.length / 30));
  try {
    const tags = await triage(ctx.store, recent);
    for (const item of recent) {
      const t = tags.get(item.id);
      if (!t) continue;
      item.triage = t;
      await ctx.store.saveInboxItem(item);
    }
  } catch (err) {
    console.log(`triage: ${err instanceof Error ? err.message : err}`);
  }
}

const hasKeyword = (rule: InboxRule, text: string) => {
  const lower = text.toLowerCase();
  return rule.keywords.some((k) => lower.includes(k.toLowerCase()));
};

/**
 * Rules match on any keyword, or on their description as judged by Claude. A
 * rule with neither matches everything on its accounts (a welcome reply).
 */
export async function matchRules(ctx: Ctx, account: Account, items: InboxItem[]): Promise<Map<string, InboxRule[]>> {
  const rules = (await getRules(ctx.store)).filter((r) => r.enabled && (!r.accountIds || r.accountIds.includes(account.id)));
  const out = new Map<string, InboxRule[]>();
  if (!rules.length) return out;
  let judged = new Map<string, string[]>();
  if (rules.some((r) => r.description?.trim()) && (await hasAi(ctx.store))) {
    try {
      judged = await judgeRules(ctx.store, rules, items);
    } catch (err) {
      console.log(`rule matching: ${err instanceof Error ? err.message : err}`);
    }
  }
  for (const item of items) {
    const hits = rules.filter((r) => {
      const described = !!r.description?.trim();
      if (!r.keywords.length && !described) return true;
      return hasKeyword(r, item.text) || (described && (judged.get(item.id) ?? []).includes(r.id));
    });
    if (hits.length) out.set(item.id, hits);
  }
  return out;
}

async function applyRules(ctx: Ctx, account: Account, fresh: InboxItem[]) {
  const matches = await matchRules(ctx, account, fresh);
  if (!matches.size) return;
  const alerts: NewAlert[] = [];
  const where = `${platformInfo[account.platform].name} (${account.handle})`;
  for (const item of fresh) {
    const rules = matches.get(item.id);
    if (!rules) continue;
    item.labels = [...new Set([...item.labels, ...rules.map((r) => r.name)])];
    const recent = ctx.now.getTime() - new Date(item.at).getTime() < actWithinMs;
    const fill = (t: string) => t.replaceAll("{name}", item.author.name.split(" ")[0] || item.author.handle);
    const replyRule = rules.find((r) => r.reply?.trim());
    const privateRule = rules.find((r) => r.privateReply?.trim());
    try {
      if (recent && privateRule && canReplyPrivately(account, item)) {
        await sendReply(ctx, account, item, fill(privateRule.privateReply!), true);
      }
      if (recent && replyRule) {
        await sendReply(ctx, account, item, fill(replyRule.reply!), false);
      }
    } catch (err) {
      if (err instanceof OutOfBudget) throw err;
      alerts.push({ kind: "inbox", title: `Auto-reply failed on ${where}`, body: err instanceof Error ? err.message : String(err), url: item.context.url, image: null, ref: item.id });
    }
    await ctx.store.saveInboxItem(item);
    const alerting = rules.filter((r) => r.alert);
    if (alerting.length) {
      alerts.push({
        kind: "inbox",
        title: `${alerting.map((r) => r.name).join(", ")}: ${item.author.name} on ${where}`,
        body: item.text.slice(0, 300),
        url: item.context.url,
        image: item.author.avatar,
        ref: item.id,
      });
    }
  }
  if (alerts.length) await raise(ctx.env, ctx.store, alerts);
}

/** Private replies (comment to DM) exist on Instagram and Facebook comments only. */
export function canReplyPrivately(account: Account, item: InboxItem) {
  return item.kind === "comment" && account.capabilities.includes("private_reply") && !item.myReply?.private;
}

async function sendReply(ctx: Ctx, account: Account, item: InboxItem, text: string, privately: boolean) {
  await adapters[account.platform].reply(ctx, account, item, text, privately);
  item.myReply = { text, at: new Date().toISOString(), private: privately };
  item.status = "done";
}

async function itemAndAccount(ctx: Ctx, itemId: string) {
  const item = await ctx.store.inboxItem(itemId);
  if (!item) throw new InputError("no such inbox item", [], 404);
  const account = await ctx.store.account(item.accountId);
  if (!account) throw new InputError("that account was removed", [], 410);
  return { item, account };
}

/** A platform failure as the API reports it; auth failures also mark the account broken. */
async function platformFailure(ctx: Ctx, account: Account, err: unknown): Promise<never> {
  if (err instanceof PlatformError && err.auth) {
    const alerts: NewAlert[] = [];
    await markBroken(ctx, account, err.message, alerts);
    await raise(ctx.env, ctx.store, alerts);
  }
  if (err instanceof PlatformError) throw new InputError(`${platformInfo[account.platform].name}: ${err.message}`, [], err.transient ? 503 : 502);
  throw err;
}

/** Replies from the app. */
export async function replyTo(ctx: Ctx, itemId: string, text: string, privately: boolean): Promise<InboxItem> {
  const { item, account } = await itemAndAccount(ctx, itemId);
  if (privately && !canReplyPrivately(account, item)) throw new InputError("a private reply isn't possible here", [], 409);
  const max = platformInfo[account.platform].maxText;
  if (text.length > max) throw new InputError(`the reply is longer than ${max} characters`);
  try {
    await sendReply(ctx, account, item, text, privately);
  } catch (err) {
    await platformFailure(ctx, account, err);
  }
  await ctx.store.saveInboxItem(item);
  return item;
}

/** Hides, unhides or deletes someone's comment on the platform. */
export async function moderate(ctx: Ctx, itemId: string, action: ModerateAction): Promise<InboxItem> {
  const { item, account } = await itemAndAccount(ctx, itemId);
  const allowed = platformInfo[account.platform].moderation;
  const adapter = adapters[account.platform];
  if (!adapter.moderate || !allowed.includes(action === "unhide" ? "hide" : action) || (item.kind !== "comment" && item.kind !== "reply")) {
    throw new InputError(`${platformInfo[account.platform].name} doesn't let you ${action} this`, [], 409);
  }
  if (item.moderation === "deleted") throw new InputError("this comment is already deleted", [], 409);
  try {
    await adapter.moderate(ctx, account, item, action);
  } catch (err) {
    await platformFailure(ctx, account, err);
  }
  item.moderation = action === "hide" ? "hidden" : action === "delete" ? "deleted" : undefined;
  if (action !== "unhide") item.status = "done";
  await ctx.store.saveInboxItem(item);
  return item;
}

/** The item in the owner's language (kept on the item, so it is translated once). */
export async function translateItem(ctx: Ctx, itemId: string): Promise<InboxItem> {
  const item = await ctx.store.inboxItem(itemId);
  if (!item) throw new InputError("no such inbox item", [], 404);
  const to = (await getSettings(ctx.store)).language;
  if (item.translation?.to === to) return item;
  item.translation = { ...(await translate(ctx.store, item.text, to)), to };
  await ctx.store.saveInboxItem(item);
  return item;
}
