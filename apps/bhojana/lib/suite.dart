import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/session.dart';
import 'domain/book.dart';
import 'ui/hints.dart';
import 'ui/look.dart';

/// Bhojana as the Brahma suite app hosts it.
final bhojanaSuite = SuiteApp(
  identity: bhojanaIdentity,
  tagline: 'Shopping and groceries',
  icon: Icons.shopping_basket_rounded,
  open: AppSession.open,
  overrides: (s) => [sessionProvider.overrideWithValue(s as AppSession)],
  hints: bhojanaHints,
  theme: (_, b) => bhojanaTheme(b),
  home: (onHome) => BhojanaHome(onHome: onHome),
  builder: (context, child) => Backdrop(child: child ?? const SizedBox.shrink()),
  summary: (_) => const _Summary(),
);

class _Summary extends ConsumerWidget {
  const _Summary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsProvider).value;
    final prices = ref.watch(pricesProvider).value;
    if (items == null || prices == null) return const SizedBox(height: 48);
    final left = items.where((i) => !i.done).toList();
    final cheapest = costByShop(left, prices).firstOrNull;
    return SummaryFigures([
      ('${left.length}', 'to buy'),
      ('${items.length - left.length}', 'in the basket'),
      (
        cheapest == null ? '–' : pounds(cheapest.pence),
        cheapest == null ? 'no prices yet' : shopName(cheapest.shop),
      ),
    ], next: items.isEmpty ? 'Start a shopping list.' : null);
  }
}
