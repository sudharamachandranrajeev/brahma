import 'dart:async';

import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;

import '../db/database.dart';
import '../domain/advisor.dart';
import '../domain/book.dart';
import '../domain/ai.dart';
import '../domain/claude.dart';
import '../domain/gemini.dart';
import '../domain/profile.dart';
import '../domain/refresh.dart';
import '../domain/n8n.dart';
import '../domain/update.dart';
import '../ui/hints.dart';
import 'session.dart';

/// The open session; main() overrides this before the first frame.
final sessionProvider = Provider<AppSession>((ref) => throw StateError('No session'));

/// HTTP for the AI and the job feeds; tests override it.
final httpClientProvider = Provider<http.Client>((ref) => http.Client());

/// The self-updater: main() sets it in a release build of the standalone app.
/// Null in the Brahma suite (which updates itself) and in tests.
final updaterProvider = Provider<Updater?>((ref) => null);

/// A newer release for this device, looked for once a run; null when this
/// is the newest or there is no updater.
final updateProvider = FutureProvider<Release?>((ref) async => ref.watch(updaterProvider)?.check());

/// What main() and the tests override: the session, under both its Udyoga
/// and its shared type, and the app's identity and hints.
List<Override> udyogaOverrides(AppSession session, {http.Client? client, Updater? updater}) => [
  sessionProvider.overrideWithValue(session),
  coreSessionProvider.overrideWithValue(session),
  appIdentityProvider.overrideWithValue(udyogaIdentity),
  hintTextsProvider.overrideWithValue({...coreHints, ...udyogaHints}),
  if (client != null) httpClientProvider.overrideWithValue(client),
  if (updater != null) updaterProvider.overrideWithValue(updater),
];

extension Mutate on WidgetRef {
  /// Runs a write, refreshes the screens and queues a sync.
  Future<T> mutate<T>(Future<T> Function(AppSession s) write) async {
    final result = await write(read(sessionProvider));
    changed();
    return result;
  }
}

/// The rows of [table] that are not deleted, re-read after every write.
FutureProvider<List<D>> _rows<T extends SyncedRow, D>(
  TableInfo<T, D> Function(AppDatabase db) table, {
  List<OrderingTerm Function(T t)> orderBy = const [],
}) => FutureProvider<List<D>>((ref) {
  ref.watch(revisionProvider);
  final db = ref.watch(sessionProvider).db;
  final q = db.select(table(db))
    ..where((t) => t.deleted.not())
    ..orderBy(orderBy);
  return q.get();
});

final jobsProvider = _rows<$JobListingsTable, Job>(
  (db) => db.jobListings,
  orderBy: [(j) => OrderingTerm.desc(j.found), (j) => OrderingTerm.desc(j.fit)],
);

final applicationsProvider = _rows<$JobApplicationsTable, JobApplication>(
  (db) => db.jobApplications,
  orderBy: [(a) => OrderingTerm.desc(a.updated)],
);

final eventsProvider = _rows<$JobEventsTable, JobEvent>(
  (db) => db.jobEvents,
  orderBy: [(e) => OrderingTerm.desc(e.at)],
);

final leadsProvider = _rows<$CareerContactsTable, Lead>(
  (db) => db.careerContacts,
  orderBy: [(c) => OrderingTerm(expression: c.name)],
);

final resumesProvider = _rows<$CareerResumesTable, Resume>(
  (db) => db.careerResumes,
  orderBy: [(r) => OrderingTerm.desc(r.created)],
);

final reportsProvider = _rows<$CareerReportsTable, Report>(
  (db) => db.careerReports,
  orderBy: [(r) => OrderingTerm.desc(r.created)],
);

final growthProvider = _rows<$CareerGrowthTable, GrowthItem>(
  (db) => db.careerGrowth,
  orderBy: [
    (g) => OrderingTerm(expression: g.status),
    (g) => OrderingTerm(expression: g.title),
  ],
);

final practiceProvider = _rows<$CareerPracticeTable, PracticeSession>(
  (db) => db.careerPractice,
  orderBy: [(p) => OrderingTerm.desc(p.started)],
);

final answersProvider = _rows<$CareerAnswersTable, PracticeAnswer>(
  (db) => db.careerAnswers,
  orderBy: [(a) => OrderingTerm(expression: a.question)],
);

final profileProvider = FutureProvider<CandidateProfile>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(sessionProvider).book.profile();
});

/// The newest report of [kind] ('assessment', 'career_map'), or null.
final latestReportProvider = FutureProvider.family<Report?, String>((ref, kind) {
  ref.watch(revisionProvider);
  return ref.watch(sessionProvider).book.latestReport(kind);
});

/// The user's n8n lead workflow (not set until they connect one).
final n8nLinkProvider = FutureProvider<N8nLink>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(sessionProvider).book.n8nLink();
});

/// The adviser with the user's model and its key, or null until a key is set.
final advisorProvider = FutureProvider<Advisor?>((ref) async {
  ref.watch(revisionProvider);
  final s = ref.watch(sessionProvider);
  final keys = await s.book.aiKeys();
  final model = effectiveModel(await s.book.pref<String>(PrefKeys.aiModel, ''), keys);
  if (model == null) return null;
  final key = keys[AiProvider.of(model)]!;
  final client = ref.watch(httpClientProvider);
  void onUsage(AiUsage u) => s.book.addSpend(u, month: today().substring(0, 7)).ignore();
  return Advisor(switch (AiProvider.of(model)) {
    AiProvider.claude => Claude(apiKey: key, model: model, client: client, onUsage: onUsage),
    AiProvider.gemini => Gemini(apiKey: key, model: model, client: client, onUsage: onUsage),
  }, today: today());
});

/// The adviser, or an error telling the user to add a key.
Future<Advisor> requireAdvisor(WidgetRef ref) async {
  final advisor = await ref.read(advisorProvider.future);
  if (advisor == null) throw AiException(needsAiKey);
  return advisor;
}

class RefreshState {
  const RefreshState({this.running = false, this.status = '', this.last});
  final bool running;
  final String status;
  final RefreshReport? last;
}

/// The routine refresh (see Refresher), run at start-up, every few hours
/// while the app is open, and from the Jobs page.
class RefreshController extends Notifier<RefreshState> {
  @override
  RefreshState build() => const RefreshState();

  Future<RefreshReport?> run({bool force = false, bool ai = false}) async {
    if (state.running) return null;
    state = RefreshState(running: true, status: 'Starting…', last: state.last);
    try {
      final s = ref.read(sessionProvider);
      final report =
          await Refresher(
            s.book,
            ref.read(httpClientProvider),
            advisor: await ref.read(advisorProvider.future),
          ).run(
            today: today(),
            force: force,
            ai: ai,
            onProgress: (m) => state = RefreshState(running: true, status: m, last: state.last),
          );
      state = RefreshState(last: report);
      ref.read(revisionProvider.notifier).bump();
      return report;
    } catch (e) {
      state = RefreshState(status: describeError(e), last: state.last);
      rethrow;
    }
  }
}

final refreshProvider = NotifierProvider<RefreshController, RefreshState>(RefreshController.new);

/// Runs the routine refresh now and then hourly while the app is open;
/// each run does only what is due. Read once at start-up.
final refreshTickerProvider = Provider<void>((ref) {
  void tick() => ref.read(refreshProvider.notifier).run().catchError((_) => null).ignore();
  tick();
  final timer = Timer.periodic(const Duration(hours: 1), (_) => tick());
  ref.onDispose(timer.cancel);
});
