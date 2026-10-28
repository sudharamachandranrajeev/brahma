import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'feeds.dart';
import 'profile.dart';

/// A row of a LinkedIn export CSV, by header in lower case.
typedef CsvRow = Map<String, String>;

/// What a LinkedIn import added, part by part.
typedef LinkedInImport = ({
  int jobs,
  int skills,
  int certifications,
  int wins,
  int applications,
  int savedJobs,
  int contacts,
});

/// The parts of the archive LinkedIn gives a member (Settings > Data privacy
/// > Get a copy of your data) that help a job search. It is read on the
/// device: nothing is fetched from LinkedIn, so the account is never at risk.
/// LinkedIn renames columns now and then, so every column is looked up
/// leniently and a missing file reads as empty.
class LinkedInExport {
  const LinkedInExport({
    this.profile = const {},
    this.positions = const [],
    this.education = const [],
    this.skills = const [],
    this.certifications = const [],
    this.languages = const [],
    this.honors = const [],
    this.recommendations = const [],
    this.connections = const [],
    this.applications = const [],
    this.savedJobs = const [],
  });

  final CsvRow profile;
  final List<CsvRow> positions, education, certifications, honors, recommendations, connections;
  final List<CsvRow> applications, savedJobs;
  final List<String> skills, languages;

  bool get isEmpty =>
      profile.isEmpty &&
      positions.isEmpty &&
      skills.isEmpty &&
      connections.isEmpty &&
      applications.isEmpty &&
      recommendations.isEmpty;

