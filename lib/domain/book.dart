import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

import '../db/database.dart';
import 'claude.dart';
import 'feeds.dart';
import 'insights.dart';
import 'json.dart';
import 'matching.dart';
import 'pipeline.dart';
import 'profile.dart';
import 'resume.dart';

/// Pref keys. The prefs table is shared by every Brahma app, so Udyoga's
/// keys carry its prefix.
abstract final class PrefKeys {
  static const profile = 'udyoga.profile';
  static const aiKey = 'udyoga.ai.key';
  static const aiModel = 'udyoga.ai.model';

  /// How often the AI looks for jobs and refreshes the career map on its own:
  /// off | weekly | daily.
  static const aiRoutine = 'udyoga.ai.routine';
  static const feedKeys = 'udyoga.feeds';
}

/// Device-only settings (local_settings).
abstract final class LocalKeys {
  static const feedsChecked = 'udyoga.feeds.checked';
  static const aiChecked = 'udyoga.ai.checked';

  /// Spend this month: {"month": "2026-10", "dollars": 1.23}.
  static const spend = 'udyoga.ai.spend';
}

/// Udyoga's write path and the reads screens share.
class CareerBook {
  CareerBook(this.store);
  final Store store;

  AppDatabase get db => store.db as AppDatabase;

  Future<T> pref<T>(String key, T fallback) async {
    final row = await (db.select(db.prefs)..where((p) => p.id.equals(key))).getSingleOrNull();
    if (row == null || row.deleted) return fallback;
    final v = jsonDecode(row.value);
    return v is T ? v : fallback;
  }

  Future<void> setPref(String key, Object value) => store.save(
    db.prefs,
    PrefsCompanion.insert(id: key, value: jsonEncode(value), deleted: const Value(false)),
    key,
  );

  Future<CandidateProfile> profile() async =>
      CandidateProfile.fromJson(await pref<Map<String, Object?>>(PrefKeys.profile, const {}));

  Future<void> saveProfile(CandidateProfile p) => setPref(PrefKeys.profile, p.toJson());

  Future<FeedKeys> feedKeys() async =>
      FeedKeys.fromJson(await pref<Map<String, Object?>>(PrefKeys.feedKeys, const {}));

  /// Saves a row of any Udyoga table.
  Future<void> save<T extends Table, D>(TableInfo<T, D> table, Insertable<D> row, String id) =>
      store.save(table, row, id);

  Future<void> remove(TableInfo table, String id) => store.remove(table, id);

  // ---- jobs ----

  static String _key(String title, String company) =>
      '${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}|${company.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';

  /// Adds new openings and refreshes known ones (same source and id, same
  /// link, or same title at the same employer), keeping the user's status,
  /// notes and the AI's assessment. Returns the ids of the new ones.
  Future<List<String>> importPostings(List<Posting> postings, CandidateProfile p, {required String today}) =>
      db.transaction(() async {
        final existing = await (db.select(db.jobListings)..where((j) => j.deleted.not())).get();
        final bySource = {for (final j in existing) '${j.source}:${j.sourceId}': j};
        final byUrl = {
          for (final j in existing)
            if (j.url.isNotEmpty) j.url: j,
        };
        final byName = {
          for (final j in existing)
            if (j.company.isNotEmpty) _key(j.title, j.company): j,
        };
        final added = <String>[];
        for (final post in postings) {
          if (post.title.isEmpty) continue;
          final match =
              bySource['${post.source}:${post.sourceId}'] ??
              (post.url.isEmpty ? null : byUrl[post.url]) ??
              (post.company.isEmpty ? null : byName[_key(post.title, post.company)]);
          final id = match?.id ?? newId();
          final row = JobListingsCompanion(
            id: Value(id),
            title: Value(post.title),
            company: Value(post.company.isNotEmpty ? post.company : match?.company ?? ''),
            location: Value(post.location.isNotEmpty ? post.location : match?.location ?? ''),
            country: Value(post.country.isNotEmpty ? post.country : match?.country ?? ''),
            remote: Value(post.remote || (match?.remote ?? false)),
            salaryMin: Value(post.salaryMin ?? match?.salaryMin),
            salaryMax: Value(post.salaryMax ?? match?.salaryMax),
            currency: Value(post.currency.isNotEmpty ? post.currency : match?.currency ?? ''),
            salaryText: Value(post.salaryText.isNotEmpty ? post.salaryText : match?.salaryText ?? ''),
            url: Value(post.url.isNotEmpty ? post.url : match?.url ?? ''),
            description: Value(
              post.description.length >= (match?.description.length ?? 0)
                  ? post.description
                  : match!.description,
            ),
            posted: Value(post.posted ?? match?.posted),
            closing: Value(post.closing ?? match?.closing),
            source: Value(match?.source ?? post.source),
            sourceId: Value(match?.sourceId ?? post.sourceId),
            found: Value(match?.found ?? today),
            fit: Value(
              match?.fit ??
                  localFit(p, title: post.title, description: post.description, salaryMax: post.salaryMax),
            ),
          );
          await save(db.jobListings, row, id);
          if (match == null) {
            added.add(id);
            final saved = await job(id);
            bySource['${post.source}:${post.sourceId}'] = saved;
            if (post.url.isNotEmpty) byUrl[post.url] = saved;
            if (post.company.isNotEmpty) byName[_key(post.title, post.company)] = saved;
          }
        }
        return added;
      });

