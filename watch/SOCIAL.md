# Social hub

The social side of Brahma Watch: connected accounts, publishing and
scheduling, a unified inbox, rules, discovery alerts and stats. Vani (the
Flutter app) is its client. The Worker holds the platform tokens, so posts go
out and replies come in while every device is off.

Data lives in D1 (`DB`), media in R2 (`MEDIA`). Tokens and provider secrets
are encrypted with AES-GCM under the `TOKEN_KEY` Worker secret before they
reach D1. Shapes are in `src/social/types.ts`.

## Profiles

One hub holds several profiles: separate workspaces for, say, your own
accounts, a business and a client. Each profile has its own accounts, posts,
media, inbox, content, stats, alerts, rules, discovery watches, settings and
ideas. App credentials (Meta, Google, LinkedIn, Threads, eBay apps and the
Anthropic key) belong to the hub and serve every profile.

An API call works in the profile named by its `x-vani-profile` header, or in
the main profile (`default`) without one; an unknown id is a 404. Profiles
share the bearer token, so they keep things apart for convenience, not
security: anyone with the token can open every profile.

An account is in one profile at a time. Connecting it in another is refused
(409); a Meta sign-in that brings several Pages adds the ones that aren't
already elsewhere. OAuth sign-ins land in the profile they started in.
Pushes go to the one ntfy topic; with more than one profile their title
starts with the profile's name.

Deleting a profile needs its accounts removed first, then deletes its posts,
media (R2 files too), inbox, alerts and documents. The main profile can't be
deleted. Data from before profiles existed is in the main profile.

## Schedule

The cron runs every minute:

Each pass goes through every profile on one shared budget, starting from a
different profile every 10 minutes.

- every minute: publish due posts;
- every 10 minutes: property watches, inbox polling (round robin within the
  subrequest budget), discovery watches that are due;
- 03:05 UTC: token refresh, account checks (expiry warnings 7 days ahead,
  broken tokens), follower snapshots, fresh ideas, pruning; on Mondays the
  weekly summary (a `summary` alert, pushed like the others).

