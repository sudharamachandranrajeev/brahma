import 'dart:convert';
import 'dart:io';

import 'package:bhojana/domain/reader.dart';
import 'package:brahma_core/brahma_core.dart' show today;
import 'package:bhojana/domain/shops.dart';
import 'package:bhojana/domain/web_searcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Reads real shop search pages in the app's own hidden web view. Needs the
/// network; run by hand: flutter test integration_test/live_shops_test.dart -d linux
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the hidden web view reads live shop prices', (tester) async {
    const searcher = WebSearcher();
    expect(searcher.available, isTrue);
    final found = <String, int>{};
    for (final id in ['aldi', 'lidl', 'ocado', 'coop', 'tesco', 'sainsburys', 'asda', 'morrisons']) {
      final shop = shopById(id)!;
      final offers = await tester.runAsync(() async {
        try {
          return await searcher.search(shop, 'semi skimmed milk');
        } catch (e) {
          // ignore: avoid_print
          print('${shop.name}: failed $e');
          return const <Offer>[];
        }
      });
      final best = autoPick('semi skimmed milk', offers!);
      // ignore: avoid_print
      print('${shop.name}: ${offers.length} products; picked ${best?.title} ${best?.pence}p ${best?.url}');
      found[id] = offers.length;
    }
    expect(found.values.where((n) => n > 0), isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 6)));

  // A live run saves each settled page for test/live_pages_test.dart to
  // replay offline, so day-to-day checks need not load the shops at all.
  // Limit the shops with --dart-define=SHOPS=asda,iceland.
  testWidgets('multi-buys at Tesco, Asda and Iceland come with the single price', (tester) async {
    const searcher = WebSearcher();
    const only = String.fromEnvironment('SHOPS');
    final save = Directory('test').existsSync() ? (Directory('test/live_pages')..createSync()) : null;
    final deals = <String, int>{};
    final checks = <String>{};
    for (final id in only.isEmpty ? ['tesco', 'asda', 'iceland'] : only.split(',')) {
      for (final q in ['heinz baked beans', 'coca cola', 'pizza']) {
        final name = '${id}__${q.replaceAll(' ', '_')}';
        String? page;
        final offers = await tester.runAsync(() async {
          try {
            return await searcher.search(
              shopById(id)!,
              q,
              keep: save == null
                  ? null
                  : (web) async => page = '${await web.evaluateJavascript(source: _snapshot)}',
            );
          } on ShopCheck catch (e) {
            checks.add(id);
            // ignore: avoid_print
            print('$id / $q: $e');
            return null;
          }
        });
        if (offers == null) break;
        final withDeal = [
          for (final o in offers)
            if (o.multiBuy != null) o,
        ];
        deals[id] = (deals[id] ?? 0) + withDeal.length;
        // ignore: avoid_print
        print('$id / $q: ${offers.length} products, ${withDeal.length} multi-buys');
        for (final o in withDeal.take(3)) {
          final d = o.multiBuy!;
          // ignore: avoid_print
          print('  ${o.title}: ${o.pence}p alone; ${d.text} = ${d.each}p each');
          expect(d.pence, lessThan(d.count * o.pence));
        }
        if (save != null && page != null && offers.isNotEmpty) {
          File('${save.path}/$name.html').writeAsStringSync(page!);
          File('${save.path}/$name.json').writeAsStringSync(
            jsonEncode({
              'shop': id,
              'query': q,
              'day': today(),
              'products': offers.length,
              'deals': withDeal.length,
            }),
          );
        }
      }
    }
    if (checks.isNotEmpty) {
      // ignore: avoid_print
      print('Bot check at ${checks.join(', ')}: answer it in the app\'s browser, or try again later.');
    }
    expect(deals.keys, isNotEmpty, reason: 'every shop showed its bot check');
    expect(deals.entries.where((e) => e.value == 0).map((e) => e.key), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));
}

/// The settled page without its scripts and with its readable stylesheets
/// inlined, so it lays out (and innerText reads) the same offline.
const _snapshot = r"""
(() => {
  const css = [...document.styleSheets].map((s) => {
    try { return [...s.cssRules].map((r) => r.cssText).join('\n'); } catch (e) { return ''; }
  }).join('\n');
  const doc = document.documentElement.cloneNode(true);
  doc.querySelectorAll('script, noscript, iframe, link[rel="stylesheet"], style').forEach((e) => e.remove());
  const style = document.createElement('style');
  style.textContent = css;
  (doc.querySelector('head') || doc).prepend(style);
  return '<!doctype html>' + doc.outerHTML;
})()
""";
