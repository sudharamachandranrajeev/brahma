import 'dart:io';

import 'package:brahma/app/app.dart';
import 'package:brahma/app/apps.dart';
import 'package:brahma/app/providers.dart';
import 'package:brahma/app/session.dart';
import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late MemorySecretStore secrets;
  late SuiteSession suite;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('brahma');
    secrets = MemorySecretStore();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => dir.path,
    );
  });

  tearDown(() => dir.delete(recursive: true));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 16; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> start(WidgetTester tester) async {
    await tester.runAsync(() async {
      suite = await SuiteSession.open(KeyVault(secrets, brahmaIdentity), suiteApps);
    });
    await tester.pumpWidget(
      ProviderScope(overrides: suiteOverrides(suite), retry: (_, _) => null, child: const BrahmaApp()),
    );
    await settle(tester);
  }

  Future<void> stop(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(suite.close);
  }

  testWidgets('every app opens its own encrypted database under one key', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await start(tester);

    final files = dir.listSync().map((f) => f.uri.pathSegments.last).toSet();
    expect(files, containsAll(['brahma.sqlite', for (final a in suiteApps) '${a.identity.id}.sqlite']));
    // One database key for the suite; the standalone apps' entries are untouched.
    expect(secrets.values.keys, ['brahma.db.key']);
    // Every database is encrypted: none starts with the plain SQLite header.
    for (final f in files.where((f) => f.endsWith('.sqlite'))) {
      final head = File('${dir.path}/$f').openSync().readSync(16);
      expect(String.fromCharCodes(head), isNot(startsWith('SQLite format 3')), reason: f);
    }
    // Sync covers every app's database.
    final container = ProviderScope.containerOf(tester.element(find.byType(BrahmaApp)));
    expect(container.read(syncStoresProvider), hasLength(suiteApps.length));
    await stop(tester);
  });

  testWidgets('the home shows each app and opens it, with a way back', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await start(tester);

    for (final app in suiteApps) {
      expect(find.text(app.identity.name), findsOneWidget);
      expect(find.text(app.tagline), findsOneWidget);
    }
    // Each card shows its app's figures.
    for (final label in ['open applications', 'viewings booked', 'day streak']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    await tester.tap(find.text('Udyoga'));
    await settle(tester);
    expect(find.text('Jobs'), findsWidgets);
    // Inside the app, the app's identity and hints are in force.
    final inside = ProviderScope.containerOf(tester.element(find.text('Jobs').first));
    expect(inside.read(appIdentityProvider).id, 'udyoga');

    await tester.tap(find.byTooltip('All apps'));
    await settle(tester);
    expect(find.textContaining(RegExp('^Good (morning|afternoon|evening)')), findsOneWidget);
    expect(find.text('Vidya'), findsOneWidget);
    await stop(tester);
  });
}