  Future<Job> job(String id) => (db.select(db.jobListings)..where((j) => j.id.equals(id))).getSingle();

  Future<void> setJobStatus(String id, String status) async {
    final j = await job(id);
    await save(db.jobListings, j.copyWith(status: status), id);
  }

  Future<void> saveAssessment(String id, FitAssessment a) async {
    final j = await job(id);
    await save(
      db.jobListings,
      j.copyWith(
        fit: Value(a.fit.clamp(0, 100)),
        assessment: jsonEncode(a.j),
        closing: Value(j.closing ?? (a.closing.length == 10 ? a.closing : null)),
      ),
      id,
    );
  }

  /// Quick AI scores for new jobs, unless the AI has assessed one in depth.
  Future<void> saveTriage(Map<String, ({int fit, String why})> scores) => db.transaction(() async {
    for (final e in scores.entries) {
      final j = await (db.select(db.jobListings)..where((t) => t.id.equals(e.key))).getSingleOrNull();
      if (j == null || j.assessment.isNotEmpty) continue;
      await save(
        db.jobListings,
        j.copyWith(fit: Value(e.value.fit), notes: j.notes.isEmpty ? e.value.why : j.notes),
        j.id,
      );
    }
  });

  // ---- applications ----

  Future<JobApplication> application(String id) =>
      (db.select(db.jobApplications)..where((a) => a.id.equals(id))).getSingle();

  /// Starts an application for [j] (or returns the open one) and marks the
  /// job applied.
  Future<String> applyFor(Job j, {required String today, bool sent = false}) => db.transaction(() async {
    final open =
        await (db.select(db.jobApplications)
              ..where((a) => a.jobId.equals(j.id) & a.deleted.not())
              ..limit(1))
            .getSingleOrNull();
    if (open != null) return open.id;
    final id = newId();
    await save(
      db.jobApplications,
      JobApplicationsCompanion.insert(
        id: id,
        jobId: Value(j.id),
        title: j.title,
        company: Value(j.company),
        location: Value(j.location),
        url: Value(j.url),
        updated: today,
      ),
      id,
    );
    await save(db.jobListings, j.copyWith(status: 'applied'), j.id);
    if (sent) await moveTo(id, Stage.applied, date: today);
    return id;
  });

  /// Moves an application to [stage] on [date], records it and sets the
  /// next follow-up.
  Future<void> moveTo(String id, Stage stage, {required String date, String summary = ''}) =>
      db.transaction(() async {
        final a = await application(id);
        await save(
          db.jobApplications,
          a.copyWith(
            stage: stage.id,
            updated: date,
            applied: Value(a.applied ?? (stage.index >= Stage.applied.index && stage.open ? date : null)),
            followUp: Value(followUpFor(stage, date)),
            followUpNote: stage.chaseAfter == null ? '' : _chaseNote(stage),
          ),
          id,
        );
        final kind = eventKinds.entries.where((e) => e.value.$2 == stage).firstOrNull?.key ?? 'note';
        await _event(id, kind, summary.isNotEmpty ? summary : stage.label, '${date}T${_clock()}');
      });

  static String _chaseNote(Stage s) => switch (s) {
    Stage.applied => 'Ask whether the application is being considered and when shortlisting ends.',
    Stage.screening => 'Ask about next steps and the interview timetable.',
    Stage.interview =>
      'Thank the panel and ask when they expect to decide; ask for feedback if unsuccessful.',
    Stage.offer => 'Reply to the offer: questions, negotiation or acceptance.',
    _ => '',
  };

  static String _clock() => DateTime.now().toIso8601String().substring(11, 16);

  Future<void> _event(String applicationId, String kind, String summary, String at) {
    final id = newId();
    return save(
      db.jobEvents,
      JobEventsCompanion.insert(
        id: id,
        applicationId: applicationId,
        at: at,
        kind: kind,
        summary: Value(summary),
      ),
      id,
    );
  }

