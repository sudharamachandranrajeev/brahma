import 'dart:async';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/pricing.dart';
import '../app/providers.dart';
import '../db/database.dart';
import '../domain/aisles.dart';
import '../domain/book.dart';
import '../domain/shops.dart';
import 'browser_page.dart';
import 'charts.dart';
import 'common.dart';
import 'compare_page.dart';
import 'item_page.dart';
import 'look.dart';

class ListPage extends ConsumerWidget {
  const ListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(listsProvider);
    final list = ref.watch(currentListProvider).value;
    return PageScaffold(
      title: list?.name ?? 'List',
      banner: 'page.list',
      actions: [if (list != null) _ListMenu(list, lists.value ?? const [])],
      children: [
        AsyncView(
          lists,
          builder: (all) => all.isEmpty
              ? EmptyState(
                  icon: Icons.shopping_basket_rounded,
                  title: 'Start a shopping list',
                  message: 'Add what you need, then compare it across shops.',
                  actions: [
                    FilledButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New list'),
                      onPressed: () => _newList(context, ref, suggested: 'Weekly shop'),
                    ),
                  ],
                )
              : const _Items(),
        ),
      ],
    );
  }
}

Future<void> _newList(BuildContext context, WidgetRef ref, {String suggested = ''}) async {
  final name = TextEditingController(text: suggested);
  String? id;
  await showFormDialog(
    context,
    title: 'New list',
    action: 'Create',
    fields: (_) => [Field(name, 'Name', autofocus: true)],
    onSave: () async {
      if (name.text.trim().isEmpty) return 'Give the list a name.';
      id = await ref.mutate((s) => s.book.addList(name.text, today: today()));
      return null;
    },
  );
  if (id != null) ref.read(currentListIdProvider.notifier).select(id);
}

class _ListMenu extends ConsumerWidget {
  const _ListMenu(this.list, this.all);
  final ShopList list;
  final List<ShopList> all;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    tooltip: 'Lists',
    icon: const Icon(Icons.list_alt_rounded),
    onSelected: (v) async {
      switch (v) {
        case 'new':
          await _newList(context, ref);
        case 'rename':
          final name = TextEditingController(text: list.name);
          await showFormDialog(
            context,
            title: 'Rename list',
            fields: (_) => [Field(name, 'Name', autofocus: true)],
            onSave: () async {
              if (name.text.trim().isEmpty) return 'Give the list a name.';
              await ref.mutate((s) => s.book.renameList(list, name.text));
              return null;
            },
          );
        case 'reset':
          await ref.mutate((s) => s.book.resetList(list.id));
        case 'delete':
          if (await askSure(context, 'Delete ${list.name}?', 'Its items go too. Prices you kept stay.')) {
            await ref.mutate((s) => s.book.removeList(list.id));
            ref.read(currentListIdProvider.notifier).select(null);
          }
        default:
          ref.read(currentListIdProvider.notifier).select(v.substring(5));
      }
    },
    itemBuilder: (_) => [
      for (final l in all)
        CheckedPopupMenuItem(value: 'list:${l.id}', checked: l.id == list.id, child: Text(l.name)),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'new', child: Text('New list')),
      const PopupMenuItem(value: 'rename', child: Text('Rename')),
      const PopupMenuItem(value: 'reset', child: Text('Untick everything')),
      const PopupMenuItem(value: 'delete', child: Text('Delete list')),
    ],
  );
}

class _Items extends ConsumerStatefulWidget {
  const _Items();

  @override
  ConsumerState<_Items> createState() => _ItemsState();
}

