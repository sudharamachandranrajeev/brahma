import 'package:brahma_core/brahma_core.dart';

import '../db/database.dart';
import '../domain/book.dart';

/// Udyoga in Brahma's terms: the app's id, name and Android package.
const udyogaIdentity = AppIdentity(id: 'udyoga', name: 'Udyoga', androidPackage: 'dev.brahma.udyoga');

/// Everything a running app needs: keys, the encrypted database and the
/// career book on top of it. Opened once at start-up.
class AppSession extends CoreSession {
  AppSession(super.keys, super.store, this.book, {super.deviceName});

  final CareerBook book;

  @override
  AppDatabase get db => store.db as AppDatabase;

  static Future<AppSession> open(KeyVault keys) => CoreSession.open(
    udyogaIdentity,
    keys,
    openDatabase: AppDatabase.open,
    build: (store, deviceName) => AppSession(keys, store, CareerBook(store), deviceName: deviceName),
  );
}
