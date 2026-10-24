import 'package:brahma_core/brahma_core.dart';

import '../db/database.dart';

/// The suite app in Brahma's terms.
const brahmaIdentity = AppIdentity(id: 'brahma', name: 'Brahma', androidPackage: 'dev.brahma.app');

/// The suite's own session (its local settings and the sync account) and
/// one open session per hosted app, in [apps] order.
class SuiteSession {
  SuiteSession(this.hub, this.apps, this.sessions);

  final CoreSession hub;
  final List<SuiteApp> apps;
  final List<CoreSession> sessions;

  /// Opens the suite's database, then every app's own, all with keys from
  /// one vault: one keychain entry and one sign-in for the whole suite.
  /// The databases live in the suite app's own data folder, apart from the
  /// standalone apps', which keep working side by side with it.
  static Future<SuiteSession> open(KeyVault keys, List<SuiteApp> apps) async {
    final hub = await CoreSession.open(
      brahmaIdentity,
      keys,
      openDatabase: HubDatabase.open,
      build: (store, deviceName) => CoreSession(keys, store, deviceName: deviceName),
    );
    final sessions = <CoreSession>[];
    try {
      for (final app in apps) {
        sessions.add(await app.open(keys));
      }
    } catch (_) {
      for (final s in [hub, ...sessions]) {
        await s.db.close();
      }
      rethrow;
    }
    return SuiteSession(hub, apps, sessions);
  }

  Future<void> close() async {
    for (final s in [hub, ...sessions]) {
      await s.db.close();
    }
  }
}
