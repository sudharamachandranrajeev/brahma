import 'package:brahma_core/brahma_core.dart';

import '../db/database.dart';
import '../domain/book.dart';

/// Bhojana in Brahma's terms: the app's id, name and Android package.
const bhojanaIdentity = AppIdentity(
  id: 'bhojana',
  name: 'Bhojana',
  androidPackage: 'dev.brahma.bhojana',
  releases: 'sudharamachandranrajeev/bhojana',
);

/// Everything a running app needs: keys, the encrypted database and the
/// shopping book on top of it. Opened once at start-up.
class AppSession extends CoreSession {
  AppSession(super.keys, super.store, this.book, {super.deviceName});

  final ShoppingBook book;

  @override
  AppDatabase get db => store.db as AppDatabase;

  static Future<AppSession> open(KeyVault keys) => CoreSession.open(
    bhojanaIdentity,
    keys,
    openDatabase: AppDatabase.open,
    build: (store, deviceName) => AppSession(keys, store, ShoppingBook(store), deviceName: deviceName),
  );
}
