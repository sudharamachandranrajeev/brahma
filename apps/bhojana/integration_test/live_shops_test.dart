import 'package:bhojana/domain/reader.dart';
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
}
