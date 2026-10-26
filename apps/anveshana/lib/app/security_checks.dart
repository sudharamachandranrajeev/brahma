import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Graha Anveshana's own Sentinel checks, run beside the core ones.
final anveshanaChecks = [watchCheck];

/// Brahma Watch: reached in clear (an address saved before the app asked for
/// https).
final watchCheck = SecurityCheck(
  id: 'anveshana.watch',
  title: 'Brahma Watch',
  findings: FutureProvider((ref) async {
    final watch = await ref.watch(watchProvider.future);
    if (watch == null) return const [];
    return [
      ?linkInClear(
        id: 'anveshana.watch.http',
        name: 'Brahma Watch',
        url: watch.url,
        where: 'Settings, Brahma Watch',
      ),
    ];
  }),
);
