import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    LearnPrograms,
    LearnCourses,
    LearnTopics,
    LearnSessions,
    LearnAssessments,
    LearnSkills,
    LearnPortfolio,
    LearnNotes,
    LearnUnlocks,
    Prefs,
    Outbox,
    SyncCursors,
    LocalSettings,
  ],
)
class AppDatabase extends _$AppDatabase with SyncedDatabase {
  AppDatabase(super.e);

  /// Opens Vidya's encrypted database (see [openEncryptedDatabase]).
  AppDatabase.open(String key) : this(openEncryptedDatabase('vidya', key));

  @override
  final syncedTables = const [
    'learn_programs',
    'learn_courses',
    'learn_topics',
    'learn_sessions',
    'learn_assessments',
    'learn_skills',
    'learn_portfolio',
    'learn_notes',
    'learn_unlocks',
    'prefs',
  ];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      for (final sql in _indexes) {
        await customStatement(sql);
      }
    },
  );

  static const _indexes = [
    'CREATE INDEX learn_courses_program ON learn_courses (program_id)',
    'CREATE INDEX learn_topics_course ON learn_topics (course_id)',
    'CREATE INDEX learn_sessions_day ON learn_sessions (day)',
  ];
}
