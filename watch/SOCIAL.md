# Social hub

The social side of Brahma Watch: connected accounts, publishing and
scheduling, a unified inbox, rules, discovery alerts and stats. Vani (the
Flutter app) is its client. The Worker holds the platform tokens, so posts go
out and replies come in while every device is off.

Data lives in D1 (`DB`), media in R2 (`MEDIA`). Tokens and provider secrets
are encrypted with AES-GCM under the `TOKEN_KEY` Worker secret before they
reach D1. Shapes are in `src/social/types.ts`.

## Schedule

The cron runs every minute:

- every minute: publish due posts;
- every 10 minutes: property watches, inbox polling (round robin within the
  subrequest budget), discovery watches that are due;
- 03:05 UTC: token refresh, account checks (expiry warnings 7 days ahead,
  broken tokens), follower snapshots, fresh ideas, pruning.

Each run may make `SUBREQUEST_BUDGET` outbound requests (45 by default, for
the Workers free plan's 50). Polling and discovery stop cleanly when it runs
out and carry on next time. With several accounts, Workers Paid ($5/month)
and a budget of 900 keep everything prompt; the free plan's 10 ms CPU limit
can also cut long runs short.

Meta webhooks (`/webhooks/meta`, `/webhooks/threads`) poll the account they
name at once, so Instagram/Facebook/Threads replies arrive within seconds.

## API

Every `/social/*` call needs `Authorization: Bearer $API_TOKEN`. Errors are
`{ "error": "...", "problems"?: ["..."] }` with a 4xx/5xx status.

| Call | Body → answer |
|---|---|
| `GET /social/overview` | Home in one call: `{accounts, stats, inbox: {new, read}, upcoming: Post[], alerts: Alert[], recentInbox: InboxItem[], topContent: Content[], ideas}` |
| `GET /social/meta` | `{platforms: {[Platform]: PlatformInfo}, redirectUris: {[Provider]: url}, webhookUrl, threadsWebhookUrl, verifyToken, ai: boolean}` |
| `GET /social/credentials` | `CredentialStatus[]` |
| `PUT /social/credentials/:provider` | `{publicId?, secret}` (meta/threads: app id + secret; google/linkedin/ebay: client id + secret; anthropic: `secret` = API key) |
| `DELETE /social/credentials/:provider` | |
| `GET /social/accounts` | `Account[]` |
| `POST /social/connect/:provider` | → `{url}`: open it in a browser; the callback stores the accounts |
| `POST /social/accounts/bluesky` | `{handle, appPassword, service?}` → `Account` |
| `POST /social/accounts/mastodon` | `{instance, accessToken}` → `Account` |
| `POST /social/accounts/:id/check` | → `Account` (re-verifies the token) |
| `DELETE /social/accounts/:id` | |
| `GET /social/media` | `Media[]` |
| `POST /social/media` | `{filename, contentType, size}` → `{media, partSize}` |
| `PUT /social/media/:id/parts/:n` | raw bytes of part n (1-based, `partSize` each but the last) → `{etag}` |
| `POST /social/media/:id/complete` | `{parts: [{n, etag}]}` → `Media` |
| `DELETE /social/media/:id` | |
| `GET /social/posts?from&to&status` | `Post[]` (from/to filter `scheduledAt`, or `updatedAt` when unscheduled) |
| `POST /social/posts` | `PostInput` → `Post` |
| `PUT /social/posts/:id` | `PostInput` → `Post` (not while publishing or after publishing) |
| `DELETE /social/posts/:id` | |
| `POST /social/posts/:id/publish` | → `Post` (now) |
| `POST /social/posts/:id/retry` | `{force?}` → `Post` (failed targets; `force` also retries ones that may have posted) |
| `GET /social/inbox?status&platform&kind&accountId&before&limit` | → `{items: InboxItem[], counts: {new, read, done}}`; status `open` = new + read |
| `PATCH /social/inbox/:id` | `{status}` → `InboxItem` |
| `POST /social/inbox/bulk` | `{ids, status}` |
| `POST /social/inbox/:id/reply` | `{text, private?}` → `InboxItem` |
| `POST /social/inbox/:id/suggest` | → `{suggestions: string[]}` |
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

## Claude

AI features (captions, reply suggestions, rule descriptions, discovery
matching, ideas, watch drafts) use the owner's Anthropic API key, stored like
the other credentials. The model is `Settings.model` (default
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
