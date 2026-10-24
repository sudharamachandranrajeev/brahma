// Alt text, inbox triage and translation, comment moderation, the weekly
// summary and Telegram.

import { test } from "node:test";
import assert from "node:assert/strict";
import { Budget } from "../src/social/http.ts";
import { moderate, pollAccount, translateItem } from "../src/social/inbox.ts";
import { mediaFiles, setAlt } from "../src/social/media.ts";
import type { Ctx } from "../src/social/platforms/adapter.ts";
import { adapters } from "../src/social/platforms/index.ts";
import { connectTelegram } from "../src/social/platforms/telegram.ts";
import { problemsWith } from "../src/social/publish.ts";
import { weeklySummary } from "../src/social/stats.ts";
import { Store } from "../src/social/store.ts";
import type { Account, InboxItem } from "../src/social/types.ts";
import { mockFetch, testEnv } from "./shims.ts";

function setup(now = new Date("2026-10-26T12:00:00Z")) {
  const env = testEnv();
  const store = new Store(env);
  const ctx: Ctx = { env, store, budget: new Budget(45), now };
  return { env, store, ctx };
}

const account = (platform: Account["platform"], remoteId: string): Omit<Account, "id"> => ({
  platform,
  name: `Test ${platform}`,
  handle: `@test-${platform}`,
  avatar: null,
  remoteId,
  status: "ok",
  statusMessage: null,
  expiresAt: null,
  capabilities: ["publish", "comments"],
  connectedAt: "2026-10-01T00:00:00.000Z",
  checkedAt: null,
});

const item = (a: Account, n: number, text: string, at = "2026-10-26T11:50:00.000Z"): InboxItem => ({
  id: `item-${n}`,
  accountId: a.id,
  platform: a.platform,
  kind: "comment",
  context: { type: "post", id: "p1", title: "Launch post", url: null, thumbnail: null },
  author: { id: `u${n}`, name: `Sam ${n}`, handle: `sam${n}`, avatar: null },
  text,
  at,
  remoteId: `c${n}`,
  parentRemoteId: null,
  status: "new",
  labels: [],
});

/** A Messages API answer whose text is [json]. */
const claude = (json: unknown) => ({
  id: "msg_1",
  type: "message",
  role: "assistant",
  model: "claude-opus-5-5",
  content: [{ type: "text", text: JSON.stringify(json) }],
  stop_reason: "end_turn",
  usage: { input_tokens: 1, output_tokens: 1 },
});

// The SDK honours ANTHROPIC_BASE_URL from the shell; the Worker has no such variable.
delete process.env.ANTHROPIC_BASE_URL;
const anthropic = "https://api.anthropic.com/v1/messages";

test("triage asks Claude only about recent new items, and only with a key", async () => {
  const { store, ctx } = setup();
  const a = await store.saveAccount(account("instagram", "17841"), {});
  const real = adapters.instagram;
  let batch = [item(a, 1, "first poll")];
  adapters.instagram = { ...real, poll: async () => ({ items: batch, content: [], state: null }) };
  const asked: string[] = [];
  const net = mockFetch({
    [anthropic]: (_u, init) => {
      asked.push(JSON.stringify(JSON.parse(String(init.body)).messages));
      return claude({ results: [{ id: "item-3", mood: "question", priority: "high", lang: "EN" }] });
    },
  });
  try {
    await pollAccount(ctx, a);
    assert.equal(asked.length, 0, "no key, no Claude");
    await store.putCredential("anthropic", null, "sk-test");
    batch = [item(a, 1, "first poll"), item(a, 2, "old one", "2026-09-01T00:00:00.000Z"), item(a, 3, "Is this still available??")];
    await pollAccount(ctx, a);
    assert.equal(asked.length, 1);
    assert.match(asked[0], /still available/);
    assert.doesNotMatch(asked[0], /old one|first poll/);
    assert.deepEqual((await store.inboxItem("item-3"))!.triage, { mood: "question", priority: "high", lang: "en" });
    assert.equal((await store.inboxItem("item-2"))!.triage, undefined);
  } finally {
    net.restore();
    adapters.instagram = real;
  }
});

