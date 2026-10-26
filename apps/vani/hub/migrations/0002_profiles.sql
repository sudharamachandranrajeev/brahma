-- Profiles: separate workspaces on one hub (a person's own accounts, a
-- business, a client). Each row below belongs to one profile; documents
-- (settings, rules, discovery, ideas, run state) are keyed per profile in
-- docs. App credentials stay hub-wide. Existing data becomes "default".

CREATE TABLE profiles (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL
);
INSERT INTO profiles (id, name, created_at) VALUES ('default', 'Main', strftime('%Y-%m-%dT%H:%M:%fZ', 'now'));

ALTER TABLE accounts ADD COLUMN profile TEXT NOT NULL DEFAULT 'default';
ALTER TABLE media ADD COLUMN profile TEXT NOT NULL DEFAULT 'default';
ALTER TABLE posts ADD COLUMN profile TEXT NOT NULL DEFAULT 'default';
ALTER TABLE inbox ADD COLUMN profile TEXT NOT NULL DEFAULT 'default';
ALTER TABLE content ADD COLUMN profile TEXT NOT NULL DEFAULT 'default';
ALTER TABLE alerts ADD COLUMN profile TEXT NOT NULL DEFAULT 'default';

CREATE INDEX inbox_by_profile ON inbox (profile, status, at);
CREATE INDEX alerts_by_profile ON alerts (profile, at);
CREATE INDEX posts_by_profile ON posts (profile, status, scheduled_at);
