import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/models.dart';
import 'ai_settings.dart';
import 'common.dart';
import 'hub_setup.dart';
import 'look.dart';
import 'profiles.dart';

export 'common.dart' show editHub;

const _zones = [
  'Europe/London',
  'Europe/Dublin',
  'Europe/Paris',
  'Europe/Berlin',
  'America/New_York',
  'America/Chicago',
  'America/Los_Angeles',
  'Asia/Kolkata',
  'Asia/Dubai',
  'Asia/Singapore',
  'Australia/Sydney',
  'UTC',
];

/// The hub link, its profiles, the greeting name, the theme, the current
/// profile's hub settings (time zone, posting queue, saved replies, AI), then the shared
/// hints, sync, security and about cards.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(hubLinkProvider).value;
    final name = ref.watch(nameProvider).value ?? '';
    final theme = ref.watch(themeProvider).value ?? ThemeMode.dark;
    final t = Theme.of(context).textTheme;
    final tone = Tone.of(context);
    return PageBody(
      maxWidth: 900,
      children: [
        const PageHeader('Settings'),
        _Card(
          title: 'Social hub',
          hint: 'settings.hub',
          trailing: TextButton(
            onPressed: () => editHub(context, ref),
            child: Text(link?.ready ?? false ? 'Change' : 'Connect'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    link?.ready ?? false ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                    color: link?.ready ?? false ? growth : tone.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      link?.ready ?? false ? Uri.tryParse(link!.url)?.host ?? link.url : 'Not connected. Set up your own hub (once, on a computer), or connect one you have.',
                      style: t.bodyLarge,
                    ),
                  ),
                ],
              ),
              if (!(link?.ready ?? false) || canDeployHub) ...[
                const SizedBox(height: 12),
                const _HubUpkeep(),
              ],
              if (link?.ready ?? false) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Hint(
                    'settings.notify',
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        if (await guarded(context, () => ref.hub((h) => h.testNotify(), refresh: false)) &&
                            context.mounted) {
                          showMessage(
                            context,
                            'Test alert sent. It should reach your phone in a few seconds.',
                          );
                        }
                      },
                      icon: const Icon(Icons.notifications_active_outlined, size: 18),
                      label: const Text('Send a test alert'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => showPhoneLink(context, link!),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: const Text('Phone link'),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (link?.ready ?? false)
          _Card(
            title: 'Profiles',
            hint: 'settings.profiles',
            trailing: TextButton.icon(
              onPressed: () => editProfile(context, ref, null),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
            ),
            child: const ProfileList(),
          ),
        _Card(
          title: 'You',
          child: _NameField(name: name, onSave: (v) => ref.mutate((s) => s.prefs.saveName(v))),
        ),
        _Card(
          title: 'Appearance',
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_outlined, size: 18),
                ),
              ],
              selected: {theme},
              showSelectedIcon: false,
              onSelectionChanged: (s) => ref.read(themeProvider.notifier).set(s.first),
            ),
          ),
        ),
        if (link?.ready ?? false)
          HubView(ref.watch(hubSettingsProvider), builder: (s) => _HubSettings(settings: s)),
        const HintsCard(),
        const SyncCard(),
        const SecurityCard(
          network:
              'This device talks only to your own hub (and your sync server, if you sign in). The hub talks to '
              'the platforms you connect and, for AI features, to the AI service you pick with your key.',
        ),
        const AboutCard(
          description:
              'Social media manager: post and schedule to Instagram, Facebook, YouTube, LinkedIn, Threads, '
              'Bluesky and Mastodon, answer every reply in one inbox, and get alerts for what you are looking for.',
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.hint, this.trailing});
  final String title;
  final String? hint;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final heading = Text(title, style: Theme.of(context).textTheme.titleMedium);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: hint == null ? heading : Hint(hint!, child: heading)),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _NameField extends StatefulWidget {
  const _NameField({required this.name, required this.onSave});
  final String name;
  final ValueChanged<String> onSave;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final _c = TextEditingController(text: widget.name);

  @override
  void didUpdateWidget(_NameField old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name && _c.text != widget.name) _c.text = widget.name;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _c,
    decoration: const InputDecoration(labelText: 'Your name', helperText: 'For the greeting on Home.'),
    onSubmitted: widget.onSave,
    onTapOutside: (_) {
      if (_c.text.trim() != widget.name) widget.onSave(_c.text);
    },
  );
}

/// The hub's version, and a button to set one up or update it (desktop; on
/// a phone the button explains the computer step).
class _HubUpkeep extends ConsumerWidget {
  const _HubUpkeep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(hubLinkProvider).value?.ready ?? false;
    final bundled = ref.watch(hubBundleProvider).value?.version;
    final version = ready ? ref.watch(hubVersionProvider) : null;
    final older = bundled != null && version is AsyncData<String?> && hubIsOlder(version.value, bundled);
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(color: Tone.of(context).muted);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (version is AsyncData<String?>)
          Text(
            older
                ? 'Hub ${version.value ?? '0.2 or older'}: version $bundled is ready.'
                : 'Hub ${version.value}, up to date.',
            style: muted,
          ),
        if (!ready || older)
          FilledButton.tonalIcon(
            onPressed: () => setUpHub(context, ref),
            icon: Icon(ready ? Icons.system_update_alt_rounded : Icons.rocket_launch_rounded, size: 18),
            label: Text(ready ? 'Update hub' : 'Set up a hub'),
          ),
      ],
    );
  }
}

