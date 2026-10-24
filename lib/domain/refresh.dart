import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:http/http.dart' as http;

import 'advisor.dart';
import 'book.dart';
import 'feeds.dart';
import 'insights.dart';
import 'json.dart';
import 'profile.dart';

/// What a refresh did.
class RefreshReport {
  int found = 0;
  int added = 0;
  int ghosted = 0;
  bool aiSearched = false;
  bool mapRefreshed = false;
  final problems = <String>[];

  String get summary => [
    if (added > 0) '$added new ${added == 1 ? 'job' : 'jobs'}' else 'No new jobs',
    if (aiSearched) 'AI search done',
    if (mapRefreshed) 'career map updated',
    if (ghosted > 0) '$ghosted marked no reply',
    if (problems.isNotEmpty) 'problems: ${problems.join('; ')}',
  ].join(' · ');
}

/// Feeds are checked at most this often (Remotive asks for a few calls a day).
const feedInterval = Duration(hours: 6);

/// The career map is redone this often while the AI routine is on.
const mapAgeDays = 30;

/// The routine refresh: job feeds for every target country, then (when the
/// user turned the AI routine on and it is due) an AI web search, quick AI
/// scores for the new jobs and a fresh career map.
class Refresher {
  Refresher(this.book, this.client, {this.advisor});
  final CareerBook book;
  final http.Client client;
  final Advisor? advisor;

  /// Runs what is due; [force] runs the feeds (and, with [ai], the AI
  /// search) now regardless.
  Future<RefreshReport> run({
    required String today,
    bool force = false,
    bool ai = false,
    Progress? onProgress,
  }) async {
    final report = RefreshReport();
    final p = await book.profile();
    report.ghosted = await book.markGhosted(today);
    if (p.searchTerms.isEmpty) {
      report.problems.add('add a current role or target roles to your profile first');
      return report;
    }
    final now = DateTime.now();
    final db = book.db;

    final checked = DateTime.tryParse(await db.localSetting(LocalKeys.feedsChecked) ?? '');
    if (force || checked == null || now.difference(checked) >= feedInterval) {
      onProgress?.call('Checking job sites…');
      final added = await _feeds(p, report, today);
      report.added += added.length;
      await db.setLocalSetting(LocalKeys.feedsChecked, now.toIso8601String());
      if (added.isNotEmpty && advisor != null && await _routine() != 'off') {
        await _triage(p, added, report);
      }
    }

    final routine = await _routine();
    if (advisor != null && (ai || routine != 'off')) {
      final last = DateTime.tryParse(await db.localSetting(LocalKeys.aiChecked) ?? '');
      final every = routine == 'daily' ? const Duration(hours: 20) : const Duration(days: 6);
      if (ai || last == null || now.difference(last) >= every) {
        await _aiSearch(p, report, today, onProgress);
        await db.setLocalSetting(LocalKeys.aiChecked, now.toIso8601String());
        if (!ai) await _map(p, report, today, onProgress);
      }
    }
    return report;
  }

  Future<String> _routine() => book.pref<String>(PrefKeys.aiRoutine, 'off');

  /// One query per target country (and town, if any), plus one for remote work.
  static List<FeedQuery> queries(CandidateProfile p) => [
    for (final c in p.searchCountries)
      FeedQuery(
        terms: p.searchTerms,
        country: c,
        place: c == p.country && p.targets.locations.isNotEmpty ? p.targets.locations.first : '',
        remote: p.targets.remote,
      ),
    if (p.targets.remote) FeedQuery(terms: p.searchTerms, country: '', remote: true),
  ];

  Future<List<String>> _feeds(CandidateProfile p, RefreshReport report, String today) async {
    final feeds = allFeeds(client, await book.feedKeys());
    final postings = <Posting>[];
    for (final q in queries(p)) {
      for (final f in feeds.where((f) => f.covers(q))) {
        try {
          postings.addAll(await f.search(q));
        } on Object catch (e) {
          report.problems.add('${f.name}: ${e is FeedException ? e.message : 'not reachable'}');
        }
      }
    }
    report.found += postings.length;
    return book.importPostings(postings, p, today: today);
  }

  Future<void> _triage(CandidateProfile p, List<String> ids, RefreshReport report) async {
    try {
      final jobs = [for (final id in ids.take(40)) await book.job(id)];
      await book.saveTriage(await advisor!.triage(p, jobs));
    } on Object catch (e) {
      report.problems.add('AI scoring: ${describeError(e)}');
    }
  }

  Future<void> _aiSearch(CandidateProfile p, RefreshReport report, String today, Progress? onProgress) async {
    try {
      final known = await (book.db.select(
        book.db.jobListings,
      )..where((j) => j.deleted.not())).map((j) => j.url).get();
      final r = await advisor!.findJobs(
        p,
        countries: p.searchCountries,
        known: known.where((u) => u.isNotEmpty).toList(),
        onProgress: onProgress,
      );
      final found = objs(r.data['jobs']);
      final postings = [
        for (final j in found)
          Posting(
            source: 'ai',
            sourceId: str(j['url']),
            title: str(j['title']),
            company: str(j['company']),
            location: str(j['location']),
            country: str(j['country']).toUpperCase(),
            remote: j['remote'] == true,
            salaryText: str(j['salaryText']),
            url: str(j['url']),
            description: [
              str(j['description']),
              if (str(j['site']).isNotEmpty) 'Advertised on ${str(j['site'])}.',
            ].join('\n\n'),
            posted: str(j['posted']).length == 10 ? str(j['posted']) : null,
            closing: str(j['closing']).length == 10 ? str(j['closing']) : null,
          ),
      ];
      final added = await book.importPostings(postings, p, today: today);
      // The search scored its own finds; keep those scores for the new ones.
      final scores = <String, ({int fit, String why})>{};
      for (final id in added) {
        final job = await book.job(id);
        final match = found.where((j) => str(j['url']) == job.url).firstOrNull;
        if (match != null) {
          scores[id] = (fit: (intOf(match['fit']) ?? 0).clamp(0, 100), why: str(match['why']));
        }
      }
      await book.saveTriage(scores);
      report
        ..found += postings.length
        ..added += added.length
        ..aiSearched = true;
    } on Object catch (e) {
      report.problems.add('AI search: ${describeError(e)}');
    }
  }

  Future<void> _map(CandidateProfile p, RefreshReport report, String today, Progress? onProgress) async {
    final last = await book.latestReport('career_map');
    if (last != null && last.created.compareTo(addDays(today, -mapAgeDays)) > 0) return;
    try {
      final a = await book.latestReport('assessment');
      final r = await advisor!.careerMap(
        p,
        assessment: a == null ? null : Assessment(decodeObject(a.content)),
        onProgress: onProgress,
      );
      await book.saveReport('career_map', r.data, r.sources, at: today);
      report.mapRefreshed = true;
    } on Object catch (e) {
      report.problems.add('Career map: ${describeError(e)}');
    }
  }
}
