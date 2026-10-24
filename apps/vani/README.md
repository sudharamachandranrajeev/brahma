# Vani

Vani ("voice") is the Brahma social media manager: one app to post, schedule and answer across
Instagram, Facebook, YouTube, LinkedIn, Threads, Bluesky and Mastodon, plus alerts for what you are
looking for (car listings near you, Instagram shops selling a kind of thing...).

It is a Flutter app for Linux, Windows and Android built on `brahma_core`. The work that has to happen
while your devices are off runs on your own hub, Brahma Watch (`brahma/watch`, a Cloudflare Worker):
it holds the platform tokens, publishes on schedule, collects comments, messages, mentions and live
chat, runs discovery watches and pushes alerts to your phone. The API is described in
`brahma/watch/SOCIAL.md`.

## What it does

- **Home**: followers, views, replies and account health at a glance, top content, AI ideas, what is
  up next, today's activity and alerts.
- **Compose**: one post to many accounts with per-account wording, format (post, carousel, reel, story,
  video, short), YouTube title and first comment; live character counts per platform; uploads with
  progress and a media library; AI captions and hashtags; post now, schedule, add to the queue or
  save a draft; recycle evergreen posts.
- **Calendar**: month and week views; drag a post to another day to reschedule; failed posts with
  retry, drafts.
- **Inbox**: every comment, reply, DM, mention and live chat message in one place; filters, bulk
  actions, inline replies, private replies to comments, saved replies with `{name}` and AI
  suggestions.
- **Alerts**: describe what you want in plain English and Claude drafts a discovery watch over eBay,
  DoneDeal, Instagram hashtags and business accounts, Bluesky and YouTube; you check it before saving.
  Inbox rules alert or auto-reply on keywords.
- **Accounts**: connect with OAuth (Meta, Threads, Google, LinkedIn), a Bluesky app password or a
  Mastodon token; token health and reconnect; app credentials with the redirect URIs and webhooks to
  paste into each developer console.
- **Analytics**: follower growth, best times to post, per-account numbers and top content.
- **Settings**: the hub address and token (synced end-to-end encrypted between your devices), the
  posting queue, saved replies, AI model, theme.

AI features need an Anthropic API key, stored on the hub (Accounts > App credentials).

## Develop

```sh
flutter pub get
flutter analyze
flutter test
VANI_SHOTS=/tmp/vani-shots flutter test test/screenshots_test.dart   # renders the main pages to PNG
scripts/make-icons.sh                                                # after editing branding/vani.svg
```

The tests run the whole app against an in-memory fake hub (`test/fake_hub.dart`) seeded with made-up
data; nothing leaves the machine.
