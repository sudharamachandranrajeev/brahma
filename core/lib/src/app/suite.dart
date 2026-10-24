import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../identity.dart';
import '../security/key_vault.dart';
import '../ui/widgets.dart';
import 'session.dart';

/// One Brahma app as the Brahma suite app hosts it: everything the suite
/// needs to open the app's data and show its screens next to the others.
///
/// Each app exports one of these (lib/suite.dart) and keeps running on its
/// own as well; the suite never needs a change to learn about a new app.
class SuiteApp {
  const SuiteApp({
    required this.identity,
    required this.tagline,
    required this.icon,
    required this.open,
    required this.overrides,
    required this.hints,
    required this.theme,
    required this.home,
    required this.summary,
    this.themeMode,
    this.builder,
    this.onStart,
  });

  final AppIdentity identity;

  /// One line under the name on the home screen, e.g. "Money and investments".
  final String tagline;
  final IconData icon;

  /// Opens the app's own encrypted database with keys from [keys] (the
  /// suite's vault, so every app shares its sign-in).
  final Future<CoreSession> Function(KeyVault keys) open;

  /// The app's own providers to override with the open session; the core
  /// ones (session, identity, hints) are the suite's to set.
  final List<Override> Function(CoreSession session) overrides;

  /// The app's hint texts by id, without [coreHints].
  final Map<String, String> hints;

  /// The app's theme; [ref] reads the app's own appearance settings, if any.
  final ThemeData Function(WidgetRef ref, Brightness brightness) theme;

  /// The app's own light or dark choice, when it has one; otherwise the
  /// suite's.
  final ThemeMode? Function(WidgetRef ref)? themeMode;

  /// The app's screens, usually an [AppShell] over its destinations.
  /// [onHome] goes back to the suite's home screen (see [AppShell.onHome]).
  final Widget Function(VoidCallback onHome) home;

  /// The app's card body on the home screen: a few live figures, drawn in
  /// the app's theme.
  final WidgetBuilder summary;

  /// Wraps the app's screens, like MaterialApp.builder (e.g. a backdrop).
  final TransitionBuilder? builder;

  /// Background work to start with the suite (e.g. a routine refresh).
  final void Function(WidgetRef ref)? onStart;
}

/// A home-screen card body: a few figures and, optionally, the next thing
/// to do. Apps build their [SuiteApp.summary] from it so every card reads
/// the same way.
class SummaryFigures extends StatelessWidget {
  const SummaryFigures(this.figures, {super.key, this.next});

  /// Value and label pairs, e.g. ('3', 'follow-ups due').
  final List<(String, String)> figures;
  final String? next;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (figures.isNotEmpty)
          // Equal columns, so figures line up from card to card; long labels wrap.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, (value, label)) in figures.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        style: type.headlineSmall?.copyWith(fontWeight: FontWeight.w600).merge(tabular),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        label,
                        style: type.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        if (next != null) ...[
          if (figures.isNotEmpty) const SizedBox(height: 16),
          // The next thing to do, set apart as a prompt.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.east, size: 16, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(next!, style: type.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
