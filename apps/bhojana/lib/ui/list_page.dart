import 'dart:async';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/pricing.dart';
import '../app/providers.dart';
import '../db/database.dart';
import '../domain/book.dart';
import '../domain/shops.dart';
import 'browser_page.dart';
import 'common.dart';
import 'compare_page.dart';
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
                  icon: Icons.shopping_basket_outlined,
                  title: 'Start a shopping list',
                  message: 'Add what you need, then compare it across shops.',
                  actions: [
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
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
    icon: const Icon(Icons.list_alt),
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
    final list = ref.read(currentListProvider).value;
    final text = _add.text.trim();
    if (list == null || text.isEmpty) return;
    _add.clear();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
            controller: _add,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Add an item',
              hintText: '2 milk, bread, washing-up liquid',
              suffixIcon: IconButton(tooltip: 'Add', icon: const Icon(Icons.add), onPressed: _submit),
            ),
          ),
        ),
        if (items.isEmpty)
          const EmptyState(icon: Icons.edit_note, title: 'Nothing on this list yet')
        else
          SectionCard(
            title: '${left.length} to buy',
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(children: [for (final i in items) _ItemRow(i, bestPrice(i.id, prices))]),
          ),
        if (left.isNotEmpty) _Costs(left, prices),
      ],
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
    return ListTile(
      leading: Checkbox(value: done, onChanged: (v) => ref.mutate((s) => s.book.tick(item, v ?? false))),
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
                if (best!.offer.isNotEmpty) best!.offer,
                if (best!.source == 'auto') best!.title,
                if (searching > 0) 'searching $searching more',
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: tomato),
            ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Item',
        onSelected: (v) async {
          switch (v) {
            case 'compare':
              await Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => ComparePage(item: item)));
            case 'edit':
              await _editItem(context, ref, item);
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

Future<void> _editItem(BuildContext context, WidgetRef ref, Item item) async {
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

/// What the rest of the list costs at each compared shop, which one is
/// cheapest, and the way to fill its basket.
class _Costs extends ConsumerWidget {
  const _Costs(this.left, this.prices);
  final List<Item> left;
  final List<Price> prices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myShopsProvider).value ?? const <Shop>[];
    final ids = {for (final s in mine) s.id};
    final costs = [
      for (final c in costByShop(left, prices))
        if (ids.contains(c.shop)) c,
    ];
    final verdict = cheapestShop(left, prices, costs);
    final lookups = ref.watch(pricerProvider);
    final searching = lookups.values.where((l) => l == Lookup.searching).length;
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
                      style: text.titleMedium?.copyWith(color: tomato, fontWeight: FontWeight.w700),
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
          for (final c in costs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(shopName(c.shop)),
              subtitle: Text(c.complete ? 'Every item priced' : '${c.priced} of ${c.items} items priced'),
              trailing: Text(
                pounds(c.pence),
                style: text.titleMedium?.copyWith(color: c.shop == verdict?.best ? tomato : null),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (available)
                OutlinedButton.icon(
                  icon: const Icon(Icons.travel_explore),
                  label: const Text('Check prices'),
                  onPressed: searching > 0 ? null : () => ref.read(pricerProvider.notifier).price(left, mine),
                ),
              if (fillable.isNotEmpty)
                FilledButton.icon(
                  icon: const Icon(Icons.shopping_cart_checkout),
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
