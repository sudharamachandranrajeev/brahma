import 'dart:convert';
import 'dart:math';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/book.dart';
import '../domain/n8n.dart';
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
        Finding(
          id: 'udyoga.n8n.secret',
          status: Status.warning,
          title: 'The n8n workflow takes jobs from anyone',
          why:
              'Without a secret, anyone who learns the webhook address can run the workflow and spend your '
              'search and AI credits.',
          steps:
              '"Make a secret" saves a long random value under Settings, n8n lead workflow and copies it. In n8n, '
              'give the Webhook node a Header Auth credential named X-Udyoga-Secret with that value.',
          fix: QuickFix('Make a secret', (context, ref) => _makeSecret(context, ref, link)),
        ),
    ];
  }),
);

/// Saves a new random secret for the workflow, copies it and says where in
/// n8n it goes (docs/n8n/README.md).
Future<void> _makeSecret(BuildContext context, WidgetRef ref, N8nLink link) async {
  final random = Random.secure();
  final secret = base64Url.encode([for (var i = 0; i < 32; i++) random.nextInt(256)]).replaceAll('=', '');
  await ref.mutate((s) => s.book.setPref(PrefKeys.n8n, N8nLink(url: link.url, secret: secret).toJson()));
  await Clipboard.setData(ClipboardData(text: secret));
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Secret copied'),
      content: const Text(
        'Udyoga now sends it with each job. In n8n, open the Webhook node, set Authentication to Header Auth '
        'and create a credential with the name X-Udyoga-Secret and the copied value as its value.',
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
    ),
  );
}
