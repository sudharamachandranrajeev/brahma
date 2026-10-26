import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Vani's own Sentinel checks, run beside the core ones.
final vaniChecks = [hubCheck];

/// The social hub: its token posts to every connected account, so it should
/// not cross a network in clear.
final hubCheck = SecurityCheck(
  id: 'vani.hub',
  title: 'Social hub',
  findings: FutureProvider((ref) async {
    final link = await ref.watch(hubLinkProvider.future);
    if (!link.ready) return const [];
    return [
      ?linkInClear(
        id: 'vani.hub.http',
        name: "Vani's social hub",
        url: link.url,
        where: 'Settings, Social hub',
      ),
    ];
  }),
);
