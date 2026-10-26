# Changelog

## Unreleased

- Set up your own hub from Vani: a guided setup (Settings > Social hub > Set up a hub, on Windows or
  Linux) takes you through a free Cloudflare account, R2 and a key, then deploys the hub, with no
  terminal. It ends with a QR code: scan it with your phone's camera and Vani on the phone connects.
- The hub is Vani's own now (`hub/`, deployed as `vani-hub`), no longer part of Brahma Watch. Hubs made
  with Brahma Watch's `npm run setup` are not carried over: set up the new one and reconnect accounts.
- Update hub: Settings shows the hub's version and updates it when Vani has a newer one, keeping its
  secrets and data.
- Connect hub also takes a pasted `vani://hub` link.
- AI from any service: Settings > AI takes an API key for Anthropic, OpenAI, Google Gemini (free tier),
  OpenRouter or any OpenAI-compatible service, lists the models the key can use, and lets the hub use
  the one you pick. On Windows and Linux you can instead answer AI requests with your own Claude,
  ChatGPT or Gemini plan through its official command-line app (Claude Code, Codex CLI, Gemini CLI), or
  with Ollama, while Vani is open. Vani never signs in to those plans or holds their tokens.
- Every platform from day one. Bluesky, Mastodon and Telegram connect at once; Facebook & Instagram,
  Threads, YouTube and LinkedIn open a step-by-step guide to making your own free app, with the exact
  console pages, the addresses to paste and a Copy button, then check the app's keys with the platform
  before saving them and end with "Sign in".
- Mastodon in one click: enter your server and sign in there; the hub registers itself on the server.
  An access token still works.

## 0.2.0 (2026-10-25)

First public release, with everything built so far.

- Profiles: switch profile and the whole app follows it on this device, for different people or uses.
  Pick one from the rail or the More sheet; add, rename and remove them in Settings > Profiles.
- Telegram: connect a bot to a channel or group to post there and read its messages.
- Alt text on images, written by you or drafted by Claude.
- Inbox: Claude tags new items by mood, priority and language (filter by mood or "urgent"),
  translates them into your language and translates your reply into theirs. Hide or delete comments
  where the platform allows it (Instagram, Facebook, YouTube hide, Telegram delete).
- Alerts: a short AI summary of the week every Monday, and an inbox language setting.
- Brahma suite: Vani joins the Brahma app with a home card (scheduled posts, new inbox items, unread
  alerts).

## 0.1.0 (2026-10-24)

- All-in-one social media manager for Instagram, Facebook Pages, YouTube, LinkedIn, Threads, Bluesky
  and Mastodon, on Linux, Windows and Android, talking to your own Brahma Watch hub.
- Home: followers, views, replies, account health, top content, AI ideas and what is up next.
- Compose: one post to many accounts with per-account wording and format, live character counts,
  uploads and a media library, AI captions and hashtags; post now, schedule, queue or save a draft.
- Calendar: month and week views, drag a post to another day to reschedule, retry failed posts.
- Inbox: comments, replies, DMs, mentions and live chat in one place, with filters, bulk actions,
  inline and private replies, saved replies and AI suggestions.
- Alerts: describe what you want in plain English and Claude drafts a discovery watch; inbox rules
  alert or auto-reply on keywords.
- Accounts (OAuth and app credentials), Analytics and Settings. Dark-first design with a light theme.
