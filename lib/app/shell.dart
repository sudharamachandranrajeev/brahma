import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/accounts_page.dart';
import '../ui/alerts_page.dart';
import '../ui/analytics_page.dart';
import '../ui/calendar_page.dart';
import '../ui/compose_page.dart';
import '../ui/home_page.dart';
import '../ui/inbox_page.dart';
import '../domain/models.dart' show Profile;
import '../ui/look.dart';
import '../ui/profiles.dart';
import '../ui/settings_page.dart';
import 'providers.dart';

/// Vani's frame: on wide screens an icon rail in a rounded card on the
/// left (the selected page on a red pill, Compose as a red button); on
/// phones a floating pill bar with Compose in the middle and a More sheet.
/// Pages swap with a short fade-and-rise. [onHome] leads back to the
/// Brahma suite's home screen when the suite hosts Vani.
class VaniShell extends ConsumerStatefulWidget {
  const VaniShell({super.key, this.onHome});
  final VoidCallback? onHome;

  @override
  ConsumerState<VaniShell> createState() => _VaniShellState();
}

class _VaniShellState extends ConsumerState<VaniShell> {
  @override
  void initState() {
    super.initState();
    ref.read(hubTickerProvider);
  }

  static Widget page(VaniTab tab) => switch (tab) {
    VaniTab.home => const HomePage(),
    VaniTab.calendar => const CalendarPage(),
    VaniTab.inbox => const InboxPage(),
    VaniTab.alerts => const AlertsPage(),
    VaniTab.analytics => const AnalyticsPage(),
    VaniTab.accounts => const AccountsPage(),
    VaniTab.settings => const SettingsPage(),
  };

  @override
  Widget build(BuildContext context) {
    // A profile deleted on another device: go back to the main one.
    ref.listen(profilesProvider, (_, next) {
      // Only a fresh list: while one reloads it still holds the old one.
      if (next.isLoading) return;
      final list = next.value;
      final current = ref.read(profileProvider).value;
      if (list != null && current != null && current != Profile.main && !list.any((p) => p.id == current)) {
        ref.read(profileProvider.notifier).set(Profile.main);
      }
    });
    final tab = ref.watch(tabProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final reduced = Motion.reduced(context);
    final body = AnimatedSwitcher(
      duration: reduced ? Duration.zero : const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.985, end: 1.0).animate(animation),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
      ),
      child: KeyedSubtree(key: ValueKey(tab), child: page(tab)),
    );
    final badges = _badges();
    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                child: _Rail(tab: tab, badges: badges, onHome: widget.onHome),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      extendBody: true,
      body: body,
      bottomNavigationBar: _PillBar(tab: tab, badges: badges, onHome: widget.onHome),
    );
  }

  /// Unread counts for Inbox and Alerts, when the overview has loaded.
  Map<VaniTab, int> _badges() {
    final o = ref.watch(overviewProvider).value;
    if (o == null) return const {};
    return {VaniTab.inbox: o.inboxNew, VaniTab.alerts: o.alerts.where((a) => !a.read).length};
  }
}

class _Rail extends ConsumerWidget {
  const _Rail({required this.tab, required this.badges, this.onHome});
  final VaniTab tab;
  final Map<VaniTab, int> badges;
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = Tone.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: tone.card,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: tone.stroke),
      ),
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  if (onHome != null) ...[
                    IconButton(
                      onPressed: onHome,
                      tooltip: 'All apps',
                      icon: Icon(Icons.apps_rounded, color: tone.muted),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const _Logo(),
                  const SizedBox(height: 14),
                  const ProfileButton(),
                  const SizedBox(height: 14),
                  for (final t in VaniTab.values)
                    if (t != VaniTab.settings) _RailButton(tab: t, selected: t == tab, badge: badges[t] ?? 0),
                  const SizedBox(height: 10),
                  Tooltip(
                    message: 'Compose',
                    child: Lift(
                      amount: 1.08,
                      child: Material(
                        color: signal,
                        shape: const CircleBorder(),
                        elevation: 6,
                        shadowColor: signal.withValues(alpha: 0.6),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => openCompose(context),
                          child: const SizedBox.square(
                            dimension: 50,
                            child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Tooltip(
                    message: dark ? 'Light theme' : 'Dark theme',
                    child: IconButton(
                      onPressed: () =>
                          ref.read(themeProvider.notifier).set(dark ? ThemeMode.light : ThemeMode.dark),
                      icon: Icon(
                        dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                        color: tone.muted,
                      ),
                    ),
                  ),
                  _RailButton(tab: VaniTab.settings, selected: tab == VaniTab.settings, badge: 0),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF4D52), signal, Color(0xFF9E0F13)],
      ),
      boxShadow: [
        BoxShadow(color: signal.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 6)),
      ],
    ),
    alignment: Alignment.center,
    child: const Text(
      'V',
      style: TextStyle(
        fontFamily: headingFont,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        fontSize: 22,
        height: 1,
      ),
    ),
  );
}