test("triage results are stored and filter the inbox", async () => {
  const { store, ctx } = setup();
  const a = await store.saveAccount(account("instagram", "17841"), {});
  await store.putCredential("anthropic", null, "sk-test");
  const real = adapters.instagram;
  adapters.instagram = { ...real, poll: async () => ({ items: [item(a, 1, "Broken on arrival"), item(a, 2, "Love it")], content: [], state: null }) };
  const net = mockFetch({
    [anthropic]: () =>
      claude({
        results: [
          { id: "item-1", mood: "complaint", priority: "high", lang: "en" },
          { id: "item-2", mood: "positive", priority: "low", lang: "en" },
        ],
      }),
  });
  try {
    await pollAccount(ctx, a);
    assert.deepEqual((await store.inboxItem("item-1"))!.triage, { mood: "complaint", priority: "high", lang: "en" });
    assert.deepEqual((await store.inbox({ triage: "urgent" })).map((x) => x.id), ["item-1"]);
    assert.deepEqual((await store.inbox({ triage: "positive" })).map((x) => x.id), ["item-2"]);
  } finally {
    net.restore();
    adapters.instagram = real;
  }
});

test("translation goes into the owner's language once and is kept", async () => {
  const { store, ctx } = setup();
  const a = await store.saveAccount(account("instagram", "17841"), {});
  await store.putCredential("anthropic", null, "sk-test");
  await store.putDoc("settings", { language: "English" });
  await store.addInbox([item(a, 1, "ഇത് എത്രയാണ്?")]);
  const asked: string[] = [];
  const net = mockFetch({
    [anthropic]: (_u, init) => {
      asked.push(JSON.parse(String(init.body)).system.match(/into (\w+)/)[1]);
      return claude({ lang: "ml", text: "How much is this?" });
    },
  });
  try {
    assert.deepEqual((await translateItem(ctx, "item-1")).translation, { lang: "ml", to: "English", text: "How much is this?" });
    await translateItem(ctx, "item-1");
    // A new language asks again.
    await store.putDoc("settings", { language: "French" });
    assert.equal((await translateItem(ctx, "item-1")).translation?.to, "French");
    assert.deepEqual(asked, ["English", "French"]);
  } finally {
    net.restore();
  }
});

