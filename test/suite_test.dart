import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udyoga/app/session.dart';
import 'package:udyoga/domain/book.dart';
import 'package:udyoga/suite.dart';

import 'support.dart';

void main() {
  testWidgets('the suite card shows the pipeline with only the suite overrides', (tester) async {
    late AppSession session;
    await tester.runAsync(() async {
      final store = await Store.open(memoryDatabase());
      session = AppSession(KeyVault(MemorySecretStore(), udyogaIdentity), store, CareerBook(store));
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coreSessionProvider.overrideWithValue(session),
          appIdentityProvider.overrideWithValue(udyogaSuite.identity),
          ...udyogaSuite.overrides(session),
        ],
        retry: (_, _) => null,
        child: MaterialApp(
          theme: udyogaSuite.theme(Brightness.light),
          home: Scaffold(body: Builder(builder: udyogaSuite.summary)),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(find.text('open applications'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3));
    expect(find.textContaining('Import your CV'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => session.db.close());
  });
}
