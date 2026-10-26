// Telegram channels and groups through a bot (Bot API). Make a bot with
// @BotFather, add it as an admin of the channel (and of the channel's
// discussion group to collect comments). The bot's updates are read with
// getUpdates, so one bot serves one connected chat and has no webhook.

import { call, PlatformError } from "../http.ts";
import type { Account, InboxItem } from "../types.ts";
import { clip, inboxItem, iso, itemId, isVideo, type Adapter, type Connected, type Ctx } from "./adapter.ts";

export interface TelegramSecret {
  token: string;
  botId: number;
  chatId: number;
  /** A channel's linked discussion group, where its comments live. */
  discussionId: number | null;
}

/** Calls a Bot API method (errors name "Telegram", never the URL with the token). */
export async function tg<T = any>(ctx: Ctx, token: string, method: string, body: object = {}): Promise<T> {
  try {
    const r = await call(`https://api.telegram.org/bot${token}/${method}`, {
      method: "POST",
      budget: ctx.budget,
      label: "Telegram",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    });
    return r.result as T;
  } catch (err) {
    if (!(err instanceof PlatformError)) throw err;
    // 401: the token was revoked; 403: the bot was removed from the chat.
    throw new PlatformError(err.message, err.status, err.transient, err.status === 401 || err.status === 403, err.permission);
  }
}

const isAdmin = (m: any) => m?.status === "creator" || m?.status === "administrator";

/** Chat id as Telegram links use it: -1001234 → 1234. */
const linkId = (chatId: number) => String(chatId).replace(/^-100/, "");

const messageUrl = (chat: { id: number; username?: string }, messageId: number) =>
  chat.username ? `https://t.me/${chat.username}/${messageId}` : `https://t.me/c/${linkId(chat.id)}/${messageId}`;

async function chatAccount(ctx: Ctx, token: string, botId: number, chatRef: string | number, connectedAt: string) {
  const chat = await tg(ctx, token, "getChat", { chat_id: chatRef });
  if (chat.type === "private") throw new PlatformError("Telegram: connect a channel or a group, not a private chat", 400, false, false);
  const me = await tg(ctx, token, "getChatMember", { chat_id: chat.id, user_id: botId });
  if (!isAdmin(me) || (chat.type === "channel" && !me.can_post_messages)) {
    throw new PlatformError(`Telegram: make the bot an admin of ${chat.title} that can post messages`, 403, false, true);
  }
  let discussionId: number | null = chat.type === "channel" ? (chat.linked_chat_id ?? null) : chat.id;
  if (discussionId && discussionId !== chat.id) {
    // The bot only sees every message in the discussion group when it is an admin there.
    const there = await tg(ctx, token, "getChatMember", { chat_id: discussionId, user_id: botId }).catch(() => null);
    if (!isAdmin(there)) discussionId = null;
  }
  const account: Connected["account"] = {
    platform: "telegram",
    name: chat.title ?? "Telegram chat",
    handle: chat.username ? `@${chat.username}` : chat.title,
    avatar: null,
    remoteId: `${botId}:${chat.id}`,
    status: "ok",
    statusMessage: null,
    expiresAt: null,
    capabilities: ["publish", "messages", "insights", ...(discussionId ? (["comments"] as const) : [])],
    connectedAt,
    checkedAt: ctx.now.toISOString(),
  };
  return { account, chat, discussionId };
}

export async function connectTelegram(ctx: Ctx, token: string, chat: string): Promise<Connected> {
  const bot = await tg(ctx, token, "getMe");
  // getUpdates hands each update to one reader, so a bot serves one chat in the whole hub.
  const others = (await ctx.store.allAccounts())
    .map((x) => x.account)
    .filter((a) => a.platform === "telegram" && a.remoteId.startsWith(`${bot.id}:`));
  const ref = /^-?\d+$/.test(chat) ? Number(chat) : chat.startsWith("@") ? chat : `@${chat.replace(/^https:\/\/t\.me\//, "")}`;
  const c = await chatAccount(ctx, token, bot.id, ref, ctx.now.toISOString());
  if (others.some((a) => a.remoteId !== c.account.remoteId)) {
    throw new PlatformError("Telegram: this bot already serves another chat; make one bot per channel", 409, false, false);
  }
  return { account: c.account, secret: { token, botId: bot.id, chatId: c.chat.id, discussionId: c.discussionId } satisfies TelegramSecret };
}

const author = (from: any) => ({
  id: String(from?.id ?? ""),
  name: [from?.first_name, from?.last_name].filter(Boolean).join(" ") || from?.username || "Someone",
  handle: from?.username ? `@${from.username}` : "",
  avatar: null,
});

/** "chatId:messageId", so a reply knows where to go. */
const ref = (chatId: number, messageId: number) => `${chatId}:${messageId}`;
const parseRef = (r: string) => {
  const i = r.lastIndexOf(":");
  return { chatId: Number(r.slice(0, i)), messageId: Number(r.slice(i + 1)) };
};

