import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:udyoga/domain/answer_metrics.dart';
import 'package:udyoga/domain/book.dart';
import 'package:udyoga/domain/calendar.dart';
import 'package:udyoga/domain/claude.dart';
import 'package:udyoga/domain/feeds.dart';
import 'package:udyoga/domain/insights.dart';
import 'package:udyoga/domain/matching.dart';
import 'package:udyoga/domain/pipeline.dart';
import 'package:udyoga/domain/profile.dart';
import 'package:udyoga/domain/resume.dart';
import 'package:udyoga/domain/schema.dart';

import 'support.dart';

String sse(List<Map<String, Object?>> events) =>
    [for (final e in events) 'event: ${e['type']}\ndata: ${jsonEncode(e)}\n\n'].join();

void main() {
  group('schema', () {
    final schema = object({
      'name': string(),
      'level': oneOf(['low', 'high']),
      'count': integer(),
      'tags': strings(),
    });

    test('accepts a conforming value', () {
      expect(violation(schema, {'name': 'a', 'level': 'low', 'count': 2, 'tags': <String>[]}), isNull);
    });

    test('names the first problem', () {
      expect(violation(schema, {'name': 'a', 'level': 'low', 'count': 2}), r'$.tags is missing');
      expect(
        violation(schema, {'name': 'a', 'level': 'mid', 'count': 2, 'tags': <String>[]}),
        r'$.level is not one of low, high',
      );
      expect(
        violation(schema, {'name': 'a', 'level': 'low', 'count': 2.5, 'tags': <String>[]}),
        r'$.count is not a whole number',
      );
      expect(
        violation(schema, {
          'name': 'a',
          'level': 'low',
          'count': 1,
          'tags': [1],
        }),
        r'$.tags[0] is not text',
      );
    });
  });

  group('Claude', () {
    final schema = object({'answer': string()});

    test('reads a streamed structured answer and counts usage', () async {
      late Map<String, Object?> sent;
      final client = MockClient.streaming((request, body) async {
        sent = jsonDecode(await body.bytesToString()) as Map<String, Object?>;
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              sse([
                {
                  'type': 'message_start',
                  'message': {
                    'usage': {'input_tokens': 1000, 'output_tokens': 1},
                  },
                },
                {
                  'type': 'content_block_start',
                  'index': 0,
                  'content_block': {'type': 'text', 'text': ''},
                },
                {
                  'type': 'content_block_delta',
                  'index': 0,
                  'delta': {'type': 'text_delta', 'text': '{"answer":'},
                },
                {
                  'type': 'content_block_delta',
                  'index': 0,
                  'delta': {'type': 'text_delta', 'text': '"yes"}'},
                },
                {'type': 'content_block_stop', 'index': 0},
                {
                  'type': 'message_delta',
                  'delta': {'stop_reason': 'end_turn'},
                  'usage': {'output_tokens': 50},
                },
                {'type': 'message_stop'},
              ]),
            ),
          ),
          200,
        );
      });
      AiUsage? usage;
      final r = await Claude(
        apiKey: 'sk-test',
        client: client,
        onUsage: (u) => usage = u,
      ).ask(system: 's', content: const [], schema: schema);
      expect(r.data['answer'], 'yes');
      expect(usage!.input, 1000);
      expect(usage!.output, 50);
      expect(sent['stream'], isTrue);
      expect((sent['output_config'] as Map)['format'], isNotNull);
    });

    test('asks again when the web answer breaks the schema', () async {
      var calls = 0;
      Map<String, Object?> submit(Object input) => {
        'type': 'content_block_start',
        'index': 0,
        'content_block': {
          'type': 'tool_use',
          'id': 't$calls',
          'name': 'submit',
          'input': <String, Object?>{},
        },
      };
      final client = MockClient.streaming((request, body) async {
        calls++;
        final input = calls == 1 ? '{"answer": 3}' : '{"answer": "ok"}';
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              sse([
                submit(input),
                {
                  'type': 'content_block_delta',
                  'index': 0,
                  'delta': {'type': 'input_json_delta', 'partial_json': input},
                },
                {'type': 'content_block_stop', 'index': 0},
                {
                  'type': 'message_delta',
                  'delta': {'stop_reason': 'tool_use'},
                  'usage': {'output_tokens': 5},
                },
              ]),
            ),
          ),
          200,
        );
      });
      final r = await Claude(
        apiKey: 'sk-test',
        client: client,
      ).ask(system: 's', content: const [], schema: schema, web: true);
      expect(r.data['answer'], 'ok');
      expect(calls, 2);
    });

    test('explains a rejected key without retrying', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{"error":{"message":"invalid x-api-key"}}', 401);
      });
      await expectLater(
        Claude(apiKey: 'sk-bad', client: client).ask(system: 's', content: const [], schema: schema),
        throwsA(isA<AiException>().having((e) => e.message, 'message', contains('API key'))),
      );
      expect(calls, 1);
    });
  });

  group('feeds', () {
    test('Reed results become postings with UK dates', () async {
      final client = MockClient((request) async {
        expect(request.headers['authorization'], startsWith('Basic '));
        return http.Response(
          jsonEncode({
            'results': [
              {
                'jobId': 55,
                'jobTitle': 'Clinical Informatics Nurse',
                'employerName': 'Example Health Trust',
                'locationName': 'Exampletown',
                'minimumSalary': 38000.0,
                'maximumSalary': 45000.0,
                'jobUrl': 'https://www.reed.co.uk/jobs/55',
                'jobDescription': '<p>Support <b>EPR</b> roll-out</p>',
                'date': '20/10/2026',
                'expirationDate': '01/12/2026',
              },
            ],
          }),
          200,
        );
      });
      final feed = ReedFeed(client, key: 'k');
      const q = FeedQuery(terms: ['informatics nurse'], country: 'GB');
      expect(feed.covers(q), isTrue);
      expect(feed.covers(const FeedQuery(terms: ['x'], country: 'IE')), isFalse);
      final p = (await feed.search(q)).single;
      expect(p.sourceId, '55');
      expect(p.salaryMax, 45000);
      expect(p.posted, '2026-10-20');
      expect(p.closing, '2026-12-01');
      expect(p.description, isNot(contains('<')));
    });

    test('a rejected key is reported as such', () async {
      final feed = ReedFeed(MockClient((_) async => http.Response('', 401)), key: 'k');
      await expectLater(
        feed.search(const FeedQuery(terms: ['x'], country: 'GB')),
        throwsA(isA<FeedException>().having((e) => e.message, 'message', contains('rejected'))),
      );
    });
  });

  group('book', () {
    late CareerBook book;
    setUp(() async => book = CareerBook(await Store.open(memoryDatabase())));
    tearDown(() => book.db.close());

    test('imports postings once, matching by source, link or name', () async {
      final first = await book.importPostings([samplePosting()], sampleProfile, today: '2026-10-24');
      expect(first, hasLength(1));
      final again = await book.importPostings(
        [
          samplePosting(),
          samplePosting(source: 'adzuna', id: '9', company: 'Example Health  Trust'),
          samplePosting(id: '2', title: 'EPR Trainer'),
        ],
        sampleProfile,
        today: '2026-10-25',
      );
      expect(again, hasLength(1));
      final jobs = await book.db.select(book.db.jobListings).get();
      expect(jobs, hasLength(2));
      expect(jobs.firstWhere((j) => j.title == 'Clinical Informatics Nurse').found, '2026-10-24');
    });

    test('applications move through stages with follow-ups', () async {
      final id = (await book.importPostings([samplePosting()], sampleProfile, today: '2026-10-01')).single;
      final app = await book.applyFor(await book.job(id), today: '2026-10-01', sent: true);
      expect(await book.applyFor(await book.job(id), today: '2026-10-02'), app);
      var a = await book.application(app);
      expect(a.stage, 'applied');
      expect(a.applied, '2026-10-01');
      expect(a.followUp, '2026-10-11');
      expect((await book.job(id)).status, 'applied');

      await book.logEvent(app, 'interview', at: '2026-10-08T10:00');
      a = await book.application(app);
      expect(a.stage, 'interview');
      expect(a.followUp, '2026-10-13');

      // A later reply never moves it back.
      await book.logEvent(app, 'reply', at: '2026-10-09T10:00');
      expect((await book.application(app)).stage, 'interview');

      await book.logEvent(app, 'rejected', at: '2026-10-20T10:00');
      a = await book.application(app);
      expect(a.stage, 'rejected');
      expect(a.followUp, isNull);
    });

    test('silent applications go to No reply', () async {
      final id = (await book.importPostings([samplePosting()], sampleProfile, today: '2026-08-01')).single;
      await book.applyFor(await book.job(id), today: '2026-08-01', sent: true);
      expect(await book.markGhosted('2026-09-01'), 0);
      expect(await book.markGhosted('2026-10-24'), 1);
      final a = (await book.db.select(book.db.jobApplications).get()).single;
      expect(a.stage, Stage.noReply.id);
    });

    test('leads are not added twice', () async {
      const lead = LeadSuggestion({
        'name': 'Sam Recruiter',
        'company': 'Sample Care Group',
        'kind': 'recruiter',
      });
      expect(await book.importLeads([lead], today: '2026-10-24'), 1);
      expect(await book.importLeads([lead], today: '2026-10-25'), 0);
    });

    test('the profile round-trips through prefs', () async {
      await book.saveProfile(sampleProfile);
      final p = await book.profile();
      expect(p.name, sampleProfile.name);
      expect(p.targets.countries, ['GB', 'IE']);
      expect(p.experience.single.highlights, hasLength(2));
    });
  });

  group('helpers', () {
    test('local fit prefers matching titles and skills', () {
      final near = localFit(
        sampleProfile,
        title: 'Clinical Informatics Nurse',
        description: 'EPR systems and patient safety training',
      );
      final far = localFit(sampleProfile, title: 'Forklift Driver', description: 'Warehouse shifts');
      expect(near, greaterThan(far));
      expect(near, inInclusiveRange(0, 100));
    });

    test('answer metrics count fillers, ownership, figures and STAR', () {
      final m = AnswerMetrics.of(
        'Um, so basically we had late observations. I set up a pilot and I trained 40 staff. '
        'As a result late observations fell 30%.',
      );
      expect(m.fillers, 2);
      expect(m.iCount, 2);
      expect(m.weCount, 1);
      expect(m.figures, 2);
      expect(m.star, contains('Result'));
      expect(m.lengthVerdict, startsWith('Short'));
    });

    test('calendar files fold long lines without splitting characters', () {
      final ics = icsFile([
        (id: 'a1', title: 'Chase ${'é' * 60}', date: '2026-10-31', details: 'Ask about the shortlist'),
      ], stamp: '20261024T090000Z');
      for (final line in ics.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75), reason: line);
      }
      expect(ics, contains('DTSTART;VALUE=DATE:20261031'));
      expect(ics, contains('DTEND;VALUE=DATE:20261101'));
      final unfolded = ics.replaceAll('\r\n ', '');
      expect(unfolded, contains('SUMMARY:Chase ${'é' * 60}'));
    });

    test('a Google Calendar link spans the whole day', () {
      final u = googleCalendarLink(title: 'Chase', date: '2026-12-31');
      expect(u.queryParameters['dates'], '20261231/20270101');
    });

    test('a CV survives the Word round trip', () {
      final doc = ResumeDoc.fromProfile(sampleProfile);
      final text = docxText(doc.toDocx());
      expect(text, contains('Alex Example'));
      expect(text, contains('Led the e-observations pilot'));
    });

    test('follow-ups are due by stage', () {
      expect(followUpFor(Stage.applied, '2026-10-01'), '2026-10-11');
      expect(followUpFor(Stage.rejected, '2026-10-01'), isNull);
    });

    test('profiles round-trip through JSON', () {
      final p = CandidateProfile.fromJson(
        jsonDecode(jsonEncode(sampleProfile.toJson())) as Map<String, Object?>,
      );
      expect(p.searchTerms, sampleProfile.targets.roles);
      expect(p.searchCountries, ['GB', 'IE']);
    });
  });
}
