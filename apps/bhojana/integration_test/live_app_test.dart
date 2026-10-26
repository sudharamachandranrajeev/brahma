import 'package:bhojana/app/pricing.dart';
import 'package:bhojana/app/providers.dart';
import 'package:bhojana/domain/web_searcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/app_harness.dart';

/// The whole flow against the real shops, in the app's own web view, over a
/// throwaway in-memory database: items typed into a list are priced at
/// every compared shop, the cheapest shop is named, and a basket is filled.
/// Needs the network; run by hand:
///   flutter test integration_test/live_app_test.dart -d linux
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a typed list is priced at real shops and a basket filled', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(seed: (book) => book.setPref(shopsPref, 'tesco,sainsburys,asda,morrisons,aldi,ocado'));
    await app.run(searcher: const WebSearcher());
    await app.tapText('New list');
    await app.tapText('Create');
    for (final item in ['semi skimmed milk', 'medium sliced white bread', '2 heinz baked beans']) {
      await app.enter('Add an item', item);
      await app.tap(find.byTooltip('Add'));
    }
    final lists = await tester.runAsync(() => app.book.db.select(app.book.db.foodLists).get());
    final items = await tester.runAsync(() => app.book.items(lists!.first.id));
    // ignore: avoid_print
    print('Items: ${items!.map((i) => '${i.qty} x ${i.name}')}');
    expect(items, hasLength(3));

    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    final watch = Stopwatch()..start();
    while (container.read(pricerProvider).values.any((l) => l == Lookup.searching) &&
        watch.elapsed < const Duration(minutes: 5)) {
      await app.settle();
    }
    await app.settle();
    // ignore: avoid_print
    print('Priced in ${watch.elapsed.inSeconds}s: ${container.read(pricerProvider)}');
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      final s = t.data ?? t.textSpan?.toPlainText() ?? '';
      // ignore: avoid_print
      if (s.contains('£') || s.contains('p at ') || s.startsWith('Cheapest')) print('  $s');
    }
    expect(find.textContaining('Cheapest at', findRichText: true), findsOneWidget);

    await app.tapText('Fill a basket');
    await app.tap(find.textContaining('Ocado').last);
    await app.tapText('Add all');
    watch.reset();
    while (find.text('Stop').evaluate().isNotEmpty && watch.elapsed < const Duration(minutes: 4)) {
      await app.settle();
    }
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      final s = t.data ?? '';
      // ignore: avoid_print
      if (s.startsWith('Added') || s.contains(' · ')) print('Basket: $s');
    }
    expect(find.textContaining('Added'), findsOneWidget);
    await app.close();
  }, timeout: const Timeout(Duration(minutes: 12)));
}
