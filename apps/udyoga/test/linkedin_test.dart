import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udyoga/ui/carousel.dart';
import 'package:udyoga/domain/ai.dart';
import 'package:udyoga/domain/book.dart';
import 'package:udyoga/domain/claude_code.dart';
import 'package:udyoga/domain/humanizer.dart';
import 'package:udyoga/domain/json.dart';
import 'package:udyoga/domain/linkedin.dart';
import 'package:udyoga/domain/pdf.dart';
import 'package:udyoga/domain/schema.dart';

import 'support.dart';

/// A stand-in for the Claude Code process: prints [out] and exits.
class FakeProcess implements Process {
  FakeProcess(String out, {String err = '', int code = 0})
    : stdout = Stream.value(utf8.encode(out)),
      stderr = Stream.value(utf8.encode(err)),
      exitCode = Future.value(code);

  @override
  final Stream<List<int>> stdout, stderr;
  @override
  final Future<int> exitCode;
  final _sink = _NullSink();
  @override
  IOSink get stdin => _sink;
  @override
  int get pid => 1;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}

class _NullSink implements IOSink {
  final text = StringBuffer();
  @override
  Encoding encoding = utf8;
  @override
  void write(Object? o) => text.write(o);
  @override
  Future close() async {}
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

String lines(List<Map<String, Object?>> events) => '${events.map(jsonEncode).join('\n')}\n';

void main() {
  group('humanizer', () {
    test('removes dashes, invisible marks and stock phrases but keeps links', () {
      final c = humanize(
        'We leverage synergy \u2014 and it\u2019s \u201Cseamless\u201D.\u200B See https://example.com/a\u2014b now.',
      );
      expect(c.text.replaceFirst('a\u2014b', ''), isNot(contains('\u2014')));
      expect(c.text, isNot(contains('\u200B')));
      expect(c.text, isNot(contains('\u2019')));
      expect(c.text.toLowerCase(), isNot(contains('leverage')));
      expect(c.text, contains('https://example.com/a\u2014b'));
      expect(c.fixes, greaterThan(2));
    });

    test('flags hollow words and scores plain writing above stock writing', () {
      final plain = humanize(
        'I rewrote our CV last March. 14 applications, 3 interviews. It took me two weeks to see why: '
        'the first line said nothing. So I changed it, and Sam from the Belfast trust replied the next day.',
      );
      final stock = humanize(
        'Passionate, results-driven, team player. Leverage your potential. Unlock success. Thrilled to '
        'announce a seamless journey of growth.',
      );
      expect(plain.overall, greaterThan(stock.overall));
      expect(stock.flags, isNotEmpty);
      expect(plain.scores.keys, humanChecks.keys);
    });

    test('is idempotent', () {
      final once = humanize('A \u2014 B \u2026 C').text;
      expect(humanize(once).text, once);
    });
  });

  group('Claude subscription', () {
    final at = DateTime.utc(2026, 10, 25, 9);
    final grant = ClaudeCodeGrant(at: at, account: 'a@example.com', exe: '/usr/bin/claude');

    test('grant lapses after 24 hours and survives JSON', () {
      expect(grant.activeAt(at.add(const Duration(hours: 23, minutes: 59))), isTrue);
      expect(grant.activeAt(at.add(const Duration(hours: 24))), isFalse);
      final again = ClaudeCodeGrant.fromJson(grant.toJson());
      expect(again.at, at);
      expect(again.account, 'a@example.com');
    });

    test('answers from stream-json and reports progress', () async {
      final progress = <String>[];
      final ai = ClaudeCode(
        grant: grant,
        model: '${ClaudeCodeModels.prefix}claude-sonnet-5-5',
        now: () => at.add(const Duration(hours: 1)),
        start: (exe, args, {workingDirectory, runInShell = false}) async {
          expect(args, containsAllInOrder(['--model', 'claude-sonnet-5-5']));
          expect(args, isNot(contains('--bare')));
          return FakeProcess(
            lines([
              {
                'type': 'assistant',
                'message': {
                  'content': [
                    {
                      'type': 'tool_use',
                      'name': 'WebSearch',
                      'input': {'query': 'ward jobs'},
                    },
                  ],
                },
              },
              {
                'type': 'result',
                'subtype': 'success',
                'is_error': false,
                'structured_output': {'name': 'ok'},
              },
            ]),
          );
        },
      );
      final r = await ai.ask(
        system: 's',
        content: [
          {'type': 'text', 'text': 'hi'},
        ],
        schema: object({'name': string()}),
        web: true,
        onProgress: progress.add,
      );
      expect(r.data['name'], 'ok');
      expect(progress, contains('Searching: ward jobs'));
    });

    test('refuses after the grant lapses, without starting Claude Code', () {
      final ai = ClaudeCode(
        grant: grant,
        model: '${ClaudeCodeModels.prefix}claude-opus-5-5',
        now: () => at.add(const Duration(hours: 25)),
        start: (exe, args, {workingDirectory, runInShell = false}) => fail('must not start'),
      );
      expect(
        ai.ask(system: 's', content: const [], schema: object({'name': string()})),
        throwsA(isA<AiException>().having((e) => e.message, 'message', claudeCodeExpired)),
      );
    });

    test('an answer that breaks the schema is rejected', () {
      final ai = ClaudeCode(
        grant: grant,
        model: '${ClaudeCodeModels.prefix}claude-opus-5-5',
        now: () => at,
        start: (exe, args, {workingDirectory, runInShell = false}) async => FakeProcess(
          lines([
            {
              'type': 'result',
              'subtype': 'success',
              'is_error': false,
              'structured_output': {'name': 3},
            },
          ]),
        ),
      );
      expect(
        ai.ask(system: 's', content: const [], schema: object({'name': string()})),
        throwsA(isA<AiException>()),
      );
    });

    test('a signed-out Claude Code is reported', () {
      final ai = ClaudeCode(
        grant: grant,
        model: '${ClaudeCodeModels.prefix}claude-opus-5-5',
        now: () => at,
        start: (exe, args, {workingDirectory, runInShell = false}) async =>
            FakeProcess('', err: 'Not logged in. Please run /login', code: 1),
      );
      expect(
        ai.ask(system: 's', content: const [], schema: object({'name': string()})),
        throwsA(isA<AiException>().having((e) => e.message, 'message', contains('not signed in'))),
      );
    });

    test('auth status is read from its JSON', () async {
      final a = await ClaudeCodeCli.status(
        '/x/claude',
        start: (exe, args, {workingDirectory, runInShell = false}) async =>
            FakeProcess('{"loggedIn":true,"authMethod":"claude.ai","email":"a@example.com"}'),
      );
      expect((a.loggedIn, a.subscription, a.account), (true, true, 'a@example.com'));
    });

    test('grant and the update switch are stored on the device', () async {
      final book = CareerBook(await Store.open(memoryDatabase()));
      expect(await book.claudeCodeGrant(), isNull);
      expect(await book.updateOnStart(), isTrue);
      await book.setClaudeCodeGrant(grant);
      expect((await book.claudeCodeGrant())!.account, 'a@example.com');
      final keys = await book.aiKeys();
      expect(keys[AiProvider.claudeCode], 'subscription');
      expect(effectiveModel('', keys), AiProvider.claudeCode.defaultModel);
      await book.setClaudeCodeGrant(null);
      expect(await book.claudeCodeGrant(), isNull);
      await book.setUpdateOnStart(false);
      expect(await book.updateOnStart(), isFalse);
    });
  });

  group('LinkedIn', () {
    test('rubric adds to 100 and hooks are numbered', () {
      expect(profileRubric.fold(0, (a, r) => a + r.points), 100);
      expect([for (final h in hooks) h.id], [for (var i = 1; i <= hooks.length; i++) i]);
      for (final h in hooks) {
        expect(h.example, isNot(contains('\u2014')));
      }
    });

    test('every tool but the human check has a prompt and fields', () {
      for (final t in LinkedInTool.values) {
        expect(t.fields, isNotEmpty);
        expect(LinkedInTool.ofKind(t.kind), t);
      }
    });

    test('a coach answer is cleaned and checked against the schema', () async {
      Json? seen;
      final coach = LinkedInCoach(
        _Canned((system, content, schema) {
          seen = {'system': system, 'text': jsonEncode(content)};
          return {
            'headline': 'Good',
            'score': -1,
            'scoreAfter': -1,
            'sections': [
              {
                'title': 'Post',
                'blocks': [
                  {
                    'label': 'Post: #5',
                    'text': 'I leverage it \u2014 daily.',
                    'copy': true,
                    'limit': 3000,
                    'note': '',
                    'write': false,
                  },
                ],
              },
            ],
            'next': 'Post it',
          };
        }),
        today: '2026-10-25',
      );
      final r = await coach.run(
        LinkedInTool.post,
        {'idea': 'I fixed the rota'},
        sampleProfile,
        voice: 'Dry and short.',
      );
      final text = (r.data['sections'] as List).first['blocks'].first['text'] as String;
      expect(text, isNot(contains('\u2014')));
      expect(violation(deliverableSchema, r.data), isNull);
      expect(seen!['system'], contains('never invent'.replaceFirst('n', 'N')));
      expect(seen!['text'], contains('Dry and short.'));
      expect(seen!['text'], contains('I fixed the rota'));
    });

    test('the plan and repurpose prompts carry the hook list', () async {
      for (final tool in [LinkedInTool.plan, LinkedInTool.repurpose]) {
        var sent = '';
        await LinkedInCoach(
          _Canned((system, content, schema) {
            sent = jsonEncode(content);
            return {'headline': '', 'score': -1, 'scoreAfter': -1, 'sections': <Object?>[], 'next': ''};
          }),
          today: '2026-10-25',
        ).run(tool, const {}, sampleProfile);
        expect(sent, contains(hooks.last.name), reason: tool.name);
      }
    });

    test('the carousel schema requires slides', () {
      final ok = {
        'headline': 'h',
        'score': -1,
        'scoreAfter': -1,
        'sections': <Object?>[],
        'next': 'n',
        'slides': [
          {'title': 't', 'body': 'b'},
        ],
      };
      expect(violation(carouselSchema, ok), isNull);
      expect(violation(carouselSchema, {...ok}..remove('slides')), isNotNull);
    });
  });

  group('PDF', () {
    test('writes pages with a correct cross-reference table', () {
      final page = (width: 2, height: 2, rgb: Uint8List(12));
      final bytes = imagePdf([page, page]);
      final s = latin1.decode(bytes);
      expect(s, startsWith('%PDF-1.4'));
      expect(s, contains('/Count 2'));
      expect(s.trimRight(), endsWith('%%EOF'));
      final start = int.parse(RegExp(r'startxref\n(\d+)').firstMatch(s)![1]!);
      expect(s.substring(start), startsWith('xref'));
      for (final m in RegExp(r'(\d{10}) 00000 n').allMatches(s)) {
        expect(s.substring(int.parse(m[1]!)), matches(RegExp(r'^\d+ 0 obj')));
      }
    });
  });

  testWidgets('the carousel renders to a PDF page per slide', (tester) async {
    final bytes = (await tester.runAsync(
      () => carouselPdf([
        (title: 'Cover', body: 'A promise'),
        (title: 'One idea', body: 'Short.'),
      ], name: 'Alex Example'),
    ))!;
    final s = latin1.decode(bytes);
    expect(s, startsWith('%PDF-1.4'));
    expect(s, contains('/Count 2'));
    expect(s, contains('/Width 1080 /Height 1350'));
  });
}

class _Canned implements Ai {
  _Canned(this.answer);
  final Json Function(String system, List<Json> content, Json schema) answer;

  @override
  String get model => 'test';

  @override
  Future<AiResult> ask({
    required String system,
    required List<Json> content,
    required Json schema,
    bool web = false,
    int searches = 8,
    String effort = 'high',
    int maxTokens = 32000,
    void Function(String status)? onProgress,
  }) async => AiResult(answer(system, content, schema));
}