  /// Logs what happened; events that imply a stage move the application on
  /// (never back), and chasing it up sets the next follow-up a week later.
  Future<void> logEvent(String id, String kind, {required String at, String summary = ''}) =>
      db.transaction(() async {
        final stage = eventKinds[kind]?.$2;
        final a = await application(id);
        final date = at.substring(0, 10);
        if (stage != null && (stage.index > Stage.of(a.stage).index || !stage.open)) {
          await moveTo(id, stage, date: date, summary: summary.isNotEmpty ? summary : eventKinds[kind]!.$1);
          return;
        }
        await _event(id, kind, summary.isNotEmpty ? summary : eventKinds[kind]?.$1 ?? kind, at);
        if (kind == 'followup' && Stage.of(a.stage).open) {
          await save(db.jobApplications, a.copyWith(followUp: Value(addDays(date, 7))), id);
        }
      });

  Future<void> setFollowUp(String id, String? date, {String? note}) async {
    final a = await application(id);
    await save(
      db.jobApplications,
      a.copyWith(followUp: Value(date), followUpNote: note ?? a.followUpNote),
      id,
    );
  }

  /// Applications with no word [ghostedAfterDays] after the last change go
  /// to No reply. Returns how many.
  Future<int> markGhosted(String today) => db.transaction(() async {
    final cutoff = addDays(today, -ghostedAfterDays);
    final stale =
        await (db.select(db.jobApplications)..where(
              (a) =>
                  a.deleted.not() &
                  a.stage.isIn([Stage.applied.id, Stage.screening.id]) &
                  a.updated.isSmallerThanValue(cutoff),
            ))
            .get();
    for (final a in stale) {
      await moveTo(a.id, Stage.noReply, date: today, summary: 'No reply after $ghostedAfterDays days');
    }
    return stale.length;
  });

  // ---- leads ----

  Future<int> importLeads(List<LeadSuggestion> leads, {String? jobId, required String today}) =>
      db.transaction(() async {
        final existing = await (db.select(db.careerContacts)..where((c) => c.deleted.not())).get();
        final known = {for (final c in existing) _key(c.name, c.company)};
        var added = 0;
        for (final l in leads) {
          if (l.name.isEmpty || !known.add(_key(l.name, l.company))) continue;
          final id = newId();
          await save(
            db.careerContacts,
            CareerContactsCompanion.insert(
              id: id,
              name: l.name,
              kind: Value(leadKinds.containsKey(l.kind) ? l.kind : 'other'),
              title: Value(l.title),
              company: Value(l.company),
              email: Value(l.email),
              linkedin: Value(l.linkedin),
              source: Value(l.source),
              jobId: Value(jobId),
              followUp: Value(today),
              notes: Value([l.why, if (l.approach.isNotEmpty) 'Approach: ${l.approach}'].join('\n')),
            ),
            id,
          );
          added++;
        }
        return added;
      });

  /// Records contact with a lead: status Contacted, chase again in a week.
  Future<void> contacted(Lead l, {required String today}) => save(
    db.careerContacts,
    l.copyWith(
      status: l.status == 'replied' ? 'replied' : 'contacted',
      lastContact: Value(today),
      followUp: Value(addDays(today, 7)),
    ),
    l.id,
  );

  // ---- CVs, reports, growth ----

  Future<String> saveResume({
    required String name,
    required ResumeDoc doc,
    String? jobId,
    Json? tailoring,
    required String today,
    String? id,
  }) async {
    final rowId = id ?? newId();
    await save(
      db.careerResumes,
      CareerResumesCompanion.insert(
        id: rowId,
        name: name,
        jobId: Value(jobId),
        created: today,
        content: jsonEncode(doc.toJson()),
        tailoring: Value(tailoring == null ? '' : jsonEncode(tailoring)),
      ),
      rowId,
    );
    return rowId;
  }

  Future<String> saveReport(String kind, Json content, List<Source> sources, {required String at}) async {
    final id = newId();
    await save(
      db.careerReports,
      CareerReportsCompanion.insert(
        id: id,
        kind: kind,
        created: at,
        content: jsonEncode(content),
        sources: Value(
          jsonEncode([
            for (final s in sources) {'title': s.title, 'url': s.url},
          ]),
        ),
      ),
      id,
    );
    return id;
  }

  Future<Report?> latestReport(String kind) =>
      (db.select(db.careerReports)
            ..where((r) => r.kind.equals(kind) & r.deleted.not())
            ..orderBy([(r) => OrderingTerm.desc(r.created)])
            ..limit(1))
          .getSingleOrNull();

