-- Brahma sync server. It stores only ciphertext and wrapped keys; e-mail
-- addresses and a hash of the derived login secret are the only readable data.
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  secret_hash TEXT NOT NULL,
  tokver INTEGER NOT NULL DEFAULT 1,
  is_owner INTEGER NOT NULL DEFAULT 0,
  created TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS vaults (
  owner_id TEXT PRIMARY KEY,
  wrapped_password TEXT NOT NULL,
  wrapped_recovery TEXT NOT NULL,
  version INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS devices (
  owner_id TEXT NOT NULL,
  device TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT '',
  created TEXT NOT NULL,
  PRIMARY KEY (owner_id, device)
);
-- Append-only log of encrypted changes, one numbered stream per device.
CREATE TABLE IF NOT EXISTS changes (
  owner_id TEXT NOT NULL,
  device TEXT NOT NULL,
  seq INTEGER NOT NULL,
  payload TEXT NOT NULL,
  created TEXT NOT NULL,
  PRIMARY KEY (owner_id, device, seq)
);
CREATE TABLE IF NOT EXISTS pairings (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  expires INTEGER NOT NULL,
  request TEXT NOT NULL DEFAULT '',
  response TEXT NOT NULL DEFAULT ''
);
-- One-time codes, stored hashed: invite (join), reset (new login secret).
CREATE TABLE IF NOT EXISTS codes (
  hash TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  user_id TEXT NOT NULL DEFAULT '',
  expires INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS rate (
  key TEXT PRIMARY KEY,
  window INTEGER NOT NULL,
  n INTEGER NOT NULL
);
