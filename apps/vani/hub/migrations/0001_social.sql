-- Social hub. Most rows are JSON documents (the API's shapes) with the
-- columns queries filter or sort on pulled out beside them.

CREATE TABLE accounts (
  id TEXT PRIMARY KEY,
  platform TEXT NOT NULL,
  remote_id TEXT NOT NULL,
  body TEXT NOT NULL,          -- Account JSON
  secret TEXT NOT NULL,        -- sealed tokens (crypto.ts)
  poll_state TEXT,             -- adapter's cursor JSON
  polled_at TEXT,
  UNIQUE (platform, remote_id)
);

CREATE TABLE credentials (
  provider TEXT PRIMARY KEY,
  public_id TEXT,
  secret TEXT NOT NULL,        -- sealed
  updated_at TEXT NOT NULL
);

CREATE TABLE media (
  id TEXT PRIMARY KEY,
  body TEXT NOT NULL,          -- Media JSON without url
  upload_id TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE posts (
  id TEXT PRIMARY KEY,
  body TEXT NOT NULL,          -- Post JSON
  status TEXT NOT NULL,
  scheduled_at TEXT,
  updated_at TEXT NOT NULL,
  lock_until TEXT              -- set while a run publishes it
);
CREATE INDEX posts_due ON posts (status, scheduled_at);

CREATE TABLE inbox (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  platform TEXT NOT NULL,
  kind TEXT NOT NULL,
  status TEXT NOT NULL,
  at TEXT NOT NULL,
  body TEXT NOT NULL           -- InboxItem JSON
);
CREATE INDEX inbox_by_time ON inbox (status, at);

CREATE TABLE content (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  at TEXT NOT NULL,
  body TEXT NOT NULL           -- Content JSON
);
CREATE INDEX content_by_account ON content (account_id, at);

CREATE TABLE alerts (
  id TEXT PRIMARY KEY,
  at TEXT NOT NULL,
  read INTEGER NOT NULL DEFAULT 0,
  body TEXT NOT NULL           -- Alert JSON
);
CREATE INDEX alerts_by_time ON alerts (at);

-- What each discovery watch has already seen, so only new finds alert.
CREATE TABLE seen (
  watch_id TEXT NOT NULL,
  item_id TEXT NOT NULL,
  at TEXT NOT NULL,
  PRIMARY KEY (watch_id, item_id)
);

CREATE TABLE stats (
  account_id TEXT NOT NULL,
  day TEXT NOT NULL,
  followers INTEGER,
  body TEXT NOT NULL,          -- {posts, views28d}
  PRIMARY KEY (account_id, day)
);

-- Small JSON documents: settings, rules, discovery, ideas, run state.
CREATE TABLE docs (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