class _ItemsState extends ConsumerState<_Items> {
  final _add = TextEditingController();

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _add.text.trim();
    _add.clear();
    await _addText(text);
  }

  Future<void> _addText(String text) async {
    final list = ref.read(currentListProvider).value;
    if (list == null || text.isEmpty) return;
    final id = await ref.mutate((s) => s.book.addItem(list.id, text, today: today()));
    // Price it at every compared shop straight away.
    final item = (await ref.read(sessionProvider).book.items(list.id)).where((i) => i.id == id);
    final mine = await ref.read(myShopsProvider.future);
    unawaited(ref.read(pricerProvider.notifier).price(item.toList(), mine));
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemsProvider).value ?? const <Item>[];
    final prices = ref.watch(pricesProvider).value ?? const <Price>[];
    final left = items.where((i) => !i.done).toList();
    final grouped = ref.watch(groupedProvider).value ?? false;
    final usual = ref.watch(usualProvider).value ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Overview(items, left, prices),
        if (items.isNotEmpty) _Budget(items, prices),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
            controller: _add,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Add an item',
              hintText: '2 milk, bread, washing-up liquid',
              suffixIcon: IconButton(tooltip: 'Add', icon: const Icon(Icons.add_rounded), onPressed: _submit),
            ),
          ),
        ),
        if (usual.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Add again',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: muted(context)),
                ),
                for (final n in usual)
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: Text(n),
                    onPressed: () => _addText(n),
                  ),
              ],
            ),
          ),
        if (items.isEmpty)
          const EmptyState(icon: Icons.edit_note_rounded, title: 'Nothing on this list yet')
        else
          SectionCard(
            title: '${left.length} to buy',
            padding: const EdgeInsets.only(bottom: 8),
            trailing: IconButton(
              tooltip: grouped ? 'Show in the order added' : 'Group by aisle',
              isSelected: grouped,
              icon: const Icon(Icons.view_agenda_outlined),
              selectedIcon: const Icon(Icons.view_agenda_rounded),
              onPressed: () => ref.mutate((s) => s.book.setPref(groupPref, grouped ? '0' : '1')),
            ),
            child: Column(
              children: [
                if (grouped)
                  ..._byAisle(items, prices)
                else
                  for (final i in items) _ItemRow(i, bestPrice(i.id, prices)),
              ],
            ),
          ),
        _Drops(left, prices),
        if (left.isNotEmpty) _Deals(left, prices),
        if (left.isNotEmpty) _Costs(left, prices),
      ],
    );
  }
}

/// The top of the list: a greeting with how the shop is going, and tiles for
/// what is left, what is in the basket, the shops compared and the deals.
class _Overview extends ConsumerWidget {
  const _Overview(this.items, this.left, this.prices);
  final List<Item> items;
  final List<Item> left;
  final List<Price> prices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myShopsProvider).value ?? const <Shop>[];
    final deals = ref.watch(dealsProvider).value ?? const <String, bool>{};
    final offers = dealOffers(left, prices, deals, {for (final s in mine) s.id});
    final hour = DateTime.now().hour;
    final text = Theme.of(context).textTheme;
    final dark = isDark(context);
    // On a phone the list itself must stay near the top.
    final narrow = MediaQuery.sizeOf(context).width < 640;
    StatTile tile((Color, Color) tone, IconData icon, int value, String label) =>
        StatTile(tone: tone, icon: icon, value: '$value', label: label, compact: narrow);
    final tiles = [
      tile(sage, Icons.checklist_rounded, left.length, 'To buy'),
      tile(peach, Icons.shopping_basket_rounded, items.length - left.length, 'In basket'),
      tile(butter, Icons.storefront_rounded, mine.length, 'Shops'),
      tile(sky, Icons.local_offer_rounded, offers.length, 'Multi-buys'),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: narrow
                ? const EdgeInsets.fromLTRB(20, 16, 16, 16)
                : const EdgeInsets.fromLTRB(24, 22, 20, 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tileFill(context, peach), tileFill(context, butter)],
              ),
              boxShadow: clayShadow(context),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hour < 12
                            ? 'Good morning'
                            : hour < 18
                            ? 'Good afternoon'
                            : 'Good evening',
                        style: text.headlineMedium?.copyWith(fontSize: narrow ? 22 : 26),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items.isEmpty
                            ? 'Add what you need and Bhojana finds the best price for each.'
                            : left.isEmpty
                            ? 'Everything is in the basket. Nicely done.'
                            : 'Bhojana searches your shops for each item and costs the list.',
                        style: (narrow ? text.bodyMedium : text.bodyLarge)?.copyWith(
                          color: dark ? null : const Color(0xFF6E5442),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ClayIcon(Icons.shopping_basket_rounded, tone: sage, size: narrow ? 52 : 72),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TileGrid(minWidth: 160, children: tiles),
        ],
      ),
    );
  }
}

