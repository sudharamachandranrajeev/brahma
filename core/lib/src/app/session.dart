import 'dart:io';

import '../db/store.dart';
import '../db/synced_database.dart';
import '../identity.dart';
import '../security/key_vault.dart';
import '../sync/account_service.dart';
import 'links.dart';

/// What every Brahma app's session holds: keys, the encrypted database, the
/// write path and the sync account. Apps extend it with their own services.
class CoreSession {
  CoreSession(this.keys, this.store, {String deviceName = ''})
    : account = AccountService(
        keys,
        deviceId: store.deviceId,
        deviceName: deviceName,
        platform: Platform.operatingSystem,
      );

  final KeyVault keys;
  final Store store;
  SyncedDatabase get db => store.db;

  /// Sync account. The device name goes only into sealed pairing requests:
  /// the server keeps its device list in clear, so that stays nameless.
  final AccountService account;

  /// Opens [app]'s encrypted database with its key from the keychain and
  /// hands the store and device name to [build], which makes the app's
  /// session. A wrong key or a build without encryption fails here, at
  /// start-up, rather than on the first screen.
  static Future<S> open<S extends CoreSession, D extends SyncedDatabase>(
    AppIdentity app,
    KeyVault keys, {
    required D Function(String key) openDatabase,
    required S Function(Store store, String deviceName) build,
  }) async {
    final exists = await (await databaseFile(app.id)).exists();
    final db = openDatabase(await keys.databaseKey(create: !exists));
    try {
      final store = await Store.open(db);
      return build(store, await PlatformLinks(app).deviceName());
    } catch (_) {
      await db.close();
      rethrow;
    }
  }
}
