import 'package:brahma_core/brahma_core.dart';

import '../db/database.dart';
import '../domain/prefs.dart';

/// Vani in Brahma's terms: the app's id, name and Android package.
const vaniIdentity = AppIdentity(id: 'vani', name: 'Vani', androidPackage: 'dev.brahma.vani');

/// Everything a running app needs: keys, the encrypted database and the
/// prefs on top of it. Opened once at start-up.
class AppSession extends CoreSession {
  AppSession(super.keys, super.store, this.prefs, {super.deviceName});

  final VaniPrefs prefs;

  @override
  AppDatabase get db => store.db as AppDatabase;

  static Future<AppSession> open(KeyVault keys) => CoreSession.open(
    vaniIdentity,
    keys,
    openDatabase: AppDatabase.open,
    build: (store, deviceName) => AppSession(keys, store, VaniPrefs(store), deviceName: deviceName),
  );
}
