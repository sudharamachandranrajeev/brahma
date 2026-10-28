import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bhojana/app/app.dart';
import 'package:bhojana/app/providers.dart';
import 'package:bhojana/app/session.dart';
import 'package:bhojana/domain/book.dart';
import 'package:bhojana/domain/reader.dart';
import 'package:bhojana/domain/shops.dart';

import 'support.dart';

/// The whole app over a fresh in-memory database, for widget tests.
class AppHarness {
  AppHarness(this.tester);
  final WidgetTester tester;
  late AppSession session;

  ShoppingBook get book => session.book;

  /// Opens the database; [seed] runs before the app starts. With [onboarded]
  /// false the first-run sync setup is still to come.
  Future<void> open({Future<void> Function(ShoppingBook book)? seed, bool onboarded = true}) async {
    await tester.runAsync(() async {
      final store = await Store.open(memoryDatabase());
      session = AppSession(KeyVault(MemorySecretStore(), bhojanaIdentity), store, ShoppingBook(store));
      // A fresh install asks about sync first; tests of the app itself skip it.
      if (onboarded) await session.db.setLocalSetting('onboarding.sync', 'done');
      await seed?.call(session.book);
    });
  }

  /// Starts the app; shop pages are read by [searcher] (none by default).
  Future<void> run({PriceSearcher searcher = const FakeSearcher()}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...bhojanaOverrides(session), searcherProvider.overrideWithValue(searcher)],
        retry: (_, _) => null,
        child: const BhojanaApp(),
      ),
    );
    await settle();
  }

  Future<void> close() async {
    // Disposing the scope stops the sync and refresh timers.
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

  /// Goes to a top-level page through the rail (desktop) or the
  /// dock (phone).
  Future<void> go(String page) async {
    final rail = find.descendant(of: find.byType(NavigationRail), matching: find.text(page));
    if (rail.evaluate().isNotEmpty) return tap(rail);
    // Phones: the dock holds every screen and scrolls to the one asked for.
    await tap(
      find.descendant(
        of: find.byWidgetPredicate((w) => '${w.runtimeType}' == '_Dock'),
        matching: find.byTooltip(page),
      ),
    );
  }

  void desktop() => _size(const Size(1400, 900));

  void phone() => _size(const Size(390, 844));

  void _size(Size s) {
    tester.view.physicalSize = s;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
}

/// Shop pages from a table instead of the web; shops in [checks] show their
/// bot check.
class FakeSearcher implements PriceSearcher {
  const FakeSearcher([this.offers = const {}, this.checks = const {}]);
  final Map<String, List<Offer>> offers;
  final Set<String> checks;

  @override
  bool get available => true;

  @override
  Future<List<Offer>> search(Shop shop, String query) async =>
      checks.contains(shop.id) ? throw ShopCheck(shop.name) : offers[shop.id] ?? const [];
}
