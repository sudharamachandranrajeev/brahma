import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../identity.dart';
import '../security/key_vault.dart';
import '../ui/widgets.dart';
import 'modules.dart';
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
    required this.destinations,
    required this.summary,
    this.builder,
    this.onStart,
    this.floating = false,
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
  final ThemeData Function(Brightness) theme;
  final List<Destination> destinations;

  /// The app's card body on the home screen: a few live figures, drawn in
  /// the app's theme.
  final WidgetBuilder summary;

  /// Wraps the app's screens, like MaterialApp.builder (e.g. a backdrop).
  final TransitionBuilder? builder;

  /// Background work to start with the suite (e.g. a routine refresh).
  final void Function(WidgetRef ref)? onStart;

  /// Whether the app uses the floating navigation bar ([AppShell.floating]).
  final bool floating;
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            for (final (value, label) in figures)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value, style: type.titleLarge?.merge(tabular)),
                  Text(label, style: type.bodySmall?.copyWith(color: muted)),
                ],
              ),
          ],
        ),
        if (next != null) ...[
          const SizedBox(height: 10),
          Text(next!, style: type.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
  }
}
