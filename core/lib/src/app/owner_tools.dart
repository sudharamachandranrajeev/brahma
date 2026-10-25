import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/widgets.dart';
import 'providers.dart';

/// Settings tiles only the owner of a Worker sync server sees: invite
/// someone, or give a member a reset code. Hidden for everyone else.
class OwnerTools extends ConsumerStatefulWidget {
  const OwnerTools({super.key});

  @override
  ConsumerState<OwnerTools> createState() => _OwnerToolsState();
}

class _OwnerToolsState extends ConsumerState<OwnerTools> {
  bool _owner = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final owner = await (await ref.read(coreSessionProvider).account.api()).isOwner();
      if (mounted) setState(() => _owner = owner);
    } catch (_) {
      // Offline or a server without owners: the tiles stay hidden.
    }
  }

  Future<void> _invite() async {
    final account = ref.read(coreSessionProvider).account;
    final scheme = ref.read(appIdentityProvider).linkScheme;
    String? code;
    Uri? server;
    if (!await guarded(context, () async {
      final api = await account.api();
      server = api.server;
      code = await api.createInvite();
    })) {
      return;
    }
    if (!mounted) return;
    final link = Uri(scheme: scheme, host: 'setup', queryParameters: {'s': '$server', 'i': code!}).toString();
    await _showCodes(
      'Invite someone',
      'They install the app, choose Set up sync, and paste this link, or enter the server address and this '
          'code. It works once and expires in 7 days.',
      {'Invite code': code!, 'Setup link': link},
    );
  }

  Future<void> _reset() async {
    final email = TextEditingController();
    final who = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset someone\'s login'),
        content: TextField(
          controller: email,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Their e-mail',
            helperText: 'They still need their recovery key to unlock their data.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, email.text.trim()),
            child: const Text('Make code'),
          ),
        ],
      ),
    );
    email.dispose();
    if (who == null || who.isEmpty || !mounted) return;
    String? code;
    if (!await guarded(context, () async {
      code = await (await ref.read(coreSessionProvider).account.api()).createResetCode(who);
    })) {
      return;
    }
    if (!mounted) return;
    await _showCodes(
      'Reset code for $who',
      'Send it to them. In the app they choose Sign in, Forgot password, and enter this code with a new '
          'password and their recovery key. It works once.',
      {'Reset code': code!},
    );
  }

  Future<void> _showCodes(String title, String text, Map<String, String> codes) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(text),
            for (final MapEntry(:key, :value) in codes.entries) ...[
              const SizedBox(height: 12),
              Text(key, style: Theme.of(context).textTheme.labelMedium),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(value, style: const TextStyle(fontFamily: 'monospace')),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => Clipboard.setData(ClipboardData(text: value)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!_owner) return const SizedBox.shrink();
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.person_add_alt_outlined),
          title: const Text('Invite someone'),
          subtitle: const Text('Make a code for a family member to create their own account on your server'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _invite,
        ),
        ListTile(
          leading: const Icon(Icons.lock_reset),
          title: const Text('Reset a member\'s login'),
          subtitle: const Text('For someone who forgot their password'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _reset,
        ),
      ],
    );
  }
}