class _RailButton extends ConsumerWidget {
  const _RailButton({required this.tab, required this.selected, required this.badge});
  final VaniTab tab;
  final bool selected;
  final int badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = Tone.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: tab.label,
        waitDuration: const Duration(milliseconds: 400),
        child: Semantics(
          selected: selected,
          button: true,
          label: tab.label,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => ref.read(tabProvider.notifier).go(tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: selected ? signal : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  if (selected)
                    BoxShadow(
                      color: signal.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                ],
              ),
              child: _Badged(
                count: badge,
                child: Icon(
                  selected ? tab.selectedIcon : tab.icon,
                  color: selected ? Colors.white : tone.muted,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small red count on an icon's corner.
class _Badged extends StatelessWidget {
  const _Badged({required this.count, required this.child});
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      child,
      if (count > 0)
        Positioned(
          top: 8,
          right: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 18),
            decoration: BoxDecoration(
              color: growth,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Tone.of(context).card, width: 2),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ),
    ],
  );
}

class _PillBar extends ConsumerWidget {
  const _PillBar({required this.tab, required this.badges, this.onHome});
  final VaniTab tab;
  final Map<VaniTab, int> badges;
  final VoidCallback? onHome;

  static const _main = [VaniTab.home, VaniTab.calendar, VaniTab.inbox, VaniTab.alerts];
  static const _more = [VaniTab.analytics, VaniTab.accounts, VaniTab.settings];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inMore = _more.contains(tab);
    Widget item(VaniTab t) => _PillItem(
      label: t.label,
      icon: t == tab ? t.selectedIcon : t.icon,
      selected: t == tab,
      badge: badges[t] ?? 0,
      onTap: () => ref.read(tabProvider.notifier).go(t),
    );
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Center(
        heightFactor: 1,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF16161A).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              item(_main[0]),
              item(_main[1]),
              Tooltip(
                message: 'Compose',
                child: Material(
                  color: signal,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => openCompose(context),
                    child: const SizedBox.square(
                      dimension: 50,
                      child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
              item(_main[2]),
              item(_main[3]),
              _PillItem(
                label: 'More',
                icon: inMore ? tab.selectedIcon : Icons.grid_view_rounded,
                selected: inMore,
                badge: 0,
                onTap: () => _showMore(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMore(BuildContext context, WidgetRef ref) => showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onHome != null)
              ListTile(
                leading: const Icon(Icons.apps_rounded),
                title: const Text('All apps'),
                onTap: () {
                  Navigator.pop(sheet);
                  onHome!();
                },
              ),
            if (ref.read(hubLinkProvider).value?.ready ?? false)
              Consumer(
                builder: (_, r, _) {
                  final p = currentProfile(r);
                  return ListTile(
                    leading: ProfileAvatar(p, current: true, size: 28),
                    title: Text(p.name),
                    subtitle: const Text('Switch profile'),
                    onTap: () {
                      Navigator.pop(sheet);
                      showProfileSwitcher(context, ref);
                    },
                  );
                },
              ),
            for (final t in _more)
              ListTile(
                leading: Icon(t == tab ? t.selectedIcon : t.icon, color: t == tab ? signal : null),
                title: Text(t.label),
                selected: t == tab,
                onTap: () {
                  Navigator.pop(sheet);
                  ref.read(tabProvider.notifier).go(t);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class _PillItem extends StatelessWidget {
  const _PillItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.badge,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
          ),
          child: _Badged(
            count: badge,
            child: Icon(icon, color: selected ? Colors.white : Colors.white60, size: 23),
          ),
        ),
      ),
    ),
  );
}
