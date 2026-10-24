import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../identity.dart';
import '../security/key_vault.dart';
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