Each run may make `SUBREQUEST_BUDGET` outbound requests (45 by default, for
the Workers free plan's 50). Polling and discovery stop cleanly when it runs
out and carry on next time. With several accounts, Workers Paid ($5/month)
and a budget of 900 keep everything prompt; the free plan's 10 ms CPU limit
can also cut long runs short.

Meta webhooks (`/webhooks/meta`, `/webhooks/threads`) poll the account they
name at once, so Instagram/Facebook/Threads replies arrive within seconds.

## API

Every `/social/*` call needs `Authorization: Bearer $API_TOKEN`, and works
in the profile named by `x-vani-profile` (see Profiles). Errors are
`{ "error": "...", "problems"?: ["..."] }` with a 4xx/5xx status.

| Call | Body → answer |
|---|---|
| `GET /social/overview` | Home in one call: `{accounts, stats, inbox: {new, read}, upcoming: Post[], alerts: Alert[], recentInbox: InboxItem[], topContent: Content[], ideas}` |
| `GET /social/meta` | `{platforms: {[Platform]: PlatformInfo}, redirectUris: {[Provider]: url}, webhookUrl, threadsWebhookUrl, verifyToken, ai: boolean}` |
| `GET /social/credentials` | `CredentialStatus[]` |
| `PUT /social/credentials/:provider` | `{publicId?, secret}` (meta/threads: app id + secret; google/linkedin/ebay: client id + secret; anthropic: `secret` = API key) |
| `DELETE /social/credentials/:provider` | |
| `GET /social/profiles` | `Profile[]` (`{id, name, createdAt}`; `default` is the main one). Profile routes ignore `x-vani-profile` |
| `POST /social/profiles` | `{name}` (1–40 characters, unique) → `Profile` |
| `PATCH /social/profiles/:id` | `{name}` → `Profile` |
| `DELETE /social/profiles/:id` | 409 while it has accounts, or for `default` |
| `GET /social/accounts` | `Account[]` |
| `POST /social/connect/:provider` | → `{url}`: open it in a browser; the callback stores the accounts |
| `POST /social/accounts/bluesky` | `{handle, appPassword, service?}` → `Account` |
| `POST /social/accounts/mastodon` | `{instance, accessToken}` → `Account` |
| `POST /social/accounts/telegram` | `{botToken, chat}` (`@channel`, a t.me link or a chat id) → `Account` |
| `POST /social/accounts/:id/check` | → `Account` (re-verifies the token) |
| `DELETE /social/accounts/:id` | |
| `GET /social/media` | `Media[]` |
| `POST /social/media` | `{filename, contentType, size}` → `{media, partSize}` |
| `PUT /social/media/:id/parts/:n` | raw bytes of part n (1-based, `partSize` each but the last) → `{etag}` |
| `POST /social/media/:id/complete` | `{parts: [{n, etag}]}` → `Media` |
| `PATCH /social/media/:id` | `{alt}` → `Media` (`""` removes the alt text) |
| `POST /social/media/:id/alt` | `{context?}` (the post's text) → `Media` with alt text drafted by Claude (JPEG, PNG, WebP, GIF) |
| `DELETE /social/media/:id` | |
| `GET /social/posts?from&to&status` | `Post[]` (from/to filter `scheduledAt`, or `updatedAt` when unscheduled) |
| `POST /social/posts` | `PostInput` → `Post` |
| `PUT /social/posts/:id` | `PostInput` → `Post` (not while publishing or after publishing) |
| `DELETE /social/posts/:id` | |
| `POST /social/posts/:id/publish` | → `Post` (now) |
| `POST /social/posts/:id/retry` | `{force?}` → `Post` (failed targets; `force` also retries ones that may have posted) |
| `GET /social/inbox?status&platform&kind&accountId&triage&before&limit` | → `{items: InboxItem[], counts: {new, read, done}}`; status `open` = new + read; triage is a mood or `urgent` (high priority) |
| `PATCH /social/inbox/:id` | `{status}` → `InboxItem` |
| `POST /social/inbox/bulk` | `{ids, status}` |
| `POST /social/inbox/:id/reply` | `{text, private?}` → `InboxItem` |
| `POST /social/inbox/:id/suggest` | → `{suggestions: string[]}` |
| `POST /social/inbox/:id/translate` | → `InboxItem` with `translation` (into `Settings.language`; kept until that changes) |
| `POST /social/inbox/:id/moderate` | `{action: hide \| unhide \| delete}` → `InboxItem` (comments and replies; `PlatformInfo.moderation` says which actions a platform has) |
| `POST /social/inbox/refresh` | → `{polled, items}` |
| `GET /social/content?accountId&limit` | `Content[]` newest first |
| `GET /social/rules`, `PUT /social/rules` | `InboxRule[]` |
| `GET /social/discovery`, `PUT /social/discovery` | `DiscoveryWatch[]` |
| `POST /social/discovery/suggest` | `{description, postcode?}` → `DiscoveryWatch` (unsaved draft) |
| `POST /social/discovery/:id/run` | → `{finds: Find[], alerts: Alert[], errors: string[]}` |
| `GET /social/alerts?since&unread` | `Alert[]` newest first (last 500) |
| `POST /social/alerts/read` | `{ids?: string[]}` (none = all) |
| `GET /social/stats` | `Stats` |
| `GET /social/settings`, `PUT /social/settings` | `Settings` |
| `POST /social/ai/caption` | `{brief, platforms, tone?}` → `{variants: {[Platform]: text}, hashtags}` |
| `GET /social/ai/ideas` | → `{ideas: {kind, title, body}[], generatedAt}` |
| `POST /social/ai/translate` | `{text, to}` (a language name) → `{lang, text}` |
| `POST /social/ai/weekly` | → `Alert`: the weekly summary now (also pushed) |

`PostInput` is `{text, media, targets: [{accountId, format, text?, title?,
firstComment?}], scheduledAt: ISO | null, queue?: boolean, draft?: boolean,
recycleDays?, tags?}`. `queue: true` takes the next free queue slot;
`draft: true` keeps it unscheduled; otherwise `scheduledAt: null` publishes
on the next minute.

Rules (`InboxRule`) match a new item when any keyword appears, or when
Claude judges that it meets the rule's description. A rule with neither
matches everything on its accounts (a welcome reply). Rules act only on items
from the last 24 hours, and never on the history a first poll brings in.
Public and private replies are both sent when a rule has both.

With AI on, each poll tags new items from the last 7 days with
`triage: {mood, priority, lang}` (mood: positive, neutral, question,
complaint, spam; priority: high, normal, low), up to 60 per poll. Untagged
items simply have no `triage`.

Alt text (`Media.alt`) goes out on Instagram and Threads images, Facebook
photos, Bluesky, Mastodon and LinkedIn images. YouTube and Telegram have no
alt text.

Discovery watches need every keyword in a find. A watch's first run records
what is there without alerting; later runs alert on new finds (with `ai` on,
only those Claude matches with a score of 0.5 or more), up to 8 per run. A
source that starts failing raises one system alert, not one per run. YouTube
searches run at most hourly (each costs 100 of the 10,000 daily quota units).

Unauthenticated: `GET /oauth/:provider/callback` (OAuth return, checks the
one-time state), `GET|POST /webhooks/meta|threads` (verify token / signed
payloads), `GET /media/:id?exp&sig` (signed media for platforms to fetch).

## What platforms allow

- Instagram: Business or Creator accounts linked to a Facebook Page. Posts,
  carousels, reels and stories; comments on posts, reels and lives; DMs and
  story replies; private replies to comments.
- Facebook: Pages only (no personal profiles). Posts, photos, videos;
  comments and Messenger conversations. Marketplace has no API.
- YouTube: videos and Shorts; comment threads; live chat of active streams.
- LinkedIn: posting to your profile is self-serve. Reading comments needs
  the Community Management API, which LinkedIn approves per app.
- Threads, Bluesky, Mastodon: posts and replies.
- Telegram: posts to a channel or group (text up to 4096 characters, or
  photos and videos with a caption up to 1024; photos up to 5 MB and videos
  up to 20 MB, as Telegram fetches them by URL). Comments from the channel's
  discussion group and messages people send the bot; replies; deleting
  comments. No alt text, first comments or post stats.
- Hiding comments: Instagram, Facebook and YouTube (held for review).
  Deleting other people's comments: Instagram, Facebook and Telegram.

## Claude

AI features (captions, alt text, reply suggestions, inbox triage,
translation, rule descriptions, discovery matching, ideas, the weekly
summary, watch drafts) use the owner's Anthropic API key, stored like the
other credentials. The model is `Settings.model` (default
`claude-opus-5-5`). Requests enable server-side fallbacks
(`server-side-fallback-2026-07-01`, `fallbacks: "default"`), so if the model
is overloaded Anthropic may answer with its default fallback model instead of
failing. Answers are structured JSON checked with zod before anything acts
on them; text from posts and listings is passed as data, never as
instructions.

## Connecting platforms

Each provider needs an app of your own (Vani's Accounts page shows the
redirect URI to register):

- Meta (Facebook Pages + Instagram): a Meta app with Facebook Login for
  Business; add the permissions in `platforms/meta.ts`. Until App Review,
  only people with a role on the app can connect. Webhooks: subscribe the
  app to `page` and `instagram` with `webhookUrl` and `verifyToken`.
- Threads: a Threads app (separate app id and secret).
- Google (YouTube): an OAuth client of type Web application with the
  YouTube Data API enabled. Publish the consent screen to production:
  apps left in Testing get refresh tokens that expire after 7 days.
- LinkedIn: an app with "Sign In with LinkedIn using OpenID Connect" and
  "Share on LinkedIn". Comments need the Community Management API.
- eBay (discovery): a production keyset (client id + secret).
- Bluesky: an app password. Mastodon: an access token from your
  instance's Development settings (scopes read and write).
- Telegram: a bot from @BotFather. Add it as an admin of the channel (with
  "Post messages"), and as an admin of the channel's discussion group to
  collect comments. One bot per connected chat: the hub reads its updates
  with `getUpdates`, so the bot must not have a webhook.
