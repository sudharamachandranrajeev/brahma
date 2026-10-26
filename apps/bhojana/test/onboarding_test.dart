import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

void main() {
  testWidgets('a fresh install offers sync setup once; skipping goes to the app', (tester) async {
    final app = AppHarness(tester)..phone();
    await app.open(onboarded: false);
    await app.run();
    expect(find.text('Welcome to Bhojana'), findsOneWidget);
    expect(find.text('Shopping lists'), findsNothing);

    await app.tapText('Keep everything on this device');
    expect(find.text('Welcome to Bhojana'), findsNothing);
    expect(tester.takeException(), isNull);
    // The answer is remembered, so the next start goes straight to the app.
    final saved = await tester.runAsync(() => app.session.db.localSetting('onboarding.sync'));
    expect(saved, isNotNull);
    await app.close();
  });

  testWidgets('setup walks the choice, the cloud guide, the server step and back', (tester) async {
    final app = AppHarness(tester)..phone();
    await app.open(onboarded: false);
    await app.run();
    await app.tapText('Sync across my devices');
    expect(find.text('Where will your server run?'), findsOneWidget);

    await app.tapText('Cloud server');
    expect(find.textContaining('npm run setup'), findsWidgets);
    await tester.ensureVisible(find.text("I've done this, connect"));
    await app.tapText("I've done this, connect");
    expect(find.widgetWithText(TextFormField, 'Setup link or server address'), findsOneWidget);

    // Too short an address is refused before any request is made.
    await app.tapText('Check server');
    expect(find.text('Paste the link or type the address'), findsOneWidget);

    await app.tapText('Back');
    await tester.ensureVisible(find.text('Back'));
    await app.tapText('Back');
    await app.tapText('Back');
    expect(find.text('Welcome to Bhojana'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });
}
