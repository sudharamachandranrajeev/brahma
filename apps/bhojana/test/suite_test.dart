import 'package:bhojana/app/session.dart';
import 'package:bhojana/domain/book.dart';
import 'package:bhojana/suite.dart';
import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets('the suite card shows the list with only the suite overrides', (tester) async {
    late AppSession session;
    await tester.runAsync(() async {
      final store = await Store.open(memoryDatabase());
      session = AppSession(KeyVault(MemorySecretStore(), bhojanaIdentity), store, ShoppingBook(store));
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coreSessionProvider.overrideWithValue(session),
          appIdentityProvider.overrideWithValue(bhojanaSuite.identity),
          ...bhojanaSuite.overrides(session),
        ],
        retry: (_, _) => null,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: bhojanaSuite.theme(ref, Brightness.light),
            home: Scaffold(body: Builder(builder: bhojanaSuite.summary)),
          ),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(find.text('to buy'), findsOneWidget);
    expect(find.textContaining('Start a shopping list'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => session.db.close());
  });
}
