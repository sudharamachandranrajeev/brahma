import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/models.dart';
import 'common.dart';
import 'look.dart';

/// The current profile, or the main one while the list loads.
Profile currentProfile(WidgetRef ref) {
  final id = ref.watch(profileProvider).value ?? Profile.main;
  final list = ref.watch(profilesProvider).value ?? const <Profile>[];
  return list.firstWhere(
    (p) => p.id == id,
    orElse: () => Profile(id: id, name: id == Profile.main ? 'Main' : ''),
  );
}

/// A profile's initial on a round chip, red for the current one; [ring]
/// draws it as a red ring instead (the rail, under the red logo).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar(this.profile, {super.key, this.current = false, this.ring = false, this.size = 36});
  final Profile profile;
  final bool current, ring;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    final name = profile.name.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: current && !ring ? signal : tone.stroke,
        border: ring ? Border.all(color: signal, width: 2) : null,
      ),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(
          fontFamily: headingFont,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
          height: 1,
          color: current ? (ring ? Theme.of(context).colorScheme.onSurface : Colors.white) : tone.muted,
        ),
      ),
    );
  }
}

/// The rail's profile chip: shows whose social media this is and opens the switcher.
class ProfileButton extends ConsumerWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!(ref.watch(hubLinkProvider).value?.ready ?? false)) return const SizedBox.shrink();
    final p = currentProfile(ref);
    return Tooltip(
      message: 'Profile: ${p.name}',
      child: InkResponse(
        onTap: () => showProfileSwitcher(context, ref),
        radius: 26,
        child: ProfileAvatar(p, current: true, ring: true, size: 38),
      ),
    );
  }
}

/// Switches the whole app to another profile: accounts, posts, inbox, alerts and settings.
Future<void> switchProfile(BuildContext context, WidgetRef ref, Profile p) async {
  await ref.read(profileProvider.notifier).set(p.id);
  if (context.mounted) showMessage(context, 'Now managing ${p.name}.');
}

Future<void> showProfileSwitcher(BuildContext context, WidgetRef ref) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  // Actions use the caller's [ref]: the sheet's own is gone once it closes.
  builder: (sheet) => Consumer(
    builder: (sheet, live, _) {
      final current = live.watch(profileProvider).value ?? Profile.main;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: HubView(
            live.watch(profilesProvider),
            builder: (list) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text('Profiles', style: Theme.of(sheet).textTheme.titleLarge),
                ),
                for (final p in list)
                  ListTile(
                    leading: ProfileAvatar(p, current: p.id == current),
                    title: Text(p.name),
                    selected: p.id == current,
                    trailing: p.id == current ? const Icon(Icons.check_rounded, color: signal) : null,
                    onTap: () {
                      Navigator.pop(sheet);
                      if (p.id != current) switchProfile(context, ref, p);
                    },
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person_add_alt_rounded),
                  title: const Text('New profile'),
                  onTap: () {
                    Navigator.pop(sheet);
                    editProfile(context, ref, null);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: const Text('Manage profiles'),
                  onTap: () {
                    Navigator.pop(sheet);
                    ref.read(tabProvider.notifier).go(VaniTab.settings);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  ),
);

/// Makes a profile ([p] null, then switches to it) or renames [p].
Future<void> editProfile(BuildContext context, WidgetRef ref, Profile? p) async {
  final name = TextEditingController(text: p?.name ?? '');
  Profile? made;
  final ok = await showFormDialog(
    context,
    title: p == null ? 'New profile' : 'Rename profile',
    action: p == null ? 'Create' : 'Save',
    fields: (_) => [
      if (p == null) ...[
        const Text(
          'A profile has its own accounts, posts, inbox, rules and settings: for another person, a business '
          'or a client. App credentials and the Anthropic key are shared by every profile.',
        ),
        const SizedBox(height: 16),
      ],
      Field(name, 'Name', hint: 'Pottery shop'),
    ],
    onSave: () async {
      final n = name.text.trim();
      if (n.isEmpty) return 'Enter a name.';
      if (n.length > 40) return 'Keep the name under 40 characters.';
      if (p == null) {
        made = await ref.hub((h) => h.addProfile(n));
      } else {
        await ref.hub((h) => h.renameProfile(p.id, n));
      }
      return null;
    },
  );
  if (ok && made != null && context.mounted) await switchProfile(context, ref, made!);
}

/// Settings' list of profiles: switch, rename, delete (the card around it adds new ones).
class ProfileList extends ConsumerWidget {
  const ProfileList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(profileProvider).value ?? Profile.main;
    final t = Theme.of(context).textTheme;
    return HubView(
      ref.watch(profilesProvider),
      builder: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Each profile is a separate workspace. Switching changes the whole app, on this device only.',
            style: t.bodyMedium?.copyWith(color: Tone.of(context).muted),
          ),
          const SizedBox(height: 8),
          for (final p in list)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: ProfileAvatar(p, current: p.id == current),
              title: Text(p.name),
              subtitle: p.id == current ? const Text('In use on this device') : null,
              onTap: p.id == current ? null : () => switchProfile(context, ref, p),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Rename ${p.name}',
                    onPressed: () => editProfile(context, ref, p),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  if (p.id != Profile.main)
                    IconButton(
                      tooltip: 'Delete ${p.name}',
                      onPressed: () => _delete(context, ref, p),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Profile p) async {
    if (!await confirm(
      context,
      title: 'Delete ${p.name}?',
      message:
          'Its posts, media, inbox, alerts, rules and settings are deleted from the hub. Remove its accounts '
          'first. This can\'t be undone.',
      action: 'Delete',
      destructive: true,
    )) {
      return;
    }
    if (!context.mounted) return;
    final wasCurrent = ref.read(profileProvider).value == p.id;
    final ok = await guarded(context, () => ref.hub((h) => h.deleteProfile(p.id)));
    if (!ok || !context.mounted) return;
    if (wasCurrent) await ref.read(profileProvider.notifier).set(Profile.main);
    if (context.mounted) showMessage(context, '${p.name} deleted.');
  }
}
