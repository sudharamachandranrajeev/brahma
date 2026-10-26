import 'dart:convert';
import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:udyoga/app/providers.dart';
import 'package:udyoga/app/security_checks.dart';
import 'package:udyoga/db/database.dart';
import 'package:udyoga/domain/answer_metrics.dart';
import 'package:udyoga/domain/book.dart';
import 'package:udyoga/domain/calendar.dart';
import 'package:udyoga/domain/ai.dart';
import 'package:udyoga/domain/claude.dart';
import 'package:udyoga/domain/feeds.dart';
import 'package:udyoga/domain/gemini.dart';
import 'package:udyoga/domain/insights.dart';
import 'package:udyoga/domain/matching.dart';
import 'package:udyoga/domain/n8n.dart';
import 'package:udyoga/domain/pipeline.dart';
import 'package:udyoga/domain/profile.dart';
import 'package:udyoga/domain/resume.dart';
import 'package:udyoga/domain/schema.dart';
import 'package:udyoga/domain/update.dart';

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
        model: 'claude-opus-5-5',
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
        model: 'claude-opus-5-5',
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
        Claude(
          apiKey: 'sk-bad',
          model: 'claude-opus-5-5',
          client: client,
        ).ask(system: 's', content: const [], schema: schema),
        throwsA(isA<AiException>().having((e) => e.message, 'message', contains('API key'))),
      );
      expect(calls, 1);
    });
  });

  group('Gemini', () {
    final schema = object({'answer': string(), 'sources': sourcesSchema});

    Map<String, Object?> interaction(String text, {List<Object?> annotations = const []}) => {
      'id': 'i1',
      'status': 'completed',
      'steps': [
        {'type': 'thought', 'summary': <Object?>[]},
        {
          'type': 'model_output',
          'content': [
            {'type': 'text', 'text': text, 'annotations': annotations},
          ],
        },
      ],
      'usage': {
        'total_input_tokens': 1000,
        'total_output_tokens': 40,
        'total_thought_tokens': 60,
        'grounding_tool_count': [
          {'type': 'google_search', 'count': 2},
        ],
      },
    };

    test('sends a structured request and reads the answer, sources and usage', () async {
      late Map<String, Object?> sent;
      late http.Request request;
      final client = MockClient((r) async {
        request = r;
        sent = jsonDecode(r.body) as Map<String, Object?>;
        return http.Response(
          jsonEncode(
            interaction(
              '{"answer":"yes","sources":[{"title":"Listed","url":"https://a.example"}]}',
              annotations: [
                {'type': 'url_citation', 'title': 'Read', 'url': 'https://b.example'},
                {'type': 'url_citation', 'title': 'Listed again', 'url': 'https://a.example'},
              ],
            ),
          ),
          200,
        );
      });
      AiUsage? usage;
      final r =
          await Gemini(
            apiKey: 'g-test',
            model: 'gemini-3.8-flash',
            client: client,
            onUsage: (u) => usage = u,
          ).ask(
            system: 's',
            content: [
              {'type': 'text', 'text': 'hello'},
              {
                'type': 'document',
                'source': {'type': 'base64', 'media_type': 'application/pdf', 'data': 'UERG'},
              },
            ],
            schema: schema,
            web: true,
            effort: 'medium',
          );
      expect(request.url.path, endsWith('/interactions'));
      expect(request.headers['x-goog-api-key'], 'g-test');
      expect(sent['store'], isFalse);
      expect(sent['response_format'], {'type': 'text', 'mime_type': 'application/json', 'schema': schema});
      expect(sent['tools'], [
        {'type': 'google_search'},
        {'type': 'url_context'},
      ]);
      expect((sent['generation_config'] as Map)['thinking_level'], 'medium');
      expect(sent['input'], [
        {'type': 'text', 'text': 'hello'},
        {'type': 'document', 'data': 'UERG', 'mime_type': 'application/pdf'},
      ]);
      expect(r.data['answer'], 'yes');
      expect(r.sources.map((s) => s.url), ['https://a.example', 'https://b.example']);
      expect(usage!.input, 1000);
      expect(usage!.output, 100);
      expect(usage!.searches, 2);
    });

    test('asks again when the answer breaks the schema', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode(interaction(calls == 1 ? '{"answer": 3' : '{"answer":"ok","sources":[]}')),
          200,
        );
      });
      final r = await Gemini(
        apiKey: 'g',
        model: 'gemini-3.8-flash',
        client: client,
      ).ask(system: 's', content: const [], schema: schema);
      expect(r.data['answer'], 'ok');
      expect(calls, 2);
    });

    test('explains a rejected key and a spent daily quota without retrying', () async {
      for (final (status, body, words) in [
        (400, '{"error":{"code":400,"message":"API key not valid.","status":"INVALID_ARGUMENT"}}', 'key'),
        (
          429,
          '{"error":{"code":429,"details":[{"violations":[{"quotaId":"GenerateRequestsPerDayPerProjectPerModel-FreeTier"}]}]}}',
          'daily',
        ),
      ]) {
        var calls = 0;
        final client = MockClient((_) async {
          calls++;
          return http.Response(body, status);
        });
        await expectLater(
          Gemini(apiKey: 'g', model: 'gemini-3.8-flash', client: client).check(),
          throwsA(isA<AiException>().having((e) => e.message, 'message', contains(words))),
        );
        expect(calls, 1);
      }
    });

    test('waits as long as Google asks at the per-minute limit, and reads a fenced answer', () async {
      var calls = 0;
      final said = <String>[];
      final client = MockClient((_) async {
        if (++calls == 1) {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 429,
                'message': 'Quota exceeded.',
                'details': [
                  {
                    'violations': [
                      {'quotaId': 'GenerateRequestsPerMinutePerProjectPerModel-FreeTier', 'quotaValue': '5'},
                    ],
                  },
                  {'retryDelay': '1s'},
                ],
              },
            }),
            429,
          );
        }
        return http.Response(jsonEncode(interaction('```json\n{"answer":"ok","sources":[]}\n```')), 200);
      });
      final r = await Gemini(
        apiKey: 'g',
        model: 'gemini-3.8-flash',
        client: client,
      ).ask(system: 's', content: const [], schema: schema, onProgress: said.add);
      expect(r.data['answer'], 'ok');
      expect(calls, 2);
      expect(said, contains(contains('waiting 1 s')));
    });

    test('a model outside the free tier is said plainly, without retrying', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(
          '{"error":{"code":429,"details":[{"violations":[{"quotaId":"GenerateRequestsPerMinutePerProjectPerModel-FreeTier","quotaValue":"0"}]}]}}',
          429,
        );
      });
      await expectLater(
        Gemini(
          apiKey: 'g',
          model: 'gemini-3.8-flash',
          client: client,
        ).ask(system: 's', content: const [], schema: schema),
        throwsA(isA<AiException>().having((e) => e.message, 'message', contains('does not include'))),
      );
      expect(calls, 1);
    });

    test('the chosen model is used only when its service has a key', () {
      expect(effectiveModel('', {}), isNull);
      expect(effectiveModel('claude-opus-5-5', {AiProvider.gemini: 'g'}), 'gemini-3.8-flash');
      expect(effectiveModel('gemini-3.5-flash-lite', {AiProvider.gemini: 'g'}), 'gemini-3.5-flash-lite');
      expect(effectiveModel('', {AiProvider.claude: 'sk', AiProvider.gemini: 'g'}), 'claude-opus-5-5');
    });
  });

  group('updates', () {
    test('versions compare number by number, ignoring a pre-release suffix', () {
      expect(isNewer('0.10.0', '0.9.9'), isTrue);
      expect(isNewer('v0.3.0-beta.1', '0.2.0'), isTrue);
      expect(isNewer('0.2.0', '0.2.0'), isFalse);
      expect(isNewer('0.2', '0.2.1'), isFalse);
    });

    Map<String, Object?> release(String tag, {bool draft = false}) => {
      'tag_name': tag,
      'draft': draft,
      'body': 'Notes',
      'assets': [
        for (final name in ['Udyoga-x-linux-x64.tar.gz', 'Udyoga-x-android.apk', checksumsName])
          {'name': name, 'browser_download_url': 'https://dl.example/$name', 'size': 4},
      ],
    };

    test('the newest published release with a file for this device is offered', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode([release('v0.2.0'), release('v0.4.0', draft: true), release('v0.3.0')]),
          200,
        ),
      );
      Updater u(String os, String current) =>
          Updater(client, current: current, os: os, dir: Directory.systemTemp);
      expect((await u('linux', '0.2.0').check())?.version, '0.3.0');
      expect(await u('linux', '0.3.0').check(), isNull);
      expect(await u('windows', '0.2.0').check(), isNull);
    });

    test('a download is kept only when it matches its checksum', () async {
      final dir = await Directory.systemTemp.createTemp('udyoga-update');
      addTearDown(() => dir.delete(recursive: true));
      final data = utf8.encode('tarball');
      for (final (sum, ok) in [(sha256.convert(data).toString(), true), ('0' * 64, false)]) {
        final client = MockClient(
          (r) async => r.url.path.endsWith(checksumsName)
              ? http.Response('$sum  Udyoga-x-linux-x64.tar.gz\n', 200)
              : http.Response.bytes(data, 200),
        );
        final u = Updater(client, current: '0.1.0', os: 'linux', dir: dir);
        final download = u.download(Release.fromJson(release('v0.3.0')));
        if (ok) {
          expect(await (await download).readAsBytes(), data);
        } else {
          await expectLater(download, throwsA(isA<UpdateException>()));
          expect(dir.listSync().where((f) => f.path.endsWith('.part')), isEmpty);
        }
      }
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

  group('n8n', () {
    late CareerBook book;
    setUp(() async => book = CareerBook(await Store.open(memoryDatabase())));
    tearDown(() => book.db.close());

    Future<Job> job() async =>
        book.job((await book.importPostings([samplePosting()], sampleProfile, today: '2026-10-24')).single);

    test('sends the job and direction, never who the candidate is', () async {
      late http.Request seen;
      final client = MockClient((r) async {
        seen = r;
        return http.Response(
          jsonEncode([
            {
              'leads': [
                {'name': 'Sam Recruiter', 'company': 'Example Health Trust', 'kind': 'agency'},
                {'name': '', 'company': 'nobody'},
              ],
            },
          ]),
          200,
        );
      });
      const link = N8nLink(url: 'https://n8n.example.com/webhook/udyoga-leads', secret: 's3');
      final leads = await n8nLeads(client, link, sampleProfile, await job());
      expect(seen.headers['x-udyoga-secret'], 's3');
      expect(seen.body, isNot(contains(sampleProfile.name)));
      expect(seen.body, contains('Clinical Informatics Nurse'));
      expect(leads.single.name, 'Sam Recruiter');
      expect(leads.single.kind, 'other');
      expect(leads.single.approach, '');
      expect(await book.importLeads(leads, today: '2026-10-24'), 1);
    });

    test('refuses plain http to the internet and explains failures', () async {
      expect(() => N8nLink.check('http://n8n.example.com/webhook/x'), throwsA(isA<N8nException>()));
      expect(N8nLink.check('http://192.168.1.20:5678/webhook/x').host, '192.168.1.20');
      final j = await job();
      for (final (status, text) in [(403, 'secret'), (404, 'active'), (200, 'leads')]) {
        final client = MockClient((_) async => http.Response(status == 200 ? '{}' : '', status));
        await expectLater(
          n8nLeads(client, const N8nLink(url: 'https://n8n.example.com/webhook/x'), sampleProfile, j),
          throwsA(isA<N8nException>().having((e) => e.message, 'message', contains(text))),
        );
      }
    });

    test('Sentinel reports a workflow on the LAN in clear, and one without a secret', () async {
      Future<List<String>> ids(N8nLink link) async {
        final c = ProviderContainer(overrides: [n8nLinkProvider.overrideWithValue(AsyncData(link))]);
        addTearDown(c.dispose);
        return [for (final f in await c.read(n8nCheck.findings.future)) f.id];
      }

      expect(await ids(const N8nLink()), isEmpty);
      expect(await ids(const N8nLink(url: 'https://n8n.example.com/webhook/x', secret: 's3')), isEmpty);
      expect(await ids(const N8nLink(url: 'http://192.168.1.20:5678/webhook/x')), [
        'udyoga.n8n.http',
        'udyoga.n8n.secret',
      ]);
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
