import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/aisles.dart';
import '../domain/book.dart';
import '../domain/shops.dart';
import 'browser_page.dart';
import 'charts.dart';
import 'common.dart';
import 'compare_page.dart';
import 'look.dart';

Future<void> openItem(BuildContext context, String itemId) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ItemPage(itemId: itemId)));

/// One list item on its own page: what it is, what it costs at each shop,
/// how its price has moved, and what to do with it.
class ItemPage extends ConsumerWidget {
  const ItemPage({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsProvider).value;
    final item = items?.where((i) => i.id == itemId).firstOrNull;
    if (item == null) {
      return PageScaffold(
        title: 'Item',
        children: [
          if (items != null)
            const EmptyState(icon: Icons.remove_shopping_cart_rounded, title: 'This item is not on the list'),
        ],
      );
    }
    final all = ref.watch(pricesProvider).value ?? const <Price>[];
    final kept = [
      for (final p in all)
        if (p.itemId == item.id) p,
    ];
    final latest = latestPrices(kept).values.toList()..sort((a, b) => a.pence.compareTo(b.pence));
    final best = bestPrice(item.id, kept);
    final lowest = kept.isEmpty ? null : kept.map((p) => p.pence).reduce((a, b) => a < b ? a : b);
    final last = kept.isEmpty ? null : kept.map((p) => p.day).reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    final byDay = <String, int>{};
    for (final p in kept) {
      if (byDay[p.day] case final had? when had <= p.pence) continue;
      byDay[p.day] = p.pence;
    }
    final days = [for (final d in byDay.keys.toList()..sort()) (d, byDay[d]!)];
    final watched = ref.watch(watchedProvider).value ?? const <String>{};
    final drop = priceDrops([item], kept, watched).firstOrNull;
    final narrow = MediaQuery.sizeOf(context).width < 640;
    StatTile tile((Color, Color) tone, IconData icon, String value, String label) =>
        StatTile(tone: tone, icon: icon, value: value, label: label, compact: narrow);
    return PageScaffold(
      title: item.name,
      children: [
        _Hero(item, watched: watched.contains(item.id)),
        TileGrid(
          minWidth: 160,
          children: [
            tile(
              peach,
              Icons.sell_rounded,
              best == null ? '–' : pounds(best.pence),
              best == null ? 'No price yet' : 'Best, ${shopName(best.shop)}',
            ),
            tile(sky, Icons.storefront_rounded, '${latest.length}', 'Shops priced'),
            tile(sage, Icons.trending_down_rounded, lowest == null ? '–' : pounds(lowest), 'Lowest seen'),
            tile(butter, Icons.event_rounded, switch (last) {
              null => '–',
              final d when d == today() => 'Today',
              final d => DateFormat('d MMM').format(DateTime.parse(d)),
            }, 'Last priced'),
          ],
        ),
        SectionCard(
          title: 'Prices at each shop',
          child: latest.isEmpty
              ? Text(
                  'No prices yet. Compare prices to search your shops for it.',
                  style: TextStyle(color: muted(context)),
                )
              : BarRows([
                  for (final p in latest)
                    BarRow(
                      label: shopName(p.shop),
                      caption: [
                        p.title,
                        p.unitPrice,
                        p.offer,
                        if (!p.inStock) 'out of stock',
                      ].where((s) => s.isNotEmpty).join(' · '),
                      figure: pounds(p.pence),
                      value: p.pence,
                      tone: shopTone(p.shop),
                      stress: p.id == best?.id,
                      trailing: _PriceMenu(p),
                    ),
                ]),
        ),
        SectionCard(
          title: 'Price history',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (drop != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    dropText(drop),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: priceInk(context)),
                  ),
                ),
              if (days.length < 2)
                Text(
                  'Bhojana keeps the price each day it looks. The trend shows from the second day.',
                  style: TextStyle(color: muted(context)),
                )
              else
                PriceTrend(days),
            ],
          ),
        ),
      ],
    );
  }
}

