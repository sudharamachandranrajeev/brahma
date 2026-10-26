import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/modules.dart';
import '../app/providers.dart';
import '../help/ask_ai_ui.dart';
import 'hints.dart';
import 'theme.dart';

/// Navigation around every module's screens: a rail on wide windows; on phones
/// a scrolling dock and a side panel the page slides aside for. Pages are
/// built on first visit and then kept.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.destinations, this.onStart, this.floating = false, this.onHome});
  final List<Destination> destinations;

  /// Leaves the app for the place that opened it (the suite's home screen):
  /// a button above the rail, the first entry in the dock and panel on phones.
  final VoidCallback? onHome;

  /// The phone dock floats over the page as a rounded, shadowed pill, and the
  /// rail has no divider. Either way the dock takes its colours from the
  /// theme's NavigationBarTheme.
  final bool floating;

  /// Background work to start with the app (e.g. a daily data refresh).
  final void Function(WidgetRef ref)? onStart;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with TickerProviderStateMixin {
  late final _destinations = widget.destinations;
  // Fades the newly selected page in over the canvas.
  late final _fade = AnimationController(vsync: this, duration: Motion.medium, value: 1);
  late final _eased = CurvedAnimation(parent: _fade, curve: Motion.curve);
  // How far the phone side panel is open, 0 to 1.
  late final _panel = AnimationController(vsync: this, duration: Motion.medium)
    ..addStatusListener((s) {
      final shown = !s.isDismissed;
      if (shown != _panelShown) setState(() => _panelShown = shown);
    });
  var _panelShown = false;
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
    _panel.dispose();
    super.dispose();
  }

  void _settle({required bool open}) {
    if (Motion.reduced(context)) {
      _panel.value = open ? 1 : 0;
    } else {
      _panel.animateTo(open ? 1 : 0, curve: Motion.curve);
    }
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _visited.add(i);
    });
    if (!Motion.reduced(context)) _fade.forward(from: 0);
  }

  /// Ask AI about the screen on show.
  void _ask() {
    final d = _destinations[_index];
    showAskAi(context, screen: d.label, topic: ref.read(hintTextsProvider)['page.${d.id}']);
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
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    if (widget.onHome != null)
                      IconButton(onPressed: widget.onHome, tooltip: 'All apps', icon: const Icon(Icons.apps)),
                    const _Logo(),
                    const SizedBox(height: 8),
                    IconButton(
                      onPressed: _ask,
                      tooltip: 'Ask AI for help with this screen',
                      icon: const Icon(Icons.auto_awesome_outlined),
                    ),
                  ],
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Hint(d.hint, child: Icon(d.icon)),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            if (!widget.floating) const VerticalDivider(width: 1),
            Expanded(child: stack),
          ],
        ),
      );
    }

    // Phones, after Discord: the page slides aside to show every screen in a
    // side panel (swipe right anywhere, or the dock's menu button), and the
    // dock along the bottom scrolls through them all.
    final panelWidth = math.min(width * 0.84, 336.0);
    final dock = _Dock(
      destinations: _destinations,
      selected: _index,
      floating: widget.floating,
      onSelect: _select,
      onPanel: () => _settle(open: true),
      onHome: widget.onHome,
    );
    final Widget page;
    if (!widget.floating) {
      page = Scaffold(body: stack, bottomNavigationBar: dock);
    } else {
      page = Scaffold(
        extendBody: true,
        // The body runs under the dock, whose height arrives as bottom
        // padding. Pages' FABs place themselves by view padding, so pass it
        // on there too, or they sit behind the dock.
        body: Builder(
          builder: (context) {
            final mq = MediaQuery.of(context);
            final bottom = mq.padding.bottom > mq.viewPadding.bottom
                ? mq.padding.bottom
                : mq.viewPadding.bottom;
            return MediaQuery(
              data: mq.copyWith(viewPadding: mq.viewPadding.copyWith(bottom: bottom)),
              child: stack,
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.only(bottom: 12),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: dock),
        ),
      );
    }
    final panel = _SidePanel(
      destinations: _destinations,
      selected: _index,
      onHome: widget.onHome,
      onAsk: () {
        _settle(open: false);
        _ask();
      },
      onSelect: (i) {
        _select(i);
        _settle(open: false);
      },
    );
    return PopScope(
      // Back closes the panel before it leaves the app.
      canPop: !_panelShown,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _settle(open: false);
      },
      // Horizontal scrollers inside a page win their own drags: the arena
      // gives a drag to the deepest recognizer that claims it.
      child: GestureDetector(
        onHorizontalDragStart: (_) => _panel.stop(),
        onHorizontalDragUpdate: (d) => _panel.value += d.primaryDelta! / panelWidth,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          _settle(open: v.abs() > 365 ? v > 0 : _panel.value > 0.5);
        },
        child: AnimatedBuilder(
          animation: _panel,
          child: page,
          builder: (context, page) {
            final t = _panel.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                // Revealed as the page moves: pages are see-through over
                // the canvas, so the panel must not show under them.
                if (t > 0)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: panelWidth * t,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: panelWidth,
                        maxWidth: panelWidth,
                        child: panel,
                      ),
                    ),
                  ),
                Transform.translate(offset: Offset(panelWidth * t, 0), child: page),
                if (t > 0)
                  Positioned(
                    left: panelWidth * t,
                    top: 0,
                    bottom: 0,
                    width: 1,
                    child: ColoredBox(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                // While open, a tap on the page closes the panel.
                if (t > 0)
                  Positioned(
                    left: panelWidth * t,
                    top: 0,
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _settle(open: false),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The phone dock: every screen in one scrolling row, the selected one a
/// labelled capsule, with a button for the side panel at the start.
class _Dock extends StatefulWidget {
  const _Dock({
    required this.destinations,
    required this.selected,
    required this.floating,
    required this.onSelect,
    required this.onPanel,
    this.onHome,
  });
  final List<Destination> destinations;
  final int selected;
  final bool floating;
  final ValueChanged<int> onSelect;
  final VoidCallback onPanel;
  final VoidCallback? onHome;

  @override
  State<_Dock> createState() => _DockState();
}

class _DockState extends State<_Dock> {
  var _moreBefore = false;
  var _moreAfter = false;

  bool _edges(ScrollMetrics m) {
    final before = m.extentBefore > 1, after = m.extentAfter > 1;
    if (before != _moreBefore || after != _moreAfter) {
      setState(() {
        _moreBefore = before;
        _moreAfter = after;
      });
    }
    return false;
  }

  late final _keys = [for (final _ in widget.destinations) GlobalKey()];

  // Primary screens first, so the main ones show without scrolling.
  late final _order = [
    for (final (i, d) in widget.destinations.indexed)
      if (d.primary) i,
    for (final (i, d) in widget.destinations.indexed)
      if (!d.primary) i,
  ];

  @override
  void didUpdateWidget(_Dock old) {
    super.didUpdateWidget(old);
    if (old.selected == widget.selected) return;
    // Scroll the newly selected screen (picked from the panel, say) into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final item = _keys[widget.selected].currentContext;
      if (item == null || !item.mounted) return;
      Scrollable.ensureVisible(
        item,
        alignment: 0.5,
        duration: Motion.reduced(item) ? Duration.zero : Motion.medium,
        curve: Motion.curve,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bar = NavigationBarTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final quiet = bar.iconTheme?.resolve({})?.color ?? scheme.onSurfaceVariant;
    final row = Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: IconButton(
            onPressed: widget.onPanel,
            tooltip: 'All screens',
            icon: Icon(Icons.menu, color: quiet),
          ),
        ),
        Expanded(
          // The row fades out at an end with more beyond it, so it reads as
          // one that scrolls.
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (n) => _edges(n.metrics),
            child: NotificationListener<ScrollUpdateNotification>(
              onNotification: (n) => _edges(n.metrics),
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => LinearGradient(
                  colors: [
                    _moreBefore ? const Color(0x00000000) : const Color(0xFF000000),
                    const Color(0xFF000000),
                    const Color(0xFF000000),
                    _moreAfter ? const Color(0x00000000) : const Color(0xFF000000),
                  ],
                  stops: const [0, 0.06, 0.92, 1],
                ).createShader(r),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(4, 0, 14, 0),
                  child: Row(
                    children: [
                      if (widget.onHome != null)
                        _DockItem(
                          icon: Icons.apps,
                          selectedIcon: Icons.apps,
                          label: 'All apps',
                          onTap: widget.onHome!,
                        ),
                      for (final i in _order)
                        _DockItem(
                          key: _keys[i],
                          icon: widget.destinations[i].icon,
                          selectedIcon: widget.destinations[i].selectedIcon,
                          label: widget.destinations[i].label,
                          selected: i == widget.selected,
                          onTap: () => widget.onSelect(i),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    final background = bar.backgroundColor ?? scheme.surfaceContainer;
    if (!widget.floating) {
      return Material(
        color: background,
        child: SafeArea(top: false, child: SizedBox(height: 64, child: row)),
      );
    }
    return DecoratedBox(
      decoration: const ShapeDecoration(
        shape: StadiumBorder(),
        shadows: [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Material(
        color: background,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(height: 64, child: row),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bar = NavigationBarTheme.of(context);
    final theme = Theme.of(context);
    final states = {if (selected) WidgetState.selected};
    final color =
        bar.iconTheme?.resolve(states)?.color ??
        (selected ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onSurfaceVariant);
    final style = (bar.labelTextStyle?.resolve(states) ?? theme.textTheme.labelLarge)?.copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: selected,
          child: AnimatedContainer(
            duration: Motion.short,
            curve: Motion.curve,
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: selected
                  ? bar.indicatorColor ?? theme.colorScheme.secondaryContainer
                  : const Color(0x00000000),
            ),
            child: Material(
              type: MaterialType.transparency,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: AnimatedSize(
                  duration: Motion.short,
                  curve: Motion.curve,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 12, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(selected ? selectedIcon : icon, color: color),
                        if (selected) ...[const SizedBox(width: 8), Text(label, style: style, maxLines: 1)],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Every screen with what it is for, under the page as it slides aside.
class _SidePanel extends ConsumerWidget {
  const _SidePanel({
    required this.destinations,
    required this.selected,
    required this.onSelect,
    required this.onAsk,
    this.onHome,
  });
  final List<Destination> destinations;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onAsk;
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bar = NavigationBarTheme.of(context);
    final hints = ref.watch(hintsProvider).value?.enabled ?? true;
    final texts = ref.watch(hintTextsProvider);
    Widget tile(IconData icon, String label, String? subtitle, VoidCallback onTap, {bool selected = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: ListTile(
            leading: Icon(icon),
            title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: subtitle == null ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            selected: selected,
            selectedTileColor: bar.indicatorColor ?? scheme.secondaryContainer,
            selectedColor:
                bar.iconTheme?.resolve({WidgetState.selected})?.color ?? scheme.onSecondaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            onTap: onTap,
          ),
        );
    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        right: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
              child: Row(
                children: [
                  const _Logo(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      ref.watch(appIdentityProvider).name,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (onHome != null) tile(Icons.apps, 'All apps', null, onHome!),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'SCREENS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 1.6,
                ),
              ),
            ),
            for (final (i, d) in destinations.indexed)
              tile(
                i == selected ? d.selectedIcon : d.icon,
                d.label,
                hints ? texts[d.hint] : null,
                () => onSelect(i),
                selected: i == selected,
              ),
            const Divider(height: 24),
            tile(Icons.auto_awesome_outlined, 'Ask AI', 'Stuck? Ask how to do something here.', onAsk),
          ],
        ),
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