  /// Adds learning suggestions not already on the list. Returns how many.
  Future<int> suggestLearning(List<LearningSuggestion> items, {String path = '', required String today}) =>
      db.transaction(() async {
        final existing = await (db.select(db.careerGrowth)..where((g) => g.deleted.not())).get();
        final known = {for (final g in existing) g.title.toLowerCase().trim()};
        var added = 0;
        for (final s in items) {
          if (s.title.isEmpty || !known.add(s.title.toLowerCase().trim())) continue;
          final id = newId();
          await save(
            db.careerGrowth,
            CareerGrowthCompanion.insert(
              id: id,
              title: s.title,
              kind: growthKinds.containsKey(s.kind) ? s.kind : 'course',
              provider: Value(s.provider),
              url: Value(s.url),
              cost: Value(s.cost),
              duration: Value(s.duration),
              why: Value(
                [s.why, if (s.priority == 'essential') '(Essential)'].where((t) => t.isNotEmpty).join(' '),
              ),
              path: Value(path),
              added: today,
            ),
            id,
          );
          added++;
        }
        return added;
      });

  /// Makes [path] the target: a goal for each step and its certifications
  /// as learning. Returns how many items were added.
  Future<int> targetPath(CareerPath path, {required String today}) async {
    var added = await suggestLearning(
      [
        for (final step in path.steps)
          for (final c in step.certifications)
            LearningSuggestion(
              title: c,
              kind: 'certification',
              why: 'Needed for ${step.role}',
              priority: 'essential',
            ),
      ],
      path: path.name,
      today: today,
    );
    added += await suggestLearning(
      [
        for (final step in path.steps)
          LearningSuggestion(
            title: 'Become ${step.role}',
            kind: 'goal',
            duration: step.timeframe,
            why: step.requirements.join('; '),
          ),
      ],
      path: path.name,
      today: today,
    );
    final goals = await (db.select(
      db.careerGrowth,
    )..where((g) => g.path.equals(path.name) & g.deleted.not())).get();
    for (final g in goals.where((g) => g.status == 'suggested')) {
      await save(db.careerGrowth, g.copyWith(status: 'planned'), g.id);
    }
    return added;
  }

  Future<void> setGrowth(GrowthItem g, {String? status, int? progress, required String today}) => save(
    db.careerGrowth,
    g.copyWith(
      status:
          status ??
          (progress == 100
              ? 'done'
              : (progress ?? 0) > 0 && g.status != 'done'
              ? 'doing'
              : g.status),
      progress: progress ?? (status == 'done' ? 100 : g.progress),
      done: Value(status == 'done' || progress == 100 ? today : g.done),
    ),
    g.id,
  );

  // ---- interview practice ----

  Future<String> startPractice({
    required String role,
    required String mode,
    String? jobId,
    required List<PracticeQuestion> questions,
    required String at,
  }) async {
    final id = newId();
    await save(
      db.careerPractice,
      CareerPracticeCompanion.insert(
        id: id,
        role: role,
        mode: mode,
        jobId: Value(jobId),
        started: at,
        questions: jsonEncode([for (final q in questions) q.j]),
      ),
      id,
    );
    return id;
  }

  /// Saves an answer and its review, and updates the round's average.
  Future<void> saveAnswer(
    String sessionId,
    int question,
    String answer,
    AnswerReview review, {
    required String at,
  }) => db.transaction(() async {
    final previous =
        await (db.select(db.careerAnswers)
              ..where((a) => a.sessionId.equals(sessionId) & a.question.equals(question) & a.deleted.not()))
            .getSingleOrNull();
    final id = previous?.id ?? newId();
    await save(
      db.careerAnswers,
      CareerAnswersCompanion.insert(
        id: id,
        sessionId: sessionId,
        question: question,
        answer: answer,
        at: at,
        review: Value(jsonEncode(review.j)),
        score: Value(review.score),
      ),
      id,
    );
    final scores =
        await (db.select(db.careerAnswers)
              ..where((a) => a.sessionId.equals(sessionId) & a.deleted.not() & a.score.isNotNull()))
            .map((a) => a.score!)
            .get();
    final s = await (db.select(db.careerPractice)..where((p) => p.id.equals(sessionId))).getSingle();
    await save(
      db.careerPractice,
      s.copyWith(score: Value(scores.isEmpty ? null : scores.reduce((a, b) => a + b) / scores.length)),
      s.id,
    );
  });

  // ---- spend ----

  /// Adds a request's cost to this month's running total on this device.
  Future<void> addSpend(AiUsage u, {required String month}) async {
    final j = decodeObject(await db.localSetting(LocalKeys.spend) ?? '');
    final dollars = (str(j['month']) == month ? numOf(j['dollars']) ?? 0 : 0) + u.dollars;
    await db.setLocalSetting(LocalKeys.spend, jsonEncode({'month': month, 'dollars': dollars}));
  }

  Future<double> spend(String month) async {
    final j = decodeObject(await db.localSetting(LocalKeys.spend) ?? '');
    return str(j['month']) == month ? numOf(j['dollars']) ?? 0 : 0;
  }
}