class _HubSettings extends ConsumerWidget {
  const _HubSettings({required this.settings});
  final HubSettings settings;

  Future<void> _save(BuildContext context, WidgetRef ref, HubSettings s) async {
    await guarded(context, () => ref.hub((h) => h.saveSettings(s)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = settings;
    final t = Theme.of(context).textTheme;
    final queue = [...s.queue]..sort((a, b) => a.day != b.day ? a.day - b.day : a.time.compareTo(b.time));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          title: 'Posting',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Choice<String>(
                label: 'Time zone for the queue',
                value: s.timezone,
                options: {
                  for (final z in {s.timezone, ..._zones}) z: z.replaceAll('_', ' '),
                },
                onChanged: (v) => _save(context, ref, s.copyWith(timezone: v)),
              ),
              Hint(
                'settings.language',
                child: Choice<String>(
                  label: 'Translate the inbox into',
                  value: s.language,
                  options: {
                    for (final l in {s.language, ...languageNames.values}) l: l,
                  },
                  onChanged: (v) => _save(context, ref, s.copyWith(language: v)),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Hint(
                  'settings.weekly',
                  child: AiButton(
                    label: 'Send this week\'s summary now',
                    onPressed: () => guarded(context, () async {
                      final a = await ref.hub((h) => h.weeklySummary());
                      if (context.mounted) showMessage(context, a.title);
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
        _Card(
          title: 'AI',
          hint: 'settings.ai',
          child: AiSettings(settings: s, onSave: (v) => _save(context, ref, v)),
        ),
        _Card(
          title: 'Queue',
          hint: 'settings.queue',
          trailing: TextButton.icon(
            onPressed: () => _addSlot(context, ref),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add slot'),
          ),
          child: queue.isEmpty
              ? Text(
                  'No slots yet. Add weekly times (for example Mon, Wed, Fri at 18:30) and "Add to queue" fills '
                  'them in order.',
                  style: t.bodyMedium?.copyWith(color: Tone.of(context).muted),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final q in queue)
                      InputChip(
                        label: Text('${weekdays[q.day.clamp(0, 6)]} ${q.time}'),
                        onDeleted: () => _save(
                          context,
                          ref,
                          s.copyWith(
                            queue: [
                              for (final x in s.queue)
                                if (x.day != q.day || x.time != q.time) x,
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        _Card(
          title: 'Saved replies',
          trailing: TextButton.icon(
            onPressed: () => _editReply(context, ref, null),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (s.savedReplies.isEmpty)
                Text(
                  'Answers you give often. Use {name} for the person\'s first name.',
                  style: t.bodyMedium?.copyWith(color: Tone.of(context).muted),
                ),
              for (final r in s.savedReplies)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(Icons.bookmark_outline_rounded),
                  title: Text(r.title),
                  subtitle: Text(r.text, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => _editReply(context, ref, r),
                  trailing: IconButton(
                    tooltip: 'Delete',
                    onPressed: () => _save(
                      context,
                      ref,
                      s.copyWith(
                        savedReplies: [
                          for (final x in s.savedReplies)
                            if (x.id != r.id) x,
                        ],
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addSlot(BuildContext context, WidgetRef ref) async {
    var day = 0;
    var time = const TimeOfDay(hour: 18, minute: 30);
    await showFormDialog(
      context,
      title: 'Add a queue slot',
      action: 'Add',
      fields: (setState) => [
        Choice<int>(
          label: 'Day',
          value: day,
          options: {for (var i = 0; i < 7; i++) i: weekdays[i]},
          onChanged: (v) => setState(() => day = v),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showTimePicker(context: context, initialTime: time);
            if (picked != null) setState(() => time = picked);
          },
          icon: const Icon(Icons.schedule_rounded, size: 18),
          label: Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'),
        ),
        const SizedBox(height: 12),
      ],
      onSave: () async {
        final hhmm = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        if (settings.queue.any((q) => q.day == day && q.time == hhmm)) return 'That slot is already there.';
        await ref.hub(
          (h) => h.saveSettings(settings.copyWith(queue: [...settings.queue, QueueSlot(day, hhmm)])),
        );
        return null;
      },
    );
  }

  Future<void> _editReply(BuildContext context, WidgetRef ref, SavedReply? r) async {
    final title = TextEditingController(text: r?.title ?? '');
    final text = TextEditingController(text: r?.text ?? '');
    await showFormDialog(
      context,
      title: r == null ? 'New saved reply' : 'Edit saved reply',
      fields: (_) => [
        Field(title, 'Title', hint: 'Opening hours'),
        Field(text, 'Reply', hint: 'Hi {name}! We are open 9 to 5, Monday to Saturday.', lines: 4),
      ],
      onSave: () async {
        if (title.text.trim().isEmpty || text.text.trim().isEmpty) return 'Enter a title and the reply.';
        final reply = SavedReply(id: r?.id ?? newId(), title: title.text.trim(), text: text.text.trim());
        final list = r == null
            ? [...settings.savedReplies, reply]
            : [for (final x in settings.savedReplies) x.id == r.id ? reply : x];
        await ref.hub((h) => h.saveSettings(settings.copyWith(savedReplies: list)));
        return null;
      },
    );
  }
}