  /// Reads the export ZIP. Throws a [FormatException] when it is not one.
  factory LinkedInExport.read(Uint8List zip) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zip);
    } catch (_) {
      throw const FormatException('That is not a ZIP file. Choose the archive LinkedIn sent you.');
    }
    final files = {
      for (final f in archive.files)
        if (f.isFile && f.name.toLowerCase().endsWith('.csv'))
          f.name.split('/').last.toLowerCase(): utf8.decode(f.content, allowMalformed: true),
    };
    List<CsvRow> rows(String name, {String header = ''}) => readCsv(files[name] ?? '', header: header);
    final export = LinkedInExport(
      profile: rows('profile.csv').firstOrNull ?? const {},
      positions: rows('positions.csv'),
      education: rows('education.csv'),
      skills: [for (final r in rows('skills.csv')) ?_nonEmpty(r['name'])],
      certifications: rows('certifications.csv'),
      languages: [for (final r in rows('languages.csv')) ?_nonEmpty(r['name'])],
      honors: rows('honors.csv'),
      recommendations: rows('recommendations_received.csv'),
      // Connections.csv opens with a few lines of notes before its header.
      connections: rows('connections.csv', header: 'first name'),
      applications: rows('job applications.csv'),
      savedJobs: rows('saved jobs.csv'),
    );
    if (export.isEmpty) {
      throw const FormatException(
        'No LinkedIn data found in that ZIP. Choose the archive from LinkedIn > Settings > Data privacy > '
        'Get a copy of your data.',
      );
    }
    return export;
  }

  /// The profile with what LinkedIn adds: empty fields filled in, jobs and
  /// education the profile lacks, and every skill, certification and
  /// language. Nothing the user already has is changed.
  CandidateProfile mergeInto(CandidateProfile p) {
    final name = [
      _col(profile, 'first name'),
      _col(profile, 'last name'),
    ].where((s) => s.isNotEmpty).join(' ');
    final jobs = [...p.experience];
    for (final r in positions) {
      final org = _col(r, 'company name');
      final title = _col(r, 'title');
      if (org.isEmpty && title.isEmpty) continue;
      final start = linkedInDate(_col(r, 'started on'));
      final i = jobs.indexWhere(
        (e) =>
            _same(e.organisation, org) &&
            (_same(e.title, title) || (start.isNotEmpty && e.start.startsWith(start))),
      );
      final highlights = [
        for (final l in _col(r, 'description').split(RegExp(r'\n+')))
          if (l.replaceFirst(RegExp(r'^[\s•*\-–]+'), '').trim() case final t when t.isNotEmpty) t,
      ];
      if (i < 0) {
        jobs.add(
          Experience(
            title: title,
            organisation: org,
            location: _col(r, 'location'),
            start: start,
            end: linkedInDate(_col(r, 'finished on')),
            highlights: highlights,
          ),
        );
      } else if (jobs[i].highlights.isEmpty && highlights.isNotEmpty) {
        final e = jobs[i];
        jobs[i] = Experience(
          title: e.title,
          organisation: e.organisation,
          location: e.location.isEmpty ? _col(r, 'location') : e.location,
          start: e.start.isEmpty ? start : e.start,
          end: e.end,
          highlights: highlights,
        );
      }
    }
    jobs.sort((a, b) => _sortKey(b).compareTo(_sortKey(a)));
    final schools = [...p.education];
    for (final r in education) {
      final school = _col(r, 'school name');
      if (school.isEmpty || schools.any((e) => _same(e.institution, school))) continue;
      schools.add(
        Education(
          qualification: _col(r, 'degree name'),
          institution: school,
          year: linkedInDate(_col(r, 'end date')).split('-').first,
        ),
      );
    }
    final current = jobs.where((e) => e.current).firstOrNull;
    return p.copyWith(
      name: p.name.isEmpty ? name : null,
      headline: p.headline.isEmpty ? _col(profile, 'headline') : null,
      location: p.location.isEmpty ? _col(profile, 'geo location') : null,
      summary: p.summary.isEmpty ? _col(profile, 'summary') : null,
      currentRole: p.currentRole.isEmpty ? current?.title : null,
      currentEmployer: p.currentEmployer.isEmpty ? current?.organisation : null,
      experience: jobs,
      education: schools,
      skills: _union(p.skills, skills),
      certifications: _union(p.certifications, [for (final c in certifications) ?_nonEmpty(_col(c, 'name'))]),
      languages: _union(p.languages, languages),
      achievements: _union(p.achievements, [
        for (final h in honors)
          if (_col(h, 'title') case final t when t.isNotEmpty) t,
      ]),
    );
  }

  /// Connections worth having as contacts: people at an employer the user
  /// is applying to or watching, and recruiters. A whole network would bury
  /// the few who matter.
  List<CsvRow> usefulConnections(Iterable<String> companies) {
    final wanted = {for (final c in companies) ?_nonEmpty(_norm(c))};
    return [
      for (final c in connections)
        if (wanted.contains(_norm(_col(c, 'company'))) || isRecruiter(_col(c, 'position'))) c,
    ];
  }

  /// Saved jobs from the last [days] days, as postings.
  List<Posting> savedPostings({required String today, int days = 90}) => [
    for (final r in savedJobs)
      if (_col(r, 'job title') case final title when title.isNotEmpty)
        if (linkedInDate(_col(r, 'saved date')) case final saved
            when saved.isEmpty || _within(saved, today, days))
          Posting(
            source: 'linkedin',
            sourceId: _col(r, 'job url'),
            title: title,
            company: _col(r, 'company name'),
            url: _col(r, 'job url'),
          ),
  ];

  /// Applications sent through LinkedIn in the last [days] days.
  List<CsvRow> recentApplications({required String today, int days = 180}) => [
    for (final r in applications)
      if (_col(r, 'job title').isNotEmpty)
        if (linkedInDate(_col(r, 'application date')) case final d when d.isEmpty || _within(d, today, days))
          r,
  ];
}

/// A column of [r] by its lower-case header, tolerating small renames
/// ("Company Name" or "Company").
String col(CsvRow r, String name) => _col(r, name);

String _col(CsvRow r, String name) {
  final v = r[name] ?? r[name.replaceAll(' name', '')] ?? r[name.replaceAll(' ', '')];
  return (v ?? '').trim();
}