export const telegram: Adapter = {
  async publish(ctx, account, { text, media }, progress) {
    const s = await ctx.store.secretOf<TelegramSecret>(account.id);
    let sent: any;
    if (!media.length) {
      progress.commit();
      sent = await tg(ctx, s.token, "sendMessage", { chat_id: s.chatId, text });
    } else if (media.length === 1) {
      const video = isVideo(media[0]);
      progress.commit();
      sent = await tg(ctx, s.token, video ? "sendVideo" : "sendPhoto", { chat_id: s.chatId, [video ? "video" : "photo"]: media[0].url, caption: text || undefined });
    } else {
      progress.commit();
      const group = await tg<any[]>(ctx, s.token, "sendMediaGroup", {
        chat_id: s.chatId,
        media: media.map((m, i) => ({ type: isVideo(m) ? "video" : "photo", media: m.url, ...(i === 0 && text ? { caption: text } : {}) })),
      });
      sent = group[0];
    }
    return { remoteId: String(sent.message_id), permalink: messageUrl(sent.chat, sent.message_id) };
  },

  async poll(ctx, account, state: { offset?: number } | null) {
    const s = await ctx.store.secretOf<TelegramSecret>(account.id);
    const updates = await tg<any[]>(ctx, s.token, "getUpdates", {
      offset: state?.offset,
      limit: 100,
      timeout: 0,
      allowed_updates: ["message"],
    });
    const items: InboxItem[] = [];
    let offset = state?.offset;
    for (const u of updates) {
      offset = u.update_id + 1;
      const m = u.message;
      const text = m?.text ?? m?.caption;
      if (!m || !text || m.from?.is_bot || m.is_automatic_forward) continue;
      const replyTo = m.reply_to_message;
      if (m.chat.type === "private") {
        items.push(
          inboxItem(account, {
            id: await itemId(account.id, ref(m.chat.id, m.message_id)),
            kind: "message",
            context: { type: "dm", id: String(m.chat.id), title: "Message to your bot", url: null, thumbnail: null },
            author: author(m.from),
            text,
            at: iso(m.date * 1000),
            remoteId: ref(m.chat.id, m.message_id),
            parentRemoteId: null,
          }),
        );
        continue;
      }
      if (m.chat.id !== s.discussionId) continue;
      // A reply to the channel post's automatic copy in the group is a comment on that post.
      const onPost = replyTo?.is_automatic_forward;
      const postId = replyTo?.forward_origin?.message_id ?? replyTo?.forward_from_message_id;
      items.push(
        inboxItem(account, {
          id: await itemId(account.id, ref(m.chat.id, m.message_id)),
          kind: replyTo && !onPost ? "reply" : "comment",
          context: {
            type: onPost ? "post" : "thread",
            id: String(onPost ? (postId ?? replyTo.message_id) : m.chat.id),
            title: onPost ? clip(replyTo.text ?? replyTo.caption, 80) || "Your post" : (m.chat.title ?? "Group chat"),
            url: onPost && postId ? messageUrl({ id: s.chatId, username: account.handle.startsWith("@") ? account.handle.slice(1) : undefined }, postId) : null,
            thumbnail: null,
          },
          author: author(m.from),
          text,
          at: iso(m.date * 1000),
          remoteId: ref(m.chat.id, m.message_id),
          parentRemoteId: replyTo ? ref(m.chat.id, replyTo.message_id) : null,
        }),
      );
    }
    return { items, content: [], state: { offset } };
  },

  async reply(ctx, account, item, text) {
    const s = await ctx.store.secretOf<TelegramSecret>(account.id);
    const { chatId, messageId } = parseRef(item.remoteId);
    const r = await tg(ctx, s.token, "sendMessage", { chat_id: chatId, text, reply_parameters: { message_id: messageId, allow_sending_without_reply: true } });
    return String(r.message_id);
  },

  async moderate(ctx, account, item, action) {
    if (action !== "delete") throw new PlatformError("Telegram can only delete messages", 400, false, false);
    const s = await ctx.store.secretOf<TelegramSecret>(account.id);
    const { chatId, messageId } = parseRef(item.remoteId);
    await tg(ctx, s.token, "deleteMessage", { chat_id: chatId, message_id: messageId });
  },

  async snapshot(ctx, account) {
    const s = await ctx.store.secretOf<TelegramSecret>(account.id);
    const n = await tg<number>(ctx, s.token, "getChatMemberCount", { chat_id: s.chatId });
    return { followers: n, posts: null, views28d: null };
  },

  async check(ctx, account): Promise<Account> {
    const s = await ctx.store.secretOf<TelegramSecret>(account.id);
    const c = await chatAccount(ctx, s.token, s.botId, s.chatId, account.connectedAt);
    if (c.discussionId !== s.discussionId) await ctx.store.updateAccount(account, { ...s, discussionId: c.discussionId });
    return { ...account, name: c.account.name, handle: c.account.handle, capabilities: c.account.capabilities };
  },
};
