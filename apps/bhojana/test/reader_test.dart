import 'dart:convert';
import 'dart:io';

import 'package:bhojana/domain/reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chromium.dart';

/// Runs the reader script in a real headless Chromium over a page shaped
/// like a supermarket's results. Skipped where Chromium is not installed.
void main() {
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
      final json = await dumpOut(chromium!, dir, page);
      final offers = parseOffers('tesco', json);
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

  test(
    'multi-buys, meal deals and old prices are kept apart from the single price',
    () async {
      final dir = await Directory.systemTemp.createTemp('bhojana_deals');
      addTearDown(() => dir.delete(recursive: true));
      final page = File('${dir.path}/page.html');
      // Tiles as Tesco, Asda and Iceland drew them in October 2026.
      await page.writeAsString('''
<html><body>
<header><a href="/about">About Asda</a> <a href="/less">£1 &amp; less</a></header>
<ul>
 <li><div><a href="/p/beans">Heinz Beans in Tomato Sauce 415g</a><p>More like this</p>
   <a href="/shop/en-GB/promotions/1">Any 2 for £2 Clubcard Price - Selected Heinz Beanz 390g - 415g</a>
   <p>Offer valid for delivery from 28/08/2026 until 19/01/2027</p><p>£1.40</p><p>£3.37/kg</p><button>Add</button></div></li>
 <li><div><a href="/p/coke">Coca-Cola Original Taste 500ml</a>
   <p>£5.50 Meal Deal Drink Clubcard Price £6 Meal Deal Drink Regular Price - Selected Drink + Snack</p>
   <p>£1.89</p><p>£3.78/litre</p><button>Add</button></div></li>
 <li><div><a href="/p/asda-beans">Heinz Tinned Baked Beans in a Rich Tomato Sauce 6 x 415g</a><p>(244)</p>
   <p>Any 2 for £8</p><p>£5.24</p><p>(£2.10/kg)</p></div></li>
 <li><div><a href="/p/ice-beans">Heinz Baked Beans 415g</a><p>10</p><p>for</p><p>£10.00</p><p>Mix &amp; Match</p>
   <p>£2.41/1kg</p><p>Mix &amp; Match from</p><p>£1.00</p><p>each</p><p>£1.40</p><p>£3.37/1kg</p><button>Add to Basket</button></div></li>
 <li><div><a href="/p/ice-pots">Heinz Baked Tinned Beans in Tomato Sauce 3 x 200g</a><p>Buy 2 Get 1 FREE</p>
   <p>Cheapest Free</p><p>£2.50</p><button>Add to Basket</button></div></li>
 <li><div><a href="/p/ice-six">Heinz Tinned Baked Beans 6 x 415g</a><p>£4.50</p><p>Was</p><p>£5.25</p><button>Add to Basket</button></div></li>
</ul>
<pre id="out"></pre>
<script>document.getElementById('out').textContent = $readerScript;</script>
</body></html>''');
      final offers = parseOffers('tesco', await dumpOut(chromium!, dir, page));
      final by = {for (final o in offers) o.title: o};
      expect(by.keys, isNot(contains('About Asda')));
      expect(by.keys.where((t) => t.contains('Selected')), isEmpty);
      final tesco = by['Heinz Beans in Tomato Sauce 415g']!;
      expect((tesco.pence, tesco.deal, tesco.offer), (140, 'Any 2 for £2 Clubcard Price', ''));
      final coke = by['Coca-Cola Original Taste 500ml']!;
      expect((coke.pence, coke.deal, coke.offer), (189, '', ''));
      final asda = by['Heinz Tinned Baked Beans in a Rich Tomato Sauce 6 x 415g']!;
      expect((asda.pence, asda.deal), (524, 'Any 2 for £8'));
      final ice = by['Heinz Baked Beans 415g']!;
      expect((ice.pence, ice.deal), (140, '10 for £10.00'));
      final pots = by['Heinz Baked Tinned Beans in Tomato Sauce 3 x 200g']!;
      expect((pots.pence, pots.deal), (250, 'Buy 2 Get 1 FREE'));
      final six = by['Heinz Tinned Baked Beans 6 x 415g']!;
      expect((six.pence, six.deal), (450, ''));
    },
    timeout: const Timeout(Duration(seconds: 90)),
    skip: chromium == null ? 'Chromium is not installed' : null,
  );

  test(
    'the basket filler presses Add on the right product and raises its quantity',
    () async {
      final dir = await Directory.systemTemp.createTemp('bhojana_basket');
      addTearDown(() => dir.delete(recursive: true));
      final page = File('${dir.path}/page.html');
      // Each tile's Add turns into a - 1 + stepper, as the grocers' do.
      await page.writeAsString('''
<html><body>
<a href="/p/9">Add to favourites</a>
<ul>
 <li class="tile"><a href="/p/1">Whole Milk 4 Pints</a><p>£1.55</p><button>Add</button><button>Add to list</button></li>
 <li class="tile"><a href="/p/2?from=search">Semi Skimmed Milk 4 Pints</a><p>£1.45</p><button aria-label="Add Semi Skimmed Milk to trolley">Add</button></li>
 <li class="tile"><a href="/p/3">Bananas Loose</a><p>18p</p></li>
</ul>
<pre id="out"></pre>
<script>
const log = [];
for (const tile of document.querySelectorAll('.tile')) {
  const add = tile.querySelector('button');
  if (!add) continue;
  add.onclick = () => {
    const name = tile.querySelector('a').textContent;
    log.push('add ' + name);
    const plus = document.createElement('button');
    plus.setAttribute('aria-label', 'Increase quantity');
    plus.textContent = '+';
    plus.onclick = () => log.push('more ' + name);
    add.replaceWith(plus);
  };
}
const r = [
  ${addScript(url: 'https://shop.example/p/2', title: 'Semi Skimmed Milk 4 Pints')},
  $moreScript,
  $moreScript,
  ${addScript(url: '', title: 'whole milk 4 pints')},
  ${addScript(url: '', title: 'Bananas Loose')},
  ${addScript(url: '', title: 'Oat Milk')},
];
document.getElementById('out').textContent = JSON.stringify({r, log});
</script>
</body></html>''');
      final out = jsonDecode(await dumpOut(chromium!, dir, page)) as Map;
      expect(out['r'], ['added', 'more', 'more', 'added', 'no-button', 'not-found']);
      expect(out['log'], [
        'add Semi Skimmed Milk 4 Pints',
        'more Semi Skimmed Milk 4 Pints',
        'more Semi Skimmed Milk 4 Pints',
        'add Whole Milk 4 Pints',
      ]);
    },
    timeout: const Timeout(Duration(seconds: 90)),
    skip: chromium == null ? 'Chromium is not installed' : null,
  );

  test(
    "Cloudflare's challenge page counts as a bot check",
    () async {
      final dir = await Directory.systemTemp.createTemp('bhojana_check');
      addTearDown(() => dir.delete(recursive: true));
      final page = File('${dir.path}/page.html');
      // As Asda served it in October 2026, with a 403.
      await page.writeAsString('''
<html><head><title>Just a moment...</title></head><body>
<h1>www.asda.com</h1><p>Verifying you are human. This may take a few seconds.</p>
<p>www.asda.com needs to review the security of your connection before proceeding.</p>
<pre id="out"></pre>
<script>document.getElementById('out').textContent = String($checkScript);</script>
</body></html>''');
      expect(await dumpOut(chromium!, dir, page), 'true');
    },
    timeout: const Timeout(Duration(seconds: 90)),
    skip: chromium == null ? 'Chromium is not installed' : null,
  );
}