String? _nonEmpty(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'\b(ltd|limited|inc|plc|llc|gmbh|corp|corporation|co)\b\.?'), '')
    .replaceAll(RegExp(r'[^a-z0-9]'), '');

bool _same(String a, String b) => _norm(a).isNotEmpty && _norm(a) == _norm(b);

String _sortKey(Experience e) => e.current ? '9999' : (e.end.isEmpty ? e.start : e.end);

List<String> _union(List<String> a, List<String> b) {
  final seen = {for (final s in a) s.toLowerCase().trim()};
  return [...a, ...b.where((s) => s.trim().isNotEmpty && seen.add(s.toLowerCase().trim()))];
}

bool _within(String date, String today, int days) {
  final d = DateTime.tryParse(date.length == 7 ? '$date-01' : date);
  final t = DateTime.tryParse(today);
  return d == null || t == null || t.difference(d).inDays <= days;
}

/// Whether a job title is a recruiter's.
bool isRecruiter(String position) => RegExp(
  r'recruit|talent|sourcer|headhunt|hiring|resourcing|\bhr\b|people partner',
  caseSensitive: false,
).hasMatch(position);

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

/// A LinkedIn date ("Mar 2021", "2021", "14 Mar 2024", "3/14/24, 10:22 AM",
/// "2024-03-14 10:22 UTC") as yyyy-MM-dd, yyyy-MM or yyyy; '' when there is
/// none.
String linkedInDate(String s) {
  final t = s.trim();
  if (t.isEmpty) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  if (RegExp(r'^(\d{4})-(\d{2})(-(\d{2}))?').firstMatch(t) case final m?) return m.group(0)!;
  if (RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})').firstMatch(t) case final m?) {
    final y = int.parse(m.group(3)!);
    return '${y < 100 ? 2000 + y : y}-${two(int.parse(m.group(1)!))}-${two(int.parse(m.group(2)!))}';
  }
  final words = t.toLowerCase().split(RegExp(r'[\s,]+'));
  final year = words.lastWhere((w) => RegExp(r'^\d{4}$').hasMatch(w), orElse: () => '');
  if (year.isEmpty) return '';
  final month = words.map((w) => _months[w.length >= 3 ? w.substring(0, 3) : w]).nonNulls.firstOrNull;
  if (month == null) return year;
  final day = words.map(int.tryParse).nonNulls.where((n) => n >= 1 && n <= 31).firstOrNull;
  return day == null ? '$year-${two(month)}' : '$year-${two(month)}-${two(day)}';
}

/// Parses CSV text (RFC 4180: quoted fields, doubled quotes, newlines in
/// quotes) into rows keyed by the lower-case header. With [header], rows
/// before the first one holding that column are skipped.
List<CsvRow> readCsv(String text, {String header = ''}) {
  final records = <List<String>>[];
  var field = StringBuffer();
  var record = <String>[];
  var quoted = false;
  final s = text.startsWith('﻿') ? text.substring(1) : text;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < s.length && s[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      record.add(field.toString());
      field = StringBuffer();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < s.length && s[i + 1] == '\n') i++;
      record.add(field.toString());
      field = StringBuffer();
      if (record.any((f) => f.trim().isNotEmpty)) records.add(record);
      record = <String>[];
    } else {
      field.write(c);
    }
  }
  record.add(field.toString());
  if (record.any((f) => f.trim().isNotEmpty)) records.add(record);
  final start = header.isEmpty
      ? 0
      : records.indexWhere((r) => r.any((f) => f.trim().toLowerCase() == header));
  if (start < 0 || start >= records.length) return const [];
  final keys = [for (final k in records[start]) k.trim().toLowerCase()];
  return [
    for (final r in records.skip(start + 1))
      {
        for (final (i, k) in keys.indexed)
          if (k.isNotEmpty) k: i < r.length ? r[i] : '',
      },
  ];
}
