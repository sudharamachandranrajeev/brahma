import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:vani/db/database.dart';

/// A fresh in-memory database (the bundled SQLite3MultipleCiphers works
/// unkeyed in memory).
AppDatabase memoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}
