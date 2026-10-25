import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/book.dart';
import '../domain/reader.dart';
import '../domain/shops.dart';
import 'browser_page.dart';
import 'common.dart';
import 'look.dart';

/// Searches one product across the user's shops. Opened from a list item
/// with [item], kept prices are tied to it and cost the list.
class ComparePage extends ConsumerStatefulWidget {
  const ComparePage({super.key, this.item});
  final Item? item;

  @override
  ConsumerState<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends ConsumerState<ComparePage> {
  late final _query = TextEditingController(text: widget.item?.name ?? '');
  final _results = <String, AsyncValue<List<Offer>>>{};
  var _searched = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(List<Shop> shops) async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    final searcher = ref.read(searcherProvider);
    final targets = [
      for (final s in shops)
        if (s.searchable) s,
    ];
    setState(() {
      _searched = q;
      _results
        ..clear()
        ..addAll({for (final s in targets) s.id: const AsyncValue<List<Offer>>.loading()});
    });
    // Three at a time: each shop is a whole web page.
    for (var i = 0; i < targets.length; i += 3) {
      await Future.wait([
        for (final s in targets.skip(i).take(3))
          AsyncValue.guard(() => searcher.search(s, q)).then((r) {
            if (mounted && _searched == q) setState(() => _results[s.id] = r.whenData((o) => rank(q, o)));
          }),
      ]);
    }
  }

  Future<void> _keep(Offer o, {String source = 'web'}) async {
    await ref.mutate((s) => s.book.keepOffer(o, itemId: widget.item?.id, query: _searched, source: source));
    if (mounted) showMessage(context, 'Kept ${pounds(o.pence)} at ${shopName(o.shop)}.');
  }

  /// Keeps a price the user read off a shelf, a leaflet or a site.
  Future<void> _typePrice() async {
    var shop = (ref.read(myShopsProvider).value?.firstOrNull ?? shops.first).id;
    final title = TextEditingController(text: _query.text.trim());
    final price = TextEditingController();
    await showFormDialog(
      context,
      title: 'Type a price',
      fields: (setState) => [
        DropdownButtonFormField<String>(
          initialValue: shop,
          decoration: const InputDecoration(labelText: 'Shop'),
          items: [for (final s in shops) DropdownMenuItem(value: s.id, child: Text(s.name))],
          onChanged: (v) => shop = v ?? shop,
        ),
        const SizedBox(height: 12),
        Field(title, 'Product'),
        Field(price, 'Price in £', number: true, hint: '1.25'),
      ],
      onSave: () async {
        final p = numberIn(price);
        if (title.text.trim().isEmpty) return 'Name the product.';
        if (p == null || p <= 0) return 'Type the price, like 1.25.';
        if (_searched.isEmpty) _searched = title.text.trim();
        await _keep(
          Offer(shop: shop, title: title.text.trim(), pence: (p * 100).round()),
          source: 'typed',
        );
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myShopsProvider).value ?? const <Shop>[];
    final available = ref.watch(searcherProvider).available;
    final kept = _keptPrices(ref.watch(pricesProvider).value ?? const []);
    final pushed = widget.item != null;
    final body = [
      TextField(
        controller: _query,
        textInputAction: TextInputAction.search,
        onSubmitted: available ? (_) => _search(mine) : null,
        decoration: const InputDecoration(labelText: 'Product', hintText: 'semi-skimmed milk 4 pints'),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (available)
            FilledButton.icon(
              icon: const Icon(Icons.search),
              label: Text('Search ${mine.where((s) => s.searchable).length} shops'),
              onPressed: () => _search(mine),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Type a price'),
            onPressed: _typePrice,
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (!available) _NoWebView(shops: mine, query: _query.text),
      for (final s in mine)
        if (_results[s.id] case final r?) _ShopResults(shop: s, query: _searched, result: r, onKeep: _keep),
      if (kept.isNotEmpty)
        SectionCard(
          title: 'Prices kept',
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              for (final p in kept)
                ListTile(
                  title: Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [
                      shopName(p.shop),
                      niceDate(p.day),
                      p.offer,
                      if (p.source == 'signed-in') 'your prices',
                    ].where((s) => s.isNotEmpty).join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(pounds(p.pence), style: Theme.of(context).textTheme.titleMedium),
                      IconButton(
                        tooltip: 'Forget this price',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => ref.mutate((s) => s.book.removePrice(p.id)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
    ];
    return PageScaffold(
      title: pushed ? 'Compare ${widget.item!.name}' : 'Compare',
      banner: 'page.compare',
      children: body,
    );
  }

  /// Prices kept for this item, or for the product searched.
  List<Price> _keptPrices(List<Price> all) {
    final item = widget.item;
    if (item != null) {
      return [
        for (final p in all)
          if (p.itemId == item.id) p,
      ];
    }
    final q = _searched.toLowerCase();
    return q.isEmpty
        ? const []
        : [
            for (final p in all)
              if (p.query.toLowerCase() == q) p,
          ];
  }
}

class _ShopResults extends StatelessWidget {
  const _ShopResults({required this.shop, required this.query, required this.result, required this.onKeep});
  final Shop shop;
  final String query;
  final AsyncValue<List<Offer>> result;
  final Future<void> Function(Offer) onKeep;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: shop.name,
    trailing: IconButton(
      tooltip: 'Open ${shop.name}',
      icon: const Icon(Icons.open_in_new, size: 20),
      onPressed: () => openShop(context, shop, url: shop.searchUrl(query)),
    ),
    padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
    child: switch (result) {
      AsyncData(:final value) when value.isEmpty => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(
          'Nothing matching found. The shop may want you to sign in or accept cookies first: open it.',
          style: TextStyle(color: muted(context)),
        ),
      ),
      AsyncData(:final value) => Column(
        children: [
          for (final o in value.take(3))
            ListTile(
              title: Text(o.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [o.unitPrice, o.offer, if (!o.inStock) 'Out of stock'].where((s) => s.isNotEmpty).join(' · '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pounds(o.pence),
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: o.offer.isEmpty ? null : tomato),
                  ),
                  IconButton(
                    tooltip: 'Keep this price',
                    icon: const Icon(Icons.bookmark_add_outlined),
                    onPressed: () => onKeep(o),
                  ),
                ],
              ),
            ),
        ],
      ),
      AsyncError(:final error) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text('Could not read ${shop.name}: ${describeError(error)}'),
      ),
      _ => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
    },
  );
}

/// Linux has no embedded web view: search each shop in the system browser
/// and type in what it costs.
class _NoWebView extends StatelessWidget {
  const _NoWebView({required this.shops, required this.query});
  final List<Shop> shops;
  final String query;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Search in your browser',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This device has no built-in browser for Bhojana to read shop pages with. Open each shop, then '
          'type the price you find. The Android and Windows apps search for you.',
          style: TextStyle(color: muted(context)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in shops)
              if (s.searchable)
                ActionChip(
                  avatar: const Icon(Icons.open_in_new, size: 16),
                  label: Text(s.name),
                  onPressed: () => openLink(context, query.trim().isEmpty ? s.home : s.searchUrl(query)),
                ),
          ],
        ),
      ],
    ),
  );
}