test("moderation hides and deletes where the platform allows it", async () => {
  const { store, ctx } = setup();
  const ig = await store.saveAccount(account("instagram", "17841"), { pageToken: "pt", pageId: "pg" });
  const bsky = await store.saveAccount(account("bluesky", "did:plc:1"), {});
  await store.addInbox([item(ig, 1, "spam spam"), { ...item(bsky, 2, "rude"), platform: "bluesky", id: "item-2" }]);
  const net = mockFetch({ "https://graph.facebook.com/": () => ({ success: true }) });
  try {
    const hidden = await moderate(ctx, "item-1", "hide");
    assert.equal(hidden.moderation, "hidden");
    assert.equal(hidden.status, "done");
    assert.equal(net.sent[0].method, "POST");
    assert.match(net.sent[0].url, /\/c1$/);
    assert.equal(JSON.parse(net.sent[0].body!).hide, true);
    assert.equal((await moderate(ctx, "item-1", "unhide")).moderation, undefined);
    await moderate(ctx, "item-1", "delete");
    assert.equal(net.sent[2].method, "DELETE");
    await assert.rejects(moderate(ctx, "item-1", "hide"), /already deleted/);
    await assert.rejects(moderate(ctx, "item-2", "hide"), /Bluesky doesn't let you hide/);
  } finally {
    net.restore();
  }
});

test("alt text is kept on media and handed to adapters", async () => {
  const { store } = setup();
  await store.putMedia({ id: "m1", filename: "cat.jpg", contentType: "image/jpeg", size: 10, status: "ready", createdAt: "2026-10-26T00:00:00Z" }, null);
  assert.equal((await mediaFiles(store, ["m1"]))[0].alt, "");
  assert.equal((await setAlt(store, "m1", "  A ginger cat asleep on a windowsill  ")).alt, "A ginger cat asleep on a windowsill");
  assert.equal((await mediaFiles(store, ["m1"]))[0].alt, "A ginger cat asleep on a windowsill");
  assert.equal((await setAlt(store, "m1", "")).alt, undefined);
});

test("the weekly summary is raised as a summary alert and pushed", async () => {
  const { store, ctx } = setup();
  const a = await store.saveAccount(account("instagram", "17841"), {});
  await store.putCredential("anthropic", null, "sk-test");
  await store.addInbox([{ ...item(a, 1, "help?"), triage: { mood: "question", priority: "high", lang: "en" } }, item(a, 2, "x", "2026-09-01T00:00:00Z")]);
  let sent = "";
  const net = mockFetch({
    [anthropic]: (_u, init) => {
      sent = String(init.body);
      return claude({ title: "A quiet week", body: "1 question waits for you." });
    },
  });
  try {
    const alert = await weeklySummary(ctx);
    assert.equal(alert.kind, "summary");
    assert.match(sent, /\\"question\\":1/);
    assert.match(sent, /\\"unanswered\\":1/);
    assert.equal(net.pushes[0].title, "A quiet week");
  } finally {
    net.restore();
  }
});

// ---- Telegram ----

const tgApi = "https://api.telegram.org/bot123456:";
const token = `123456:${"A".repeat(35)}`;

function telegramNet(extra: Record<string, (body: any) => unknown> = {}) {
  const methods: Record<string, (body: any) => unknown> = {
    getMe: () => ({ id: 123456, is_bot: true, username: "vani_bot" }),
    getChat: (b) =>
      b.chat_id === -1002 ? { id: -1002, type: "supergroup", title: "Shop chat" } : { id: -1001, type: "channel", title: "Shop", username: "shop", linked_chat_id: -1002 },
    getChatMember: () => ({ status: "administrator", can_post_messages: true }),
    ...extra,
  };
  return mockFetch({
    [tgApi]: (url, init) => {
      const method = url.pathname.split("/").pop()!;
      const body = JSON.parse(String(init.body));
      const fn = methods[method];
      if (!fn) return new Response(JSON.stringify({ ok: false, error_code: 400, description: `Bad Request: ${method}` }), { status: 400 });
      return { ok: true, result: fn(body) };
    },
  });
}

test("Telegram: connects a channel with its discussion group, one bot per chat", async () => {
  const { store, ctx } = setup();
  const net = telegramNet();
  try {
    const c = await connectTelegram(ctx, token, "@shop");
    assert.equal(c.account.remoteId, "123456:-1001");
    assert.equal(c.account.handle, "@shop");
    assert.ok(c.account.capabilities.includes("comments"));
    assert.deepEqual(c.secret, { token, botId: 123456, chatId: -1001, discussionId: -1002 });
    await store.saveAccount(c.account, c.secret);
    await assert.rejects(connectTelegram(ctx, token, "-1002"), /one bot per channel/);
  } finally {
    net.restore();
  }
});

test("Telegram: publishes, collects comments and DMs, replies and deletes", async () => {
  const { store, ctx } = setup();
  const sent: { method: string; body: any }[] = [];
  const net = telegramNet(
    Object.fromEntries(
      ["sendMessage", "sendPhoto", "sendMediaGroup", "deleteMessage", "getUpdates"].map((m) => [
        m,
        (b: any) => {
          sent.push({ method: m, body: b });
          if (m === "sendMediaGroup") return [{ message_id: 7, chat: { id: -1001, username: "shop" } }, { message_id: 8 }];
          if (m === "deleteMessage") return true;
          if (m === "getUpdates")
            return [
              { update_id: 10, message: { message_id: 50, date: 1793000000, chat: { id: -1002, type: "supergroup", title: "Shop chat" }, from: { id: 9, first_name: "Asha" }, text: "Price?", reply_to_message: { message_id: 40, is_automatic_forward: true, forward_origin: { message_id: 7 }, text: "New stock" } } },
              { update_id: 11, message: { message_id: 3, date: 1793000001, chat: { id: 9, type: "private" }, from: { id: 9, first_name: "Asha", username: "asha" }, text: "hello" } },
              { update_id: 12, message: { message_id: 51, date: 1793000002, chat: { id: -1002, type: "supergroup" }, from: { id: 1, is_bot: true }, text: "bot" } },
            ];
          return { message_id: 99, chat: { id: b.chat_id, username: "shop" } };
        },
      ]),
    ),
  );
  try {
    const c = await connectTelegram(ctx, token, "shop");
    const a = await store.saveAccount(c.account, c.secret);
    const media = [
      { id: "m1", key: "media/m1", url: "https://hub.test/media/m1", contentType: "image/jpeg", size: 1, filename: "a.jpg", alt: "" },
      { id: "m2", key: "media/m2", url: "https://hub.test/media/m2", contentType: "video/mp4", size: 1, filename: "b.mp4", alt: "" },
    ];
    let committed = false;
    const progress = { saveContainer: async () => {}, commit: () => void (committed = true) };
    const post = { id: "p", text: "New stock", media: [], targets: [], scheduledAt: null, status: "scheduled" as const, tags: [], createdAt: "", updatedAt: "" };
    const target = { accountId: a.id, format: "post" as const, status: "publishing" as const, attempts: 1 };
    const r = await adapters.telegram.publish(ctx, a, { post, target, text: "New stock", media }, progress);
    assert.ok(committed);
    assert.deepEqual(r, { remoteId: "7", permalink: "https://t.me/shop/7" });
    const group = sent.find((s) => s.method === "sendMediaGroup")!.body;
    assert.deepEqual(group.media.map((m: any) => m.type), ["photo", "video"]);
    assert.equal(group.media[0].caption, "New stock");

    const poll = await adapters.telegram.poll(ctx, a, null);
    assert.deepEqual(poll.state, { offset: 13 });
    assert.equal(poll.items.length, 2);
    const [onPost, dm] = poll.items;
    assert.equal(onPost.kind, "comment");
    assert.equal(onPost.context.url, "https://t.me/shop/7");
    assert.equal(onPost.remoteId, "-1002:50");
    assert.equal(dm.kind, "message");
    assert.equal(dm.author.handle, "@asha");

    await adapters.telegram.reply(ctx, a, onPost, "£20", false);
    const reply = sent.filter((s) => s.method === "sendMessage").pop()!.body;
    assert.deepEqual([reply.chat_id, reply.reply_parameters.message_id], [-1002, 50]);
    await adapters.telegram.moderate!(ctx, a, onPost, "delete");
    assert.deepEqual(sent.find((s) => s.method === "deleteMessage")!.body, { chat_id: -1002, message_id: 50 });
  } finally {
    net.restore();
  }
});

test("Telegram: validation knows caption and file limits", async () => {
  const { store } = setup();
  const a = await store.saveAccount(account("telegram", "1:-1001"), {});
  await store.putMedia({ id: "big", filename: "big.jpg", contentType: "image/jpeg", size: 6 * 1024 * 1024, status: "ready", createdAt: "" }, null);
  const problems = await problemsWith(store, { text: "x".repeat(1100), media: ["big"], targets: [{ accountId: a.id, format: "post", firstComment: "hi" }] });
  assert.ok(problems.some((p) => /1024 characters/.test(p)));
  assert.ok(problems.some((p) => /5 MB photo limit/.test(p)));
  assert.ok(problems.some((p) => /doesn't take a first comment/.test(p)));
});
