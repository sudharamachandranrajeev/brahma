import 'dart:io';

import 'package:bhojana/domain/reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs the reader script in a real headless Chromium over a page shaped
/// like a supermarket's results. Skipped where Chromium is not installed.
void main() {
  final chromium = [
    'chromium',
    'chromium-browser',
    'google-chrome-stable',
    'google-chrome',
  ].where((c) => Process.runSync('which', [c]).exitCode == 0).firstOrNull;

  test(
    'the reader finds products, prices, unit prices, offers and stock',
    () async {
      final dir = await Directory.systemTemp.createTemp('bhojana_reader');
      addTearDown(() => dir.delete(recursive: true));
      final page = File('${dir.path}/page.html');
      await page.writeAsString('''
<html><body>
<script type="application/ld+json">
{"@type":"ItemList","itemListElement":[{"@type":"Product","name":"Heinz Baked Beans 415g",
 "url":"https://shop.example/beans","offers":{"@type":"Offer","price":"1.40","availability":"https://schema.org/InStock"}}]}
</script>
<ul>
 <li><div class="tile"><a href="/p/1"><img alt=""></a><a href="/p/1">Tesco Semi Skimmed Milk 2.272L, 4 Pints</a>
   <p>£1.55</p><p>68p/litre</p><p>£1.45 Clubcard Price</p><button>Add</button></div></li>
 <li><div class="tile"><a href="/p/2">Hovis Soft White Medium Bread 800g</a>
   <p>£1.60</p><p>£0.20/100g</p><p>Out of stock</p></div></li>
 <li><div class="tile"><a href="/p/3">Bananas Loose</a><p>18p</p><p>£0.96/kg</p></div></li>
 <li><a href="/help">Help</a></li>
</ul>
<pre id="out"></pre>
<script>document.getElementById('out').textContent = $readerScript;</script>
</body></html>''');
      // A fresh profile and a virtual-time budget keep CI's Chrome from waiting
      // on first-run work; the timeout stops a browser that hangs anyway.
      final p = await Process.start(chromium!, [
        '--headless',
        '--disable-gpu',
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--no-first-run',
        '--user-data-dir=${dir.path}/profile',
        '--virtual-time-budget=5000',
        '--dump-dom',
        page.uri.toString(),
      ]);
      final stdout = p.stdout.transform(const SystemEncoding().decoder).join();
      final stderr = p.stderr.transform(const SystemEncoding().decoder).join();
      await p.exitCode.timeout(const Duration(seconds: 45), onTimeout: () => (p..kill()).pid);
      final json = RegExp(r'<pre id="out">(.*?)</pre>', dotAll: true).firstMatch(await stdout)?[1];
      expect(json, isNotNull, reason: await stderr);
      final offers = parseOffers('tesco', json!.replaceAll('&amp;', '&'));
      final byTitle = {for (final o in offers) o.title: o};
      expect(byTitle['Heinz Baked Beans 415g']?.pence, 140);
      final milk = byTitle['Tesco Semi Skimmed Milk 2.272L, 4 Pints']!;
      expect(milk.pence, 145);
      expect(milk.unitPrice, '68p/litre');
      expect(milk.offer, 'Clubcard Price');
      expect(milk.url, endsWith('/p/1'));
      expect(byTitle['Hovis Soft White Medium Bread 800g']?.inStock, isFalse);
      expect(byTitle['Bananas Loose']?.pence, 18);
      expect(byTitle.keys, isNot(contains('Help')));
    },
    timeout: const Timeout(Duration(seconds: 90)),
    skip: chromium == null ? 'Chromium is not installed' : null,
  );
}
