import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/format.dart';
import '../ui/hints.dart';
import '../ui/widgets.dart';
import 'pairing_dialogs.dart';
import 'owner_tools.dart';
import 'providers.dart';
import 'sentinel_page.dart';
import 'sync_dialogs.dart';
import 'sync_wizard.dart';

/// Settings sections every Brahma app shows. Each app's settings page puts
/// its own sections around these.

/// Hints on or off, and bringing dismissed tips back.
class HintsCard extends ConsumerWidget {
  const HintsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hints = ref.watch(hintsProvider).value ?? const HintsState();
    return SectionCard(
      title: 'Hints',
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Show hints'),
            subtitle: const Text('Explanations on hover or long-press, and tips at the top of pages.'),
            value: hints.enabled,
            onChanged: (v) => ref.read(hintsProvider.notifier).setEnabled(v),
          ),
          ListTile(
            title: const Text('Restore hints'),
            subtitle: Text(
              hints.dismissed.isEmpty
                  ? 'No tips dismissed.'
                  : '${hints.dismissed.length} dismissed ${hints.dismissed.length == 1 ? 'tip' : 'tips'}.',
            ),
            trailing: Hint(
              'settings.restoreHints',
              child: OutlinedButton(
                onPressed: () async {
                  await ref.read(hintsProvider.notifier).restore();
                  if (context.mounted) showMessage(context, 'Hints are back on.');
                },
                child: const Text('Restore'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How the data is protected, and what Sentinel found. [network] says what,
/// if anything, the app sends without sync.
class SecurityCard extends StatelessWidget {
  const SecurityCard({super.key, required this.network});
  final String network;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Security and privacy',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SentinelTile(),
          for (final (icon, text) in [
            (
              Icons.lock_outline,
              'The database on this device is encrypted with ChaCha20-Poly1305 (SQLite3MultipleCiphers). '
                  'Its key is kept in the system keychain.',
            ),
            (Icons.cloud_off_outlined, network),
            (
              Icons.enhanced_encryption_outlined,
              'Sync is end-to-end encrypted with XChaCha20-Poly1305. Keys come from your password '
                  'through Argon2id. The server stores only ciphertext and cannot read your data.',
            ),
            (
              Icons.key_outlined,
              'Your password and recovery key never leave this device. Lose both and synced data '
                  'cannot be recovered; data on this device is unaffected.',
            ),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The app's name, what it is, and the open-source licences.
class AboutCard extends ConsumerWidget {
  const AboutCard({super.key, required this.description});
  final String description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(appIdentityProvider).name;
    return SectionCard(
      title: 'About',
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(name),
        subtitle: Text('$description Part of Brahma. Open-source licences of included software.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showLicensePage(context: context, applicationName: name),
      ),
    );
  }
}

/// Sign in, add devices, sync now, change password, sign out.
class SyncCard extends ConsumerWidget {
  const SyncCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncProvider);
    final signedOut = sync.phase == SyncPhase.signedOut;
    return SectionCard(
      title: 'Sync',
      hint: 'settings.sync',
      padding: const EdgeInsets.only(bottom: 8),
      child: signedOut
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Keep ${ref.watch(appIdentityProvider).name} in step across your devices through your own '
                    'sync server. Everything is encrypted on the device first.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => showSyncWizard(context),
                        icon: const Icon(Icons.cloud_sync_outlined),
                        label: const Text('Set up sync'),
                      ),
                      OutlinedButton(
                        onPressed: () => showJoinDialog(context),
                        child: const Text('Join from another device'),
                      ),
                      TextButton(
                        onPressed: () => showSyncDialog(context, mode: SyncMode.signIn),
                        child: const Text('Sign in with e-mail'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(sync.email ?? 'Signed in'),
                  subtitle: Text(sync.server ?? ''),
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code_2),
                  title: const Text('Add a device'),
                  subtitle: const Text('Show a code your phone or another computer can join with'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showAddDevice(context),
                ),
                const OwnerTools(),
                ListTile(
                  leading: Icon(switch (sync.phase) {
                    SyncPhase.failed => Status.critical.icon,
                    SyncPhase.running => Icons.sync,
                    _ => Status.good.icon,
                  }, color: sync.phase == SyncPhase.failed ? Status.critical.color : null),
                  title: Text(switch (sync.phase) {
                    SyncPhase.running => 'Syncing…',
                    SyncPhase.failed => 'Last sync failed',
                    _ => sync.lastSync == null ? 'Not synced yet' : 'Synced',
                  }),
                  subtitle: Text(
                    [
                      if (sync.error != null) sync.error!,
                      if (sync.lastSync != null) 'Last success ${_when(sync.lastSync!)}',
                    ].join('\n'),
                  ),
                  trailing: OutlinedButton(
                    onPressed: sync.phase == SyncPhase.running
                        ? null
                        : () => ref.read(syncProvider.notifier).run(),
                    child: const Text('Sync now'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => showChangePassword(context, ref),
                        child: const Text('Change password'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final yes = await confirm(
                            context,
                            title: 'Sign out of sync?',
                            message:
                                'Data stays on this device and on the server. Signing back in needs your '
                                'password, or your recovery key if the password changed.',
                            action: 'Sign out',
                          );
                          if (yes && context.mounted) {
                            await guarded(context, () => ref.read(syncProvider.notifier).signOut());
                          }
                        },
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  static String _when(String iso) {
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return iso;
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${niceDate(t.toIso8601String().substring(0, 10))} at $hm';
  }
}