/// The items under a header for each aisle, in the order a shop is walked.
List<Widget> _byAisle(List<Item> items, List<Price> prices) {
  final out = <Widget>[];
  for (final aisle in walkOrder) {
    final here = items.where((i) => aisleOf(i.name) == aisle).toList();
    if (here.isEmpty) continue;
    out.add(_AisleHeader(aisle, here.where((i) => !i.done).length));
    for (final i in here) {
      out.add(_ItemRow(i, bestPrice(i.id, prices)));
    }
  }
  return out;
}

/// An aisle's name and how many of its items are left, above them.
class _AisleHeader extends StatelessWidget {
  const _AisleHeader(this.aisle, this.left);
  final Aisle aisle;
  final int left;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = aisleLook(aisle);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tone.$2),
          const SizedBox(width: 8),
          Text(aisle.label, style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          if (left > 0)
            Text('$left left', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted(context))),
        ],
      ),
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow(this.item, this.best);
  final Item item;
  final Price? best;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = item.done;
    final searching = ref.watch(
      pricerProvider.select(
        (m) => m.entries.where((e) => e.key.$1 == item.id && e.value == Lookup.searching).length,
      ),
    );
    final (icon, tone) = aisleLook(aisleOf(item.name));
    return ListTile(
      onTap: () => openItem(context, item.id),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(value: done, onChanged: (v) => ref.mutate((s) => s.book.tick(item, v ?? false))),
          Opacity(
            opacity: done ? 0.45 : 1,
            child: ClayIcon(icon, tone: tone, size: 40),
          ),
        ],
      ),
      title: Text(
        '${item.qty > 1 ? '${item.qty} × ' : ''}${item.name}',
        style: done ? TextStyle(decoration: TextDecoration.lineThrough, color: muted(context)) : null,
      ),
      subtitle: searching > 0 && best == null
          ? Text(
              'Searching $searching ${searching == 1 ? 'shop' : 'shops'}…',
              style: TextStyle(color: muted(context)),
            )
          : best == null
          ? (item.note.isEmpty ? null : Text(item.note))
          : Text(
              [
                '${pounds(best!.pence)} at ${shopName(best!.shop)}',
                if (best!.multiBuy case final d?)
                  'multi-buy ${d.text}'
                else if (best!.offer.isNotEmpty)
                  best!.offer,
                if (best!.source == 'auto') best!.title,
                if (searching > 0) 'searching $searching more',
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: priceInk(context)),
            ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Item',
        onSelected: (v) async {
          switch (v) {
            case 'compare':
              await Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => ComparePage(item: item)));
            case 'edit':
              await editItem(context, ref, item);
            case 'delete':
              await ref.mutate((s) => s.book.removeItem(item.id));
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'compare', child: Text('Compare prices')),
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}

