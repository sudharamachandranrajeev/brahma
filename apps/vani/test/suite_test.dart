import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vani/app/session.dart';
import 'package:vani/domain/prefs.dart';
import 'package:vani/suite.dart';

import 'support.dart';

void main() {
  testWidgets('the suite card asks for the hub with only the suite overrides', (tester) async {
    late AppSession session;
    await tester.runAsync(() async {
      final store = await Store.open(memoryDatabase());
      session = AppSession(KeyVault(MemorySecretStore(), vaniIdentity), store, VaniPrefs(store));
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coreSessionProvider.overrideWithValue(session),
          appIdentityProvider.overrideWithValue(vaniSuite.identity),
          ...vaniSuite.overrides(session),
        ],
        retry: (_, _) => null,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: vaniSuite.theme(ref, Brightness.light),
            home: Scaffold(body: Builder(builder: vaniSuite.summary)),
          ),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(find.text('Connect your social hub in Settings.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => session.db.close());
  });
}
