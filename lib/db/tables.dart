import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

// Vani keeps its posts, inbox and alerts on the social hub (the hub has to
// act while every device is off), so the device database holds only the
// shared tables: synced prefs (the hub link, your name) and sync's own
// bookkeeping.

@DataClassName('Pref')
class Prefs extends Table with SyncedRow, PrefColumns {}

@DataClassName('OutboxItem')
class Outbox extends Table with OutboxColumns {}

@DataClassName('SyncCursor')
class SyncCursors extends Table with SyncCursorColumns {}

@DataClassName('LocalSetting')
class LocalSettings extends Table with LocalSettingColumns {}
