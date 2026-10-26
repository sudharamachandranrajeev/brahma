import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Udyoga's own Sentinel checks, run beside the core ones.
final udyogaChecks = [n8nCheck];

/// The n8n lead workflow: reached in clear, or open to anyone who learns its
/// address.
final n8nCheck = SecurityCheck(
  id: 'udyoga.n8n',
  title: 'n8n lead workflow',
  findings: FutureProvider((ref) async {
    final link = await ref.watch(n8nLinkProvider.future);
    if (!link.isSet) return const [];
    return [
      ?linkInClear(id: 'udyoga.n8n.http', name: 'n8n', url: link.url, where: 'Settings, n8n lead workflow'),
      if (link.secret.isEmpty)
        const Finding(
          id: 'udyoga.n8n.secret',
          status: Status.warning,
          title: 'The n8n workflow takes jobs from anyone',
          why:
              'Without a secret, anyone who learns the webhook address can run the workflow and spend your '
              'search and AI credits.',
          steps:
              'In n8n, give the Webhook node a Header Auth credential named X-Udyoga-Secret with a long random '
              'value, then put the same value under Settings, n8n lead workflow.',
        ),
    ];
  }),
);
