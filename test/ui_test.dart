import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vani/app/providers.dart';

import 'app_harness.dart';
import 'fake_hub.dart';

/// Every page builds, with and without data, on phone and desktop widths,
/// without throwing or overflowing; and the main flows against the fake hub.
void main() {
  final pages = [for (final t in VaniTab.values) t.label];

  testWidgets('every page builds on a desktop window', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    expect(find.textContaining('Sam'), findsWidgets);
    for (final label in pages) {
      await app.go(label);
      expect(tester.takeException(), isNull, reason: label);
    }
    await app.close();
  });

  testWidgets('every page builds on a phone, in light and dark', (tester) async {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      final app = AppHarness(tester)..phone();
      await app.open(theme: theme);
      await app.run();
      for (final label in pages) {
        await app.go(label);
        expect(tester.takeException(), isNull, reason: '$label ($theme)');
      }
      await app.close();
    }
  });

  testWidgets('without a hub every page asks to connect one, then loads', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(connected: false);
    await app.run();
    expect(find.text('Connect your social hub'), findsOneWidget);
    await app.go('Inbox');
    expect(find.text('Connect your social hub'), findsOneWidget);
    expect(app.hub.log, isEmpty);

    await app.tapText('Connect hub');
    await app.enter('Hub address', 'http://example.com');
    await app.enter('API token', hubToken);
    await app.tapText('Connect');
    expect(find.textContaining('https'), findsWidgets, reason: 'plain http is refused off the local network');
    await app.enter('Hub address', hubUrl);
    await app.tapText('Connect');
    expect(find.text('Connect your social hub'), findsNothing);
    expect(find.textContaining('Riley Example'), findsWidgets);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('a hub with no accounts points to Accounts', (tester) async {
    final app = AppHarness(tester, hub: FakeHub(seeded: false))..desktop();
    await app.open();
    await app.run();
    expect(find.text('Connect your first account'), findsOneWidget);
    for (final label in pages) {
      await app.go(label);
      expect(tester.takeException(), isNull, reason: label);
    }
    await app.close();
  });

  testWidgets('compose and post now', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.compose();
    await app.tapText('Sam Example');
    await app.enter('Post text', 'Open studio this Saturday, 10 to 4.');
    await app.tapText('Now');
    await app.tapText('Post now');
    expect(tester.takeException(), isNull);
    final sent = app.hub.bodies['POST /social/posts']! as Map;
    expect(sent['text'], 'Open studio this Saturday, 10 to 4.');
    expect((sent['targets'] as List).single['accountId'], 'a4');
    expect(app.hub.posts.last['status'], 'published');
    expect(find.text('Post text'), findsNothing, reason: 'the composer closes');
    await app.close();
  });

  testWidgets('reply to a comment from the inbox', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Inbox');
    await app.tapText('What clay body do you use for the speckled ones?');
    await tester.enterText(
      find.widgetWithText(TextField, 'Reply to Jordan Sample'),
      'A buff stoneware with iron.',
    );
    await app.tap(find.byTooltip('Send'));
    expect(app.hub.bodies['POST /social/inbox/i1/reply'], {'text': 'A buff stoneware with iron.'});
    expect(app.hub.inbox[1]['status'], 'done');
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('turn a rule on', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Alerts');
    await app.segment('Rules');
    expect(find.text('Price requests'), findsOneWidget);
    await app.tap(find.byType(Switch).last);
    final saved = app.hub.bodies['PUT /social/rules']! as List;
    expect(saved.map((r) => r['enabled']), [true, true]);
    await app.close();
  });

  testWidgets('describe a discovery watch, check it and save it', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Alerts');
    await app.segment('Discovery');
    await app.enter('What are you looking for?', 'A small automatic car under 6000');
    await app.enter('Postcode (optional)', 'EX1 1AA');
    await app.tapText('Draft a watch');
    expect(app.hub.bodies['POST /social/discovery/suggest'], {
      'description': 'A small automatic car under 6000',
      'postcode': 'EX1 1AA',
    });
    expect(find.text('Small automatic hatchbacks'), findsWidgets);
    await app.tapText('Save');
    final saved = app.hub.bodies['PUT /social/discovery']! as List;
    expect(saved, hasLength(3));
    expect(saved.last['id'], isNotEmpty);
    expect(tester.takeException(), isNull);

    await app.tap(find.text('Run now').first);
    expect(find.textContaining('DoneDeal: the site answered 503.'), findsOneWidget);
    expect(find.text('2016 hatchback, automatic, 48k miles'), findsOneWidget);
    await app.close();
  });

  testWidgets('without an Anthropic key the AI buttons explain why', (tester) async {
    final app = AppHarness(tester, hub: FakeHub(ai: false))..desktop();
    await app.open();
    await app.run();
    await app.go('Alerts');
    await app.segment('Discovery');
    await app.enter('What are you looking for?', 'A small automatic car');
    await app.tapText('Draft a watch');
    expect(app.hub.log.where((l) => l.contains('suggest')), isEmpty);
    expect(find.textContaining('Add your Anthropic API key'), findsWidgets);
    await app.close();
  });

  testWidgets('add a Bluesky account', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Accounts');
    await app.tapText('With an app password');
    await app.enter('Handle', '@studio.example.social');
    await app.enter('App password', 'abcd-efgh-ijkl-mnop');
    await app.tapText('Add');
    expect(app.hub.bodies['POST /social/accounts/bluesky'], {
      'handle': 'studio.example.social',
      'appPassword': 'abcd-efgh-ijkl-mnop',
    });
    expect(app.hub.accounts, hasLength(6));
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('connecting without app credentials opens them with the URLs to paste', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Accounts');
    await app.tapText('Threads profile');
    expect(app.hub.log.where((l) => l.contains('/connect/')), isEmpty);
    expect(find.text('$hubUrl/social/oauth/threads/callback'), findsOneWidget);
    expect(find.text('$hubUrl/social/webhook/threads'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });
}
