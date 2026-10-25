import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/shops.dart';
import '../domain/web_searcher.dart';
import 'browser_page.dart';
import 'common.dart';
import 'look.dart';

class ShopsPage extends ConsumerWidget {
  const ShopsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = {for (final s in ref.watch(myShopsProvider).value ?? const <Shop>[]) s.id};
    final postcode = ref.watch(postcodeProvider).value ?? '';
    return PageScaffold(
      title: 'Shops',
      banner: 'page.shops',
      children: [
        SectionCard(
          title: 'Your postcode',
          child: Row(
            children: [
              Expanded(
                child: Text(
                  postcode.isEmpty
                      ? 'Not set. Shops price and stock by area, and slots depend on it.'
                      : '$postcode. Give the same postcode to each shop when it asks; the browser can copy it.',
                  style: TextStyle(color: muted(context)),
                ),
              ),
              TextButton(
                onPressed: () => _editPostcode(context, ref, postcode),
                child: Text(postcode.isEmpty ? 'Set' : 'Change'),
              ),
            ],
          ),
        ),
        if (!hasWebView)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'On this device shops open in your usual browser, signed in there. The Android and Windows '
              'apps open them inside Bhojana so searches use your sign-in.',
              style: TextStyle(color: muted(context)),
            ),
          ),
        for (final kind in shopKinds)
          SectionCard(
            title: kind,
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                for (final s in shops)
                  if (s.kind == kind) _ShopRow(s, compared: mine.contains(s.id), mine: mine),
              ],
            ),
          ),
      ],
    );
  }
}

Future<void> _editPostcode(BuildContext context, WidgetRef ref, String current) async {
  final c = TextEditingController(text: current);
  await showFormDialog(
    context,
    title: 'Your postcode',
    fields: (_) => [Field(c, 'Postcode', autofocus: true, hint: 'BT74 7AA')],
    onSave: () async {
      final p = c.text.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
      if (p.isNotEmpty && !RegExp(r'^[A-Z]{1,2}\d[A-Z\d]? ?\d[A-Z]{2}$').hasMatch(p)) {
        return 'That does not look like a UK postcode.';
      }
      await ref.mutate((s) => s.book.setPref(postcodePref, p));
      return null;
    },
  );
}

class _ShopRow extends ConsumerWidget {
  const _ShopRow(this.shop, {required this.compared, required this.mine});
  final Shop shop;
  final bool compared;
  final Set<String> mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: IconButton(
      tooltip: compared ? 'Stop comparing ${shop.name}' : 'Compare ${shop.name}',
      isSelected: compared,
      icon: const Icon(Icons.star_border),
      selectedIcon: const Icon(Icons.star, color: tomato),
      onPressed: shop.searchable
          ? () {
              final next = compared ? (mine.toSet()..remove(shop.id)) : {...mine, shop.id};
              ref.mutate((s) => s.book.setPref(shopsPref, next.join(',')));
            }
          : null,
    ),
    title: Text(shop.name),
    subtitle: Text(
      [
        shop.selling.label,
        if (shop.loyalty != null) '${shop.loyalty} prices when signed in',
        if (!shop.searchable) 'no online search',
      ].join(' · '),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (shop.slots != null)
          IconButton(
            tooltip: 'Delivery slots',
            icon: const Icon(Icons.local_shipping_outlined),
            onPressed: () => openShop(context, shop, url: shop.slots),
          ),
        IconButton(
          tooltip: shop.selling == Selling.browse ? 'Open ${shop.name}' : 'Sign in to ${shop.name}',
          icon: Icon(shop.selling == Selling.browse ? Icons.open_in_new : Icons.login),
          onPressed: () => openShop(context, shop),
        ),
      ],
    ),
  );
}
