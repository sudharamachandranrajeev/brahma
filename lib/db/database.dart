import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Properties,
    Contacts,
    Interactions,
    Viewings,
    Searches,
    Appraisals,
    Tenancies,
    RentPayments,
    ComplianceItems,
    Areas,
    Vehicles,
    Prefs,
    Outbox,
    SyncCursors,
    LocalSettings,
  ],
)
class AppDatabase extends _$AppDatabase with SyncedDatabase {
  AppDatabase(super.e);

  /// Opens Anveshana's encrypted database (see [openEncryptedDatabase]).
  AppDatabase.open(String key) : this(openEncryptedDatabase('anveshana', key));

  @override
  final syncedTables = const [
    'properties',
    'contacts',
    'interactions',
    'viewings',
    'searches',
    'appraisals',
    'tenancies',
    'rent_payments',
    'compliance_items',
    'areas',
    'vehicles',
    'prefs',
  ];

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      for (final sql in _indexes) {
        await customStatement(sql);
      }
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(vehicles);
    },
  );

  static const _indexes = [
    'CREATE INDEX properties_source ON properties (source, source_id)',
    'CREATE INDEX interactions_property ON interactions (property_id)',
    'CREATE INDEX viewings_property ON viewings (property_id)',
    'CREATE INDEX rent_payments_tenancy ON rent_payments (tenancy_id)',
  ];
}
