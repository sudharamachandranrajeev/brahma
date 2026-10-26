import 'package:brahma_core/brahma_core.dart';

import '../db/database.dart';
import '../domain/book.dart';

/// Vahana in Brahma's terms: the app's id, name and Android package.
const vahanaIdentity = AppIdentity(
  id: 'vahana',
  name: 'Vahana Anveshana',
  androidPackage: 'dev.brahma.vahana',
  releases: 'sudharamachandranrajeev/vahana-anveshana',
);

/// Everything a running app needs: keys, the encrypted database and the
/// car book on top of it. Opened once at start-up.
class AppSession extends CoreSession {
  AppSession(super.keys, super.store, this.book, {super.deviceName});

  final CarBook book;

  @override
  AppDatabase get db => store.db as AppDatabase;

  static Future<AppSession> open(KeyVault keys) => CoreSession.open(
    vahanaIdentity,
    keys,
    openDatabase: AppDatabase.open,
    build: (store, deviceName) => AppSession(keys, store, CarBook(store), deviceName: deviceName),
  );
}
