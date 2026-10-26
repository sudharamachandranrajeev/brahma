import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vani/app/app.dart';
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

  testWidgets('a new profile switches the whole app; switching back brings the data back', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    expect(find.text('Connect your first account'), findsNothing);
    await app.tap(find.byTooltip('Profile: Main'));
    await app.tapText('New profile');
    await app.enter('Name', 'Pottery shop');
    await app.tapText('Create');
    expect(find.byTooltip('Profile: Pottery shop'), findsOneWidget);
    expect(find.text('Connect your first account'), findsOneWidget);
    final shop = app.hub.profileHubs.keys.single;
    expect(app.hub.profileHubs[shop]!.log, contains('GET /social/overview'));

    // Every page now works in the new, empty profile.
    for (final label in pages) {
      await app.go(label);
      expect(tester.takeException(), isNull, reason: label);
    }

    await app.tap(find.byTooltip('Profile: Pottery shop'));
    await app.tapText('Main');
    expect(find.byTooltip('Profile: Main'), findsOneWidget);
    await app.go('Accounts');
    expect(
      find.text('No accounts yet. Add your developer app credentials below, then connect.'),
      findsNothing,
    );

    // Delete it from Settings (once the "Now managing" message has gone from over the rail).
    await tester.pump(const Duration(seconds: 6));
    await app.settle();
    await app.go('Settings');
    await app.tap(find.byTooltip('Delete Pottery shop'));
    await app.tapText('Delete');
    expect(app.hub.profiles.map((p) => p['name']), ['Main']);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('a profile deleted elsewhere falls back to the main one', (tester) async {
    final hub = FakeHub();
    hub.profiles.add({'id': 'gone', 'name': 'Gone', 'createdAt': '2026-01-02T00:00:00.000Z'});
    hub.profileHubs['gone'] = FakeHub(seeded: false);
    final app = AppHarness(tester, hub: hub)..desktop();
    await app.open();
    await app.run();
    await app.tap(find.byTooltip('Profile: Main'));
    await app.tapText('Gone');
    expect(find.byTooltip('Profile: Gone'), findsOneWidget);
    hub.profiles.removeLast();
    hub.profileHubs.remove('gone');
    ProviderScope.containerOf(tester.element(find.byType(VaniApp))).read(hubRevisionProvider.notifier).bump();
    await app.settle();
    expect(find.byTooltip('Profile: Main'), findsOneWidget);
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

  testWidgets('translate a comment, reply in its language and hide it', (tester) async {
    final app = AppHarness(tester)..desktop();
    (app.hub.inbox[1]['triage']! as Map)['lang'] = 'es';
    await app.open();
    await app.run();
    await app.go('Inbox');
    await app.tapText('What clay body do you use for the speckled ones?');
    await app.tapText('Translate');
    expect(find.text('Translated: What clay body do you use for the speckled ones?'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Reply to Jordan Sample'), 'Buff stoneware.');
    await app.tapText('Reply in Spanish');
    expect(find.text('[Spanish] Buff stoneware.'), findsOneWidget);
    await app.tap(find.byTooltip('Moderate'));
    await app.tapText('Hide from the public');
    expect(app.hub.bodies['POST /social/inbox/i1/moderate'], {'action': 'hide'});
    expect(app.hub.inbox[1]['moderation'], 'hidden');
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('deleting a comment asks first', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Inbox');
    await app.tapText('These are gorgeous! Do you ship to Ireland?');
    await app.tap(find.byTooltip('Moderate'));
    await app.tapText('Delete');
    expect(find.text('Delete this comment?'), findsOneWidget);
    await app.tapText('Delete');
    expect(app.hub.inbox[0]['moderation'], 'deleted');
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

  testWidgets('without any AI set up the AI buttons explain why', (tester) async {
    final app = AppHarness(tester, hub: FakeHub(ai: false))..desktop();
    await app.open();
    await app.run();
    await app.go('Alerts');
    await app.segment('Discovery');
    await app.enter('What are you looking for?', 'A small automatic car');
    await app.tapText('Draft a watch');
    expect(app.hub.log.where((l) => l.contains('suggest')), isEmpty);
    expect(find.textContaining('Set up AI in Settings > AI'), findsWidgets);
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

  testWidgets('add a Telegram channel', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Accounts');
    await app.tapText('Telegram');
    await app.enter('Bot token', '123456789:AAexample-token-for-the-test-only');
    await app.enter('Channel or group', '@studio');
    await app.tapText('Add');
    expect(app.hub.bodies['POST /social/accounts/telegram'], {
      'botToken': '123456789:AAexample-token-for-the-test-only',
      'chat': '@studio',
    });
    expect(app.hub.accounts.last['platform'], 'telegram');
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('send the weekly summary from Settings', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Settings');
    await app.tapText('Send this week\'s summary now');
    expect(app.hub.log, contains('POST /social/ai/weekly'));
    expect(app.hub.alerts.first['kind'], 'summary');
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('add a Gemini key in Settings > AI and pick its model', (tester) async {
    final app = AppHarness(tester, hub: FakeHub(ai: false))..desktop();
    await app.open();
    await app.run();
    await app.go('Settings');
    await app.tapText('Google Gemini');
    await app.enter('API key', 'g-key');
    await app.tapText('Save');
    await app.settle();
    expect(app.hub.credentials['gemini'], isNotNull);
    expect(find.text('Key set · in use'), findsOneWidget);
    expect(app.hub.log, contains('GET /social/ai/models?provider=gemini'));

    await app.tap(find.text('Pick a model').last);
    await app.tap(find.text('gemini-big').last);
    await app.settle();
    expect((app.hub.bodies['PUT /social/settings'] as Map)['aiModels'], {'gemini': 'gemini-big'});
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets(
    'connecting without app credentials walks through making the app, checks the keys and saves them',
    (tester) async {
      final app = AppHarness(tester)..desktop();
      await app.open();
      await app.run();
      await app.go('Accounts');
      expect(find.text('Set up · 6 steps'), findsWidgets);
      await app.tapText('Threads profile');
      expect(app.hub.log.where((l) => l.contains('/connect/')), isEmpty);
      expect(find.text('Set up Threads'), findsOneWidget);

      await app.tapText('Done, next');
      expect(find.text('$hubUrl/social/oauth/threads/callback'), findsOneWidget);
      await app.tapText('Done, next');
      await app.tapText('Done, next');
      expect(find.text('$hubUrl/social/webhook/threads'), findsOneWidget);
      await app.tapText('Done or skip, next');

      await app.enter('Threads app ID', '1234');
      await app.enter('Threads app secret', 'wrong');
      await app.tapText('Check and save');
      expect(find.textContaining('did not accept'), findsOneWidget);
      expect(app.hub.credentials['threads'], isNull);

      await app.enter('Threads app secret', 'right');
      await app.tapText('Check and save');
      expect(find.text('threads accepted the app ID and secret.'), findsOneWidget);
      expect(app.hub.credentials['threads']?['publicId'], '1234');
      expect(find.text('Sign in with Threads'), findsWidgets);
      expect(tester.takeException(), isNull);
      await app.close();
    },
  );

  testWidgets('Mastodon signs in on the server, or takes a token', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Accounts');
    await app.tapText('Sign in on your server');
    await app.tapText('Use an access token instead');
    expect(find.text('Add Mastodon with a token'), findsOneWidget);
    await app.enter('Server', 'https://mastodon.example/');
    await app.enter('Access token', 'token-1234567890');
    await app.tapText('Add');
    expect(app.hub.bodies['POST /social/accounts/mastodon'], {
      'instance': 'mastodon.example',
      'accessToken': 'token-1234567890',
    });
    expect(tester.takeException(), isNull);
    await app.close();
  });
}
