import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/pricing.dart';
import '../app/providers.dart';
import 'look.dart';

/// The top of the side rail: the basket mark, with the name when there is
/// room for it.
class RailHeader extends StatelessWidget {
  const RailHeader({super.key, required this.extended});
  final bool extended;

  @override
  Widget build(BuildContext context) {
    const mark = ClayIcon(Icons.shopping_basket_rounded, tone: peach, size: 44);
    if (!extended) return const Tooltip(message: 'Bhojana', child: mark);
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          mark,
          const SizedBox(width: 12),
          Text('Bhojana', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

/// The foot of the side rail: a card to search every shop for what is left
/// on the list, or a round button when the rail is narrow.
class RailFooter extends ConsumerWidget {
  const RailFooter({super.key, required this.extended});
  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsProvider).value ?? const [];
    final mine = ref.watch(myShopsProvider).value ?? const [];
    final left = items.where((i) => !i.done).toList();
    if (!ref.watch(searcherProvider).available || left.isEmpty || mine.isEmpty) {
      return const SizedBox.shrink();
    }
    final busy = ref.watch(pricerProvider).values.any((l) => l == Lookup.searching);
    final check = busy ? null : () => ref.read(pricerProvider.notifier).price(left, mine);
    if (!extended) {
      return RoundIconButton(
        icon: Icons.travel_explore_rounded,
        tooltip: 'Search every shop',
        onPressed: check,
      );
    }
    final text = Theme.of(context).textTheme;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tileFill(context, peach), tileFill(context, butter)],
        ),
        boxShadow: clayShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ClayIcon(Icons.travel_explore_rounded, tone: peach, size: 36),
          const SizedBox(height: 10),
          Text('Prices move daily', style: text.titleMedium),
          Text(
            'Search every shop again for the ${left.length} ${left.length == 1 ? 'item' : 'items'} left.',
            style: text.bodySmall?.copyWith(color: muted(context)),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: coralButton(context),
            onPressed: check,
            child: Text(busy ? 'Searching…' : 'Search shops'),
          ),
        ],
      ),
    );
  }
}
