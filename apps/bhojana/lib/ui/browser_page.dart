import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/book.dart';
import '../domain/reader.dart';
import '../domain/shops.dart';
import '../domain/web_searcher.dart';
import 'common.dart';

/// Opens [url] at [shop] in the in-app browser, or in the system browser
/// where there is no web view. With [basket], it walks the items one by one
/// so the user can add each to the shop's basket.
Future<void> openShop(BuildContext context, Shop shop, {String? url, List<Item> basket = const []}) async {
  if (!hasWebView) return openLink(context, url ?? shop.home);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BrowserPage(shop: shop, url: url, basket: basket),
    ),
  );
}

/// A shop's own website, signed in with the user's own account. The user
/// types their password and postcode into the shop's page; Bhojana only
/// keeps the cookies (in the web view's own store, as any browser does).
class BrowserPage extends ConsumerStatefulWidget {
  const BrowserPage({super.key, required this.shop, this.url, this.basket = const []});
  final Shop shop;
  final String? url;
  final List<Item> basket;

  @override
  ConsumerState<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends ConsumerState<BrowserPage> {
  InAppWebViewController? _web;
  var _progress = 0.0;
  var _step = 0;

  Shop get shop => widget.shop;
  bool get _filling => widget.basket.isNotEmpty;
  Item get _item => widget.basket[_step];

  String get _start {
    if (_filling && shop.searchable) return shop.searchUrl(_item.name);
    return widget.url ?? shop.home;
  }

  Future<void> _goTo(int step) async {
    setState(() => _step = step);
    if (shop.searchable) await _web?.loadUrl(urlRequest: URLRequest(url: WebUri(shop.searchUrl(_item.name))));
  }

  Future<void> _addFirst() async {
    final r = await _web?.evaluateJavascript(source: addFirstScript);
    if (!mounted) return;
    if (r == 'added') {
      showMessage(context, 'Pressed the first Add button. Check the quantity on the page.');
    } else {
      showMessage(context, 'No Add button found here. Pick a product on the page and add it yourself.');
    }
  }

  /// Reads the products on the page in view and keeps the one the user picks.
  Future<void> _readPrices() async {
    final json = await _web?.evaluateJavascript(source: readerScript);
    final query = _filling ? _item.name : '';
    var offers = parseOffers(shop.id, json);
    // Best matches for the item first, then everything else on the page.
    if (query.isNotEmpty) {
      offers = [...rank(query, offers), ...offers.where((o) => relevance(query, o.title) < .5)];
    }
    if (!mounted) return;
    if (offers.isEmpty) return showMessage(context, 'No prices found on this page.');
    final picked = await showModalBottomSheet<Offer>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Keep which price?')),
            for (final o in offers.take(20))
              ListTile(
                title: Text(o.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    o.unitPrice,
                    o.offer,
                    if (!o.inStock) 'Out of stock',
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
                trailing: Text(pounds(o.pence)),
                onTap: () => Navigator.pop(context, o),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await ref.mutate(
      (s) => s.book.keepOffer(
        picked,
        itemId: _filling ? _item.id : null,
        query: query.isEmpty ? picked.title : query,
        source: 'signed-in',
      ),
    );
    if (mounted) showMessage(context, 'Kept ${pounds(picked.pence)} at ${shop.name}.');
  }

  @override
  Widget build(BuildContext context) {
    final postcode = ref.watch(postcodeProvider).value ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(shop.name),
        actions: [
          if (postcode.isNotEmpty)
            IconButton(
              tooltip: 'Copy postcode $postcode',
              icon: const Icon(Icons.pin_drop_outlined),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: postcode));
                showMessage(context, 'Copied $postcode. Paste it where the shop asks for your postcode.');
              },
            ),
          if (shop.slots != null)
            IconButton(
              tooltip: 'Delivery slots',
              icon: const Icon(Icons.local_shipping_outlined),
              onPressed: () => _web?.loadUrl(urlRequest: URLRequest(url: WebUri(shop.slots!))),
            ),
          IconButton(
            tooltip: 'Keep a price from this page',
            icon: const Icon(Icons.sell_outlined),
            onPressed: _readPrices,
          ),
          IconButton(tooltip: 'Reload', icon: const Icon(Icons.refresh), onPressed: () => _web?.reload()),
        ],
        bottom: _progress < 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress),
              )
            : null,
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_start)),
        initialSettings: InAppWebViewSettings(javaScriptEnabled: true, supportMultipleWindows: false),
        onWebViewCreated: (c) => _web = c,
        onProgressChanged: (_, p) => setState(() => _progress = p / 100),
      ),
      bottomNavigationBar: _filling ? _basketBar(context) : null,
    );
  }

  Widget _basketBar(BuildContext context) {
    final n = widget.basket.length;
    final last = _step == n - 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous item',
              icon: const Icon(Icons.chevron_left),
              onPressed: _step == 0 ? null : () => _goTo(_step - 1),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_step + 1} of $n', style: Theme.of(context).textTheme.labelSmall),
                  Text(
                    '${_item.qty > 1 ? '${_item.qty} × ' : ''}${_item.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (shop.selling != Selling.browse)
              OutlinedButton(onPressed: _addFirst, child: const Text('Add first')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: last ? () => Navigator.pop(context) : () => _goTo(_step + 1),
              child: Text(last ? 'Done' : 'Next'),
            ),
          ],
        ),
      ),
    );
  }
}
