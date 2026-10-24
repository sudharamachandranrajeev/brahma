import 'package:vahana/app/app.dart';
import 'package:vahana/app/providers.dart';
import 'package:vahana/app/session.dart';
import 'package:vahana/domain/book.dart';
import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// The whole app over a fresh in-memory database, for widget tests.
class AppHarness {
  AppHarness(this.tester);
  final WidgetTester tester;
  late AppSession session;

  CarBook get book => session.book;

  /// Opens the database; [seed] runs before the app starts.
  Future<void> open({Future<void> Function(CarBook book)? seed}) async {
    await tester.runAsync(() async {
      final store = await Store.open(memoryDatabase());
      session = AppSession(KeyVault(MemorySecretStore(), vahanaIdentity), store, CarBook(store));
      await seed?.call(session.book);
    });
  }

  Future<void> run() async {
    await tester.pumpWidget(
      ProviderScope(overrides: vahanaOverrides(session), retry: (_, _) => null, child: const VahanaApp()),
    );
    await settle();
  }

  Future<void> close() async {
    // Disposing the scope stops the sync timers.
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => session.db.close());
  }

  /// Lets database work (real I/O) and animations finish.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> tap(Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle();
  }

  Future<void> tapText(String text) => tap(find.text(text).last);

  /// Types into the text field labelled [label].
  Future<void> enter(String label, String text) async {
    final f = find.widgetWithText(TextField, label).last;
    await tester.ensureVisible(f);
    await tester.enterText(f, text);
    await tester.pump();
  }

  /// Goes to a top-level page through the navigation rail (desktop sizes).
  Future<void> go(String page) =>
      tap(find.descendant(of: find.byType(NavigationRail), matching: find.text(page)));

  void desktop() {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
}
