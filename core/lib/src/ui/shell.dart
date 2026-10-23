import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/modules.dart';
import '../app/providers.dart';
import 'hints.dart';
import 'theme.dart';

/// Navigation around every module's screens: a rail on wide windows, a bottom
/// bar with "More" on phones. Pages are built on first visit and then kept.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.destinations, this.onStart});
  final List<Destination> destinations;

  /// Background work to start with the app (e.g. a daily data refresh).
  final void Function(WidgetRef ref)? onStart;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with SingleTickerProviderStateMixin {
  late final _destinations = widget.destinations;
  // Fades the newly selected page in over the canvas.
  late final _fade = AnimationController(vsync: this, duration: Motion.medium, value: 1);
  late final _eased = CurvedAnimation(parent: _fade, curve: Motion.curve);
  final _visited = <int>{0};
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Start the sync controller.
    ref.read(syncProvider);
    widget.onStart?.call(ref);
  }

  @override
  void dispose() {
    _eased.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _visited.add(i);
    });
    if (!Motion.reduced(context)) _fade.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final indexed = IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < _destinations.length; i++)
          _visited.contains(i)
              ? KeyedSubtree(key: ValueKey(_destinations[i].id), child: _destinations[i].page(context))
              : const SizedBox.shrink(),
      ],
    );
    final stack = FadeTransition(
      opacity: _eased,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.012), end: Offset.zero).animate(_eased),
        child: indexed,
      ),
    );

    if (width >= 840) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: width >= 1280,
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: width >= 1280 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              leading: const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: _Logo()),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Hint(d.hint, child: Icon(d.icon)),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: stack),
          ],
        ),
      );
    }

    final primary = [
      for (var i = 0; i < _destinations.length; i++)
        if (_destinations[i].primary) i,
    ];
    final more = [
      for (var i = 0; i < _destinations.length; i++)
        if (!_destinations[i].primary) i,
    ];
    final barIndex = primary.contains(_index) ? primary.indexOf(_index) : primary.length;
    return Scaffold(
      body: stack,
      bottomNavigationBar: NavigationBar(
        selectedIndex: barIndex,
        onDestinationSelected: (i) async {
          if (i < primary.length) return _select(primary[i]);
          final picked = await showModalBottomSheet<int>(
            context: context,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final j in more)
                    ListTile(
                      leading: Icon(_destinations[j].icon),
                      title: Text(_destinations[j].label),
                      subtitle: Text(ref.read(hintTextsProvider)[_destinations[j].hint] ?? ''),
                      selected: j == _index,
                      onTap: () => Navigator.pop(context, j),
                    ),
                ],
              ),
            ),
          );
          if (picked != null) _select(picked);
        },
        destinations: [
          for (final i in primary)
            NavigationDestination(
              icon: Hint(_destinations[i].hint, child: Icon(_destinations[i].icon)),
              selectedIcon: Icon(_destinations[i].selectedIcon),
              label: _destinations[i].label,
            ),
          NavigationDestination(
            icon: Hint('nav.more', child: const Icon(Icons.more_horiz)),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

class _Logo extends ConsumerWidget {
  const _Logo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final name = ref.watch(appIdentityProvider).name;
    return Tooltip(
      message: name,
      child: CircleAvatar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        child: Text(name[0], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
