import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'session.dart';

/// The open suite; main() overrides this before the first frame.
final suiteProvider = Provider<SuiteSession>((ref) => throw StateError('No session'));

/// What main() and the tests override: the suite's own session for core,
/// sync over every app's database, and each app's own providers.
List<Override> suiteOverrides(SuiteSession s) => [
  suiteProvider.overrideWithValue(s),
  coreSessionProvider.overrideWithValue(s.hub),
  appIdentityProvider.overrideWithValue(brahmaIdentity),
  hintTextsProvider.overrideWithValue({...coreHints, ...brahmaHints}),
  // The suite's own database holds only device settings, so it stays out
  // of sync; each app's database syncs as its own device on the account.
  syncStoresProvider.overrideWithValue([for (final x in s.sessions) x.store]),
  for (var i = 0; i < s.apps.length; i++) ...s.apps[i].overrides(s.sessions[i]),
];

const brahmaHints = <String, String>{'home.open': 'Open the app. "All apps" brings you back here.'};
