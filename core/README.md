# brahma_core

The Flutter package every Brahma app is built on.

- **Encrypted local database.** drift over SQLite3MultipleCiphers; the key
  lives in the system keychain (`KeyVault`).
- **End-to-end encrypted sync** through your own PocketBase server. Rows carry
  hybrid-logical-clock stamps; the server only sees ciphertext (Argon2id,
  HKDF, XChaCha20-Poly1305). One account and one vault serve every app: each
  app reads the shared change log and applies only its own tables.
- **Pairing**: add a device from a QR code or link, any app's scheme.
- **App frame**: the shell with adaptive navigation, hints, settings cards
  (hints, sync, security, about), start-up failure screen, money formatting
  and the shared widgets.

## Using it in an app

```yaml
dependencies:
  brahma_core:
    git:
      url: https://github.com/sudharamachandranrajeev/brahma.git
      path: core
```

During development, point it at a local checkout with a git-ignored
`pubspec_overrides.yaml`:

```yaml
dependency_overrides:
  brahma_core:
    path: ../brahma/core
```

Then:

1. Pick an `AppIdentity` (id, name, Android package) and add its id to
   `brahmaLinkSchemes`.
2. Declare the four sync tables in the app's drift database with the column
   mixins (see the comment in `lib/src/db/synced_database.dart`), mix in
   `SyncedDatabase` and list `syncedTables`. Table names must be unique
   across the suite; only `prefs` is shared, and app pref keys take the app
   id as a prefix.
3. Extend `CoreSession`, and override `coreSessionProvider`,
   `appIdentityProvider` and `hintTextsProvider` at the root.
4. Wrap the home in `LinkHandler` and give `AppShell` the destinations.
