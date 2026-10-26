import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Setup extends HelpAiSettings {
  _Setup(this.initial);
  final HelpAiSetup initial;
  @override
  Future<HelpAiSetup> build() async => initial;
}

const _hints = {
  'nav.home': 'Your day.',
  'page.home': 'Three quests a day.',
  'action.focus': 'A quiet timer.',
};

const _turn = <HelpTurn>[(user: true, text: 'How do I sync?')];

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  test('the guide holds the screens, page tips, buttons and the shared parts', () {
    final p = helpSystemPrompt(app: 'Vidya', hints: _hints);
    expect(p, contains('- home: Your day.'));
    expect(p, contains('- home: Three quests a day.'));
    expect(p, contains('- action.focus: A quiet timer.'));
    expect(p, contains('Sync setup wizard'));
    expect(p, contains('Never ask for passwords'));
    expect(
      helpQuestion(question: 'What now?', screen: 'Home', topic: 'Three quests a day.'),
      'I am on the Home screen.\nIt says: Three quests a day.\nWhat now?',
    );
  });

  test('chat websites open with the question, except Gemini, which takes none', () {
    final long = 'x' * 3000;
    final gpt = chatLink(chatSites[0], 'How do I sync?');
    expect(gpt.host, 'chatgpt.com');
    expect(gpt.queryParameters['q'], 'How do I sync?');
    expect(chatLink(chatSites[1], long).queryParameters['q']!.length, lessThan(1900));
    expect(chatLink(chatSites[2], 'How?').hasQuery, isFalse);
  });

  test('the setup reads back, with each service\'s defaults', () {
    final s = HelpAiSetup.fromJson(
      jsonDecode(jsonEncode(const HelpAiSetup(via: HelpAi.local, base: 'http://10.0.0.5:11434/v1').toJson())),
    );
    expect(s.via, HelpAi.local);
    expect(s.effectiveBase, 'http://10.0.0.5:11434/v1');
    expect(HelpAiSetup.fromJson('junk').via, HelpAi.chat);
    expect(const HelpAiSetup(via: HelpAi.anthropic).effectiveModel, 'claude-opus-5-5');
  });

  test('Gemini gets the guide as the system instruction and its key in a header', () async {
    late http.Request sent;
    final asker = HelpAsker(
      const HelpAiSetup(via: HelpAi.gemini),
      key: ' k1 ',
      client: MockClient((r) async {
        sent = r;
        return _json({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Open '},
                  {'text': 'Settings.'},
                ],
              },
            },
          ],
        });
      }),
    );
    expect(await asker.ask('GUIDE', _turn), 'Open Settings.');
    expect(sent.url.path, endsWith('/models/gemini-3.5-flash-lite:generateContent'));
    expect(sent.headers['x-goog-api-key'], 'k1');
    final body = jsonDecode(sent.body) as Map;
    expect(jsonEncode(body['system_instruction']), contains('GUIDE'));
    expect((body['contents'] as List).single['role'], 'user');
  });

  test('Claude by API key: low effort, server-side fallbacks, refusals reported', () async {
    late http.Request sent;
    var refuse = false;
    final asker = HelpAsker(
      const HelpAiSetup(via: HelpAi.anthropic),
      key: 'sk',
      client: MockClient((r) async {
        sent = r;
        return _json({
          'stop_reason': refuse ? 'refusal' : 'end_turn',
          'content': [
            {'type': 'thinking', 'thinking': ''},
            {'type': 'text', 'text': 'Settings > Sync.'},
          ],
        });
      }),
    );
    expect(await asker.ask('GUIDE', _turn), 'Settings > Sync.');
    expect(sent.headers['x-api-key'], 'sk');
    expect(sent.headers['anthropic-beta'], 'server-side-fallback-2026-07-01');
    final body = jsonDecode(sent.body) as Map;
    expect(body['model'], 'claude-opus-5-5');
    expect(body['output_config'], {'effort': 'low'});
    expect(body['fallbacks'], 'default');
    expect(body.containsKey('temperature'), isFalse);
    refuse = true;
    await expectLater(asker.ask('GUIDE', _turn), throwsA(isA<AskAiException>()));
  });

  test('a local server may be plain http at home, never on the internet', () async {
    final client = MockClient(
      (r) async => _json({
        'choices': [
          {
            'message': {'content': 'Tap Sync now.'},
          },
        ],
      }),
    );
    HelpAsker local(String base) => HelpAsker(
      HelpAiSetup(via: HelpAi.local, base: base, model: 'gemma3'),
      client: client,
    );
    expect(await local('http://192.168.1.4:11434/v1').ask('G', _turn), 'Tap Sync now.');
    expect(await local('http://localhost:1234/v1/').ask('G', _turn), 'Tap Sync now.');
    await expectLater(
      local('http://example.com/v1').ask('G', _turn),
      throwsA(isA<AskAiException>().having((e) => e.message, 'message', contains('https'))),
    );
  });

  test('keys are needed, and a refused key says so', () async {
    final none = HelpAsker(const HelpAiSetup(via: HelpAi.openai, model: 'm'));
    await expectLater(
      none.ask('G', _turn),
      throwsA(isA<AskAiException>().having((e) => e.message, 'message', contains('key first'))),
    );
    final bad = HelpAsker(
      const HelpAiSetup(via: HelpAi.openai, model: 'm'),
      key: 'bad',
      client: MockClient(
        (r) async => _json({
          'error': {'message': 'Incorrect API key'},
        }, 401),
      ),
    );
    await expectLater(
      bad.ask('G', _turn),
      throwsA(isA<AskAiException>().having((e) => e.message, 'message', contains('Incorrect API key'))),
    );
  });

  Future<void> open(WidgetTester tester, HelpAiSetup setup, {http.Client? client}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appIdentityProvider.overrideWithValue(
            const AppIdentity(id: 'vidya', name: 'Vidya', androidPackage: 'dev.brahma.vidya'),
          ),
          hintTextsProvider.overrideWithValue(_hints),
          helpAiProvider.overrideWith(() => _Setup(setup)),
          helpAskerProvider.overrideWithValue((s) async => HelpAsker(s, key: 'k', client: client)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => const AskAiButton(screen: 'Home', topic: 'Tip'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();
  }

  testWidgets('with no setup, Ask AI hands the question to a chat website', (tester) async {
    await open(tester, const HelpAiSetup());
    expect(find.text('Answers from: A chat website'), findsOneWidget);
    expect(find.text('Ask ChatGPT'), findsOneWidget);
    expect(find.text('Ask Claude'), findsOneWidget);
    expect(find.text('Ask Gemini'), findsOneWidget);
    expect(find.byIcon(Icons.send), findsNothing);
  });

  testWidgets('with an AI set up, the answer appears in the dialog', (tester) async {
    late String asked;
    await open(
      tester,
      const HelpAiSetup(via: HelpAi.gemini),
      client: MockClient((r) async {
        asked = r.body;
        return _json({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Choose Learn, then New program.'},
                ],
              },
            },
          ],
        });
      }),
    );
    await tester.enterText(find.byType(TextField), 'How do I start a course?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(find.text('Choose Learn, then New program.'), findsOneWidget);
    expect(asked, contains('I am on the Home screen'));
    expect(asked, contains('How do I start a course?'));
  });
}