/// The running total: what is in the basket and what the whole list comes
/// to at each item's best price, against the list's budget when it has one.
class _Budget extends ConsumerWidget {
  const _Budget(this.items, this.prices);
  final List<Item> items;
  final List<Price> prices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(budgetProvider).value;
    final deals = ref.watch(dealsProvider).value ?? const <String, bool>{};
    final s = spend(items, prices, deals: deals);
    final text = Theme.of(context).textTheme;
    final over = budget != null && s.list > budget;
    final basketOver = budget != null && s.basket > budget;
    return SectionCard(
      title: budget == null ? 'Running total' : 'Budget ${pounds(budget)}',
      trailing: TextButton(
        onPressed: () => _setBudget(context, ref, budget),
        child: Text(budget == null ? 'Set a budget' : 'Change'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${pounds(s.basket)} in the basket', style: text.titleMedium),
          if (budget != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 12,
                value: (s.basket / budget).clamp(0.0, 1.0),
                color: basketOver ? Theme.of(context).colorScheme.error : null,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            [
              'The whole list comes to about ${pounds(s.list)} at the best prices',
              if (s.unpriced > 0) ', with ${s.unpriced} ${s.unpriced == 1 ? 'item' : 'items'} not priced yet',
              '.',
              if (budget != null && !over) ' ${pounds(budget - s.list)} to spare.',
            ].join(),
            style: TextStyle(color: muted(context)),
          ),
          if (over)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                basketOver
                    ? 'The basket is ${pounds(s.basket - budget)} over budget.'
                    : 'The list is ${pounds(s.list - budget)} over budget.',
                style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _setBudget(BuildContext context, WidgetRef ref, int? now) async {
  final list = ref.read(currentListProvider).value;
  if (list == null) return;
  final amount = TextEditingController(text: now == null ? '' : (now / 100).toStringAsFixed(2));
  await showFormDialog(
    context,
    title: 'Budget for ${list.name}',
    fields: (_) => [
      Field(amount, 'Budget in £', number: true, hint: '60, or empty for none', autofocus: true),
    ],
    onSave: () async {
      final n = numberIn(amount);
      if (amount.text.trim().isNotEmpty && (n == null || n <= 0)) return 'Type an amount, like 60.';
      await ref.mutate((s) => s.book.setBudget(list.id, n == null ? null : (n * 100).round()));
      return null;
    },
  );
}

/// Watched items whose best price has fallen since they were last priced.
class _Drops extends ConsumerWidget {
  const _Drops(this.left, this.prices);
  final List<Item> left;
  final List<Price> prices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drops = priceDrops(left, prices, ref.watch(watchedProvider).value ?? const {});
    if (drops.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: drops.length == 1 ? 'A price drop' : '${drops.length} price drops',
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          for (final d in drops)
            ListTile(
              onTap: () => openItem(context, d.item.id),
              leading: const ClayIcon(Icons.trending_down_rounded, tone: sage),
              title: Text(d.item.name),
              subtitle: Text(dropText(d), style: TextStyle(color: priceInk(context))),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
        ],
      ),
    );
  }
}

/// Multi-buy deals found for the list. Bhojana compares single prices until
/// the user takes a deal; then that item is costed, and its basket filled,
/// as whole deals.
class _Deals extends ConsumerWidget {
  const _Deals(this.left, this.prices);
  final List<Item> left;
  final List<Price> prices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = {for (final s in ref.watch(myShopsProvider).value ?? const <Shop>[]) s.id};
    final deals = ref.watch(dealsProvider).value ?? const <String, bool>{};
    final offers = dealOffers(left, prices, deals, mine);
    if (offers.isEmpty) return const SizedBox.shrink();
    final open = offers.where((o) => o.taken == null).length;
    final text = Theme.of(context).textTheme;
    return SectionCard(
      title: open > 0 ? 'Multi-buy deals: $open to decide' : 'Multi-buy deals',
      hint: 'action.deals',
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          for (final o in offers)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${o.item.name} at ${shopName(o.price.shop)}', style: text.titleSmall),
                  Text(
                    o.price.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted(context)),
                  ),
                  const SizedBox(height: 4),
                  Text('Single purchase: ${pounds(o.price.pence)} each'),
                  Text(
                    'Multi-buy deal: ${o.deal.text} (${pounds(o.deal.each)} each). For your '
                    '${o.item.qty}, buy ${o.deal.units(o.item.qty)} for ${pounds(o.deal.cost(o.item.qty))}'
                    ' instead of ${pounds(o.price.pence * o.item.qty)}.',
                    style: TextStyle(color: priceInk(context)),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<bool>(
                    emptySelectionAllowed: true,
                    segments: const [
                      ButtonSegment(value: true, label: Text('Take deal')),
                      ButtonSegment(value: false, label: Text('Single price')),
                    ],
                    selected: {?o.taken},
                    onSelectionChanged: (v) {
                      if (v.isEmpty) return;
                      ref.mutate((s) => s.book.chooseDeal(dealKey(o.price, o.deal), v.first));
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// What the rest of the list costs at each compared shop, which one is
/// cheapest, and the way to fill its basket.
class _Costs extends ConsumerWidget {
  const _Costs(this.left, this.prices);
  final List<Item> left;
  final List<Price> prices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myShopsProvider).value ?? const <Shop>[];
    final deals = ref.watch(dealsProvider).value ?? const <String, bool>{};
    final ids = {for (final s in mine) s.id};
    final costs = [
      for (final c in costByShop(left, prices, deals: deals))
        if (ids.contains(c.shop)) c,
    ];
    final verdict = cheapestShop(left, prices, costs, deals: deals);
    final lookups = ref.watch(pricerProvider);
    final searching = lookups.values.where((l) => l == Lookup.searching).length;
    final checks = {
      for (final e in lookups.entries)
        if (e.value == Lookup.checkNeeded) e.key.$2,
    };
    final available = ref.watch(searcherProvider).available;
    final fillable = [
      for (final s in mine)
        if (s.searchable && s.selling != Selling.browse) s,
    ];
    final text = Theme.of(context).textTheme;
    return SectionCard(
      title: 'Where to shop',
      hint: 'action.basket',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (verdict != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Cheapest at ${shopName(verdict.best)}: ', style: text.titleMedium),
                    TextSpan(
                      text: pounds(verdict.pence),
                      style: text.titleMedium?.copyWith(
                        color: priceInk(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: [
                        verdict.items == left.length
                            ? ' for all ${left.length} ${left.length == 1 ? 'item' : 'items'}'
                            : ' for the ${verdict.items} items every shop has',
                        if (verdict.runnerUp != null)
                          verdict.saving > 0
                              ? ', ${pounds(verdict.saving)} less than ${shopName(verdict.runnerUp!)}.'
                              : ', the same as ${shopName(verdict.runnerUp!)}.',
                      ].join(),
                    ),
                  ],
                ),
              ),
            ),
          if (costs.isEmpty && searching == 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                available
                    ? 'No prices yet. Check prices to search your shops for every item.'
                    : 'No prices yet. Compare an item from its menu to cost the list.',
                style: TextStyle(color: muted(context)),
              ),
            ),
          if (searching > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text(
                    '$searching ${searching == 1 ? 'search' : 'searches'} to go',
                    style: TextStyle(color: muted(context)),
                  ),
                ],
              ),
            ),
          // Only the user can answer a shop's bot check; searches share the
          // browser's cookies, so Check prices works again afterwards.
          for (final shop in mine)
            if (checks.contains(shop.id))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.gpp_maybe_rounded),
                title: Text('${shop.name} wants to check you are a person'),
                subtitle: const Text('Open it, answer the check, then Check prices again.'),
                trailing: TextButton(
                  onPressed: () => openShop(context, shop, url: shop.searchUrl('milk')),
                  child: Text('Open ${shop.name}'),
                ),
              ),
          if (costs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: BarRows([
                for (final c in costs)
                  BarRow(
                    label: shopName(c.shop),
                    caption: c.complete ? 'Every item priced' : '${c.priced} of ${c.items} items priced',
                    figure: pounds(c.pence),
                    value: c.pence,
                    tone: shopTone(c.shop),
                    stress: c.shop == verdict?.best,
                  ),
              ]),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (available)
                OutlinedButton.icon(
                  icon: const Icon(Icons.travel_explore_rounded),
                  label: const Text('Check prices'),
                  onPressed: searching > 0 ? null : () => ref.read(pricerProvider.notifier).price(left, mine),
                ),
              if (fillable.isNotEmpty)
                FilledButton.icon(
                  style: coralButton(context),
                  icon: const Icon(Icons.shopping_cart_checkout_rounded),
                  label: const Text('Fill a basket'),
                  onPressed: () async {
                    final shop = await _pickShop(context, fillable, costs, verdict?.best);
                    if (shop != null && context.mounted) await openShop(context, shop, basket: left);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<Shop?> _pickShop(BuildContext context, List<Shop> shops, List<ShopCost> costs, String? best) =>
    showDialog<Shop>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Fill which basket?'),
        children: [
          for (final s in [...shops.where((s) => s.id == best), ...shops.where((s) => s.id != best)])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, s),
              child: Row(
                children: [
                  Expanded(child: Text(s.id == best ? '${s.name} (cheapest)' : s.name)),
                  Text(switch (costs.where((c) => c.shop == s.id).firstOrNull) {
                    final c? => pounds(c.pence),
                    null => '',
                  }),
                ],
              ),
            ),
        ],
      ),
    );