/// The item in its aisle's colours: name, note, how many, whether it is in
/// the basket, and the ways to act on it.
class _Hero extends ConsumerWidget {
  const _Hero(this.item, {required this.watched});
  final Item item;
  final bool watched;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aisle = aisleOf(item.name);
    final (icon, tone) = aisleLook(aisle);
    final text = Theme.of(context).textTheme;
    final narrow = MediaQuery.sizeOf(context).width < 640;
    Future<void> setQty(int n) => ref.mutate((s) => s.book.saveItem(item.copyWith(qty: n)));
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(narrow ? 18 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tileFill(context, tone), Theme.of(context).colorScheme.surfaceContainerLow],
        ),
        boxShadow: clayShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClayIcon(icon, tone: tone, size: narrow ? 64 : 88),
              SizedBox(width: narrow ? 16 : 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(aisle.label, style: text.labelLarge?.copyWith(color: muted(context))),
                    Text(item.name, style: text.headlineMedium?.copyWith(fontSize: narrow ? 24 : 30)),
                    if (item.note.isNotEmpty)
                      Text(item.note, style: text.bodyMedium?.copyWith(color: muted(context))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RoundIconButton(
                    icon: Icons.remove_rounded,
                    tooltip: 'One less',
                    onPressed: item.qty > 1 ? () => setQty(item.qty - 1) : null,
                  ),
                  SizedBox(
                    width: 44,
                    child: Text('${item.qty}', textAlign: TextAlign.center, style: text.titleLarge),
                  ),
                  RoundIconButton(
                    icon: Icons.add_rounded,
                    tooltip: 'One more',
                    onPressed: () => setQty(item.qty + 1),
                  ),
                ],
              ),
              FilterChip(
                avatar: Icon(
                  item.done ? Icons.shopping_basket_rounded : Icons.radio_button_unchecked_rounded,
                ),
                showCheckmark: false,
                label: Text(item.done ? 'In the basket' : 'Still to buy'),
                selected: item.done,
                onSelected: (v) => ref.mutate((s) => s.book.tick(item, v)),
              ),
              FilterChip(
                avatar: Icon(watched ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
                showCheckmark: false,
                label: Text(watched ? 'Watching the price' : 'Watch the price'),
                tooltip: 'Show on the list when its best price falls',
                selected: watched,
                onSelected: (v) => ref.mutate((s) => s.book.watch(item.id, v)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                style: coralButton(context),
                icon: const Icon(Icons.travel_explore_rounded),
                label: const Text('Compare prices'),
                onPressed: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => ComparePage(item: item))),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit'),
                onPressed: () => editItem(context, ref, item),
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
                onPressed: () async {
                  if (!await askSure(context, 'Delete ${item.name}?', 'Prices you kept stay.')) return;
                  await ref.mutate((s) => s.book.removeItem(item.id));
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opens the product's page at the shop, or forgets the price.
class _PriceMenu extends ConsumerWidget {
  const _PriceMenu(this.price);
  final Price price;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    tooltip: 'Price',
    icon: const Icon(Icons.more_vert_rounded),
    onSelected: (v) async {
      switch (v) {
        case 'open':
          final shop = shopById(price.shop);
          if (shop == null) return openLink(context, price.url);
          await openShop(context, shop, url: price.url);
        case 'forget':
          await ref.mutate((s) => s.book.removePrice(price.id));
      }
    },
    itemBuilder: (_) => [
      if (price.url.isNotEmpty) const PopupMenuItem(value: 'open', child: Text('Open at the shop')),
      const PopupMenuItem(value: 'forget', child: Text('Forget this price')),
    ],
  );
}

/// "£1.39 at Aldi, down 10p from £1.49 on 18 Oct".
String dropText(PriceDrop d) =>
    '${pounds(d.now.pence)} at ${shopName(d.now.shop)}, down ${pounds(d.was.pence - d.now.pence)} '
    'from ${pounds(d.was.pence)} on ${DateFormat('d MMM').format(DateTime.parse(d.was.day))}';

Future<void> editItem(BuildContext context, WidgetRef ref, Item item) async {
  final name = TextEditingController(text: item.name);
  final qty = TextEditingController(text: '${item.qty}');
  final note = TextEditingController(text: item.note);
  await showFormDialog(
    context,
    title: 'Edit item',
    fields: (_) => [
      Field(name, 'Name', autofocus: true),
      Field(qty, 'How many', number: true),
      Field(note, 'Note', hint: 'Brand, size, "only if on offer"'),
    ],
    onSave: () async {
      final n = numberIn(qty)?.round() ?? 0;
      if (name.text.trim().isEmpty) return 'Give the item a name.';
      if (n < 1) return 'How many must be 1 or more.';
      await ref.mutate(
        (s) => s.book.saveItem(item.copyWith(name: name.text.trim(), qty: n, note: note.text.trim())),
      );
      return null;
    },
  );
}
