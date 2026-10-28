import 'dart:async';

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

  /// Why the page in view did not load, shown over it with ways on.
  String? _failed;
  var _step = 0;
  Completer<void>? _loaded;

  /// What happened to each basket item, by step: added, more, not-found,
  /// no-button.
  final _done = <int, String>{};
  var _filling = false;
  var _stop = false;

  Shop get shop => widget.shop;
  bool get _basket => widget.basket.isNotEmpty;
  Item get _item => widget.basket[_step];

  String get _start => widget.url ?? shop.home;

  Future<void> _load(String url) async {
    _loaded = Completer<void>();
    await _web?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    await _loaded!.future.timeout(const Duration(seconds: 30), onTimeout: () {});
  }

  Future<String> _add(String url, String title) async =>
      '${await _web?.evaluateJavascript(
        source: addScript(url: url, title: title),
      )}';

  /// Opens one item's search, for the user to add by hand.
  Future<void> _goTo(int step) async {
    setState(() => _step = step);
    if (shop.searchable) await _load(shop.searchUrl(_item.name));
  }

  /// Adds every item to the shop's basket the way the user would: searches
  /// it, finds the product (the price kept for it, else the best match) and
  /// presses its Add button, then its plus button for each extra one.
  Future<void> _fill() async {
    setState(() {
      _filling = true;
      _stop = false;
      _done.clear();
    });
    final kept = latestPrices(ref.read(pricesProvider).value ?? const []);
    final deals = ref.read(dealsProvider).value ?? const <String, bool>{};
    for (var i = 0; i < widget.basket.length && !_stop && mounted; i++) {
      setState(() => _step = i);
      final item = _item;
      await _load(shop.searchUrl(item.name));
      // Results are drawn by script after the page loads.
      var offers = const <Offer>[];
      for (var t = 0; t < 10 && rank(item.name, offers).isEmpty && !_stop; t++) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        offers = parseOffers(shop.id, await _web?.evaluateJavascript(source: readerScript));
      }
      final price = kept[(item.id, shop.id)];
      final pick = price == null ? autoPick(item.name, offers) : null;
      if (price == null && pick == null) {
        _done[i] = 'not-found';
        continue;
      }
      var r = await _add(price?.url ?? pick!.url, price?.title ?? pick!.title);
      // The kept product may be gone from today's results: take the best match.
      if (r == 'not-found' && price != null) {
        if (autoPick(item.name, offers) case final other?) r = await _add(other.url, other.title);
      }
      // A multi-buy the user took means whole deals: 2 of "any 2 for £3".
      final want = price?.units(item.qty, deals) ?? item.qty;
      if (r == 'added' && want > 1) {
        var n = 1;
        for (; n < want; n++) {
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          if ('${await _web?.evaluateJavascript(source: moreScript)}' != 'more') break;
        }
        if (n < want) r = 'added $n';
      }
      if (mounted) setState(() => _done[i] = r);
    }
    if (mounted) setState(() => _filling = false);
  }

  /// Reads the products on the page in view and keeps the one the user picks.
  Future<void> _readPrices() async {
    final json = await _web?.evaluateJavascript(source: readerScript);
    final query = _basket ? _item.name : '';
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
        itemId: _basket ? _item.id : null,
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
              icon: const Icon(Icons.pin_drop_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: postcode));
                showMessage(context, 'Copied $postcode. Paste it where the shop asks for your postcode.');
              },
            ),
          if (shop.slots != null)
            IconButton(
              tooltip: 'Delivery slots',
              icon: const Icon(Icons.local_shipping_rounded),
              onPressed: () => _web?.loadUrl(urlRequest: URLRequest(url: WebUri(shop.slots!))),
            ),
          IconButton(
            tooltip: 'Keep a price from this page',
            icon: const Icon(Icons.sell_rounded),
            onPressed: _readPrices,
          ),
          IconButton(
            tooltip: 'Open in your browser',
            icon: const Icon(Icons.open_in_browser_rounded),
            onPressed: _openOutside,
          ),
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _web?.reload(),
          ),
        ],
        bottom: _progress < 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress),
              )
            : null,
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_start)),
            initialSettings: webSettings(supportMultipleWindows: false),
            onWebViewCreated: (c) => _web = c,
            onLoadStart: (_, _) {
              if (_failed != null) setState(() => _failed = null);
            },
            onLoadStop: (_, _) {
              if (_loaded?.isCompleted == false) _loaded!.complete();
            },
            // A shop's bot check comes with a 403, which the Windows web view
            // reports here rather than in onLoadStop; the page still shows.
            onReceivedHttpError: (_, req, _) {
              if (req.isForMainFrame != false && _loaded?.isCompleted == false) _loaded!.complete();
            },
            onReceivedError: (_, req, err) {
              if (req.isForMainFrame == false || err.type == WebResourceErrorType.CANCELLED) return;
              if (_loaded?.isCompleted == false) _loaded!.complete();
              setState(() => _failed = err.description);
            },
            onProgressChanged: (_, p) => setState(() => _progress = p / 100),
          ),
          if (_failed case final why?)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: '${shop.name} did not load',
                  message: '$why. Try again, or open it in your browser.',
                  actions: [
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                      onPressed: () => _web?.reload(),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_browser_rounded),
                      label: const Text('Open in your browser'),
                      onPressed: _openOutside,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _basket ? _basketBar(context) : null,
    );
  }

  /// The page in view in the system browser, for a shop whose bot check
  /// will not pass in the app.
  Future<void> _openOutside() async {
    final url = await _web?.getUrl();
    if (mounted) await openLink(context, '${url ?? _start}');
  }

  Widget _basketBar(BuildContext context) {
    final n = widget.basket.length;
    final text = Theme.of(context).textTheme;
    final added = _done.values.where((r) => r.startsWith('added')).length;
    final missed = [
      for (final e in _done.entries)
        if (e.value != 'added') e.key,
    ];
    final Widget status;
    if (_filling) {
      status = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Adding ${_step + 1} of $n', style: text.labelSmall),
          Text(
            '${_item.qty > 1 ? '${_item.qty} × ' : ''}${_item.name}',
            style: text.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else if (_done.isEmpty) {
      status = Text(
        'Sign in to ${shop.name} on this page first if you have not, then add your $n '
        '${n == 1 ? 'item' : 'items'}.',
        style: text.bodyMedium,
      );
    } else {
      status = Text(
        missed.isEmpty
            ? 'Added all $added. Check the basket on the page, then check out.'
            : 'Added $added of $n. ${missed.length} need you: tap one to find it.',
        style: text.bodyMedium,
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_filling) LinearProgressIndicator(value: (_step + 1) / n),
            if (missed.isNotEmpty && !_filling)
              Wrap(
                spacing: 8,
                children: [
                  for (final i in missed)
                    ActionChip(
                      label: Text('${widget.basket[i].name} · ${_why(_done[i]!)}'),
                      onPressed: () => _goTo(i),
                    ),
                ],
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: status),
                const SizedBox(width: 8),
                if (_filling)
                  OutlinedButton(onPressed: () => setState(() => _stop = true), child: const Text('Stop'))
                else
                  FilledButton.icon(
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    label: Text(_done.isEmpty ? 'Add all' : 'Again'),
                    onPressed: shop.searchable ? _fill : null,
                  ),
                if (!_filling && _done.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Why an item is not in the basket, shortly.
  String _why(String result) => switch (result) {
    'not-found' => 'not found',
    'no-button' => 'no Add button',
    final r when r.startsWith('added ') => 'only ${r.substring(6)} added',
    _ => result,
  };
}
