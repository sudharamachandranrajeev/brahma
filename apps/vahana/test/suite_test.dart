import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vahana/app/session.dart';
import 'package:vahana/domain/book.dart';
import 'package:vahana/suite.dart';

import 'support.dart';

void main() {
  testWidgets('the suite card shows the garage with only the suite overrides', (tester) async {
    late AppSession session;
    await tester.runAsync(() async {
      final store = await Store.open(memoryDatabase());
      session = AppSession(KeyVault(MemorySecretStore(), vahanaIdentity), store, CarBook(store));
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coreSessionProvider.overrideWithValue(session),
          appIdentityProvider.overrideWithValue(vahanaSuite.identity),
          ...vahanaSuite.overrides(session),
        ],
        retry: (_, _) => null,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: vahanaSuite.theme(ref, Brightness.light),
            home: Scaffold(body: Builder(builder: vahanaSuite.summary)),
          ),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(find.text('dates due in 30 days'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3));
    expect(find.textContaining('add an advert link'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => session.db.close());
  });
}
