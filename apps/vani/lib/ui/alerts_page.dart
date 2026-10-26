import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/hub.dart' show DiscoveryRun;
import '../domain/models.dart';
import 'common.dart';
import 'home_page.dart' show alertIcon;
import 'post_page.dart' show WarningBox;
import 'look.dart';

/// Alerts, and what raises them: inbox rules (keywords or a plain-English
/// condition, with an optional auto-reply) and discovery watches (a
/// described search over listings, hashtags, businesses and posts that the
/// hub runs on a schedule, with Claude judging each find).
class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage({super.key});

  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(alertsProvider).value?.where((a) => !a.read).length ?? 0;
    return PageBody(
      maxWidth: 1100,
      children: [
        PageHeader(
          'Alerts',
          subtitle: unread == 0 ? 'Rules and watches that tell you what matters' : '$unread unread',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Feed'), icon: Icon(Icons.notifications_rounded, size: 18)),
              ButtonSegment(
                value: 1,
                label: Text('Discovery'),
                icon: Icon(Icons.travel_explore_rounded, size: 18),
              ),
              ButtonSegment(value: 2, label: Text('Rules'), icon: Icon(Icons.rule_rounded, size: 18)),
            ],
            selected: {_tab},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 300),
          layoutBuilder: (current, previous) =>
              Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
          child: KeyedSubtree(
            key: ValueKey(_tab),
            child: switch (_tab) {
              0 => const _Feed(),
              1 => const _Discovery(),
              _ => const _Rules(),
            },
          ),
        ),
      ],
    );
  }
}

class _Feed extends ConsumerStatefulWidget {
  const _Feed();

  @override
  ConsumerState<_Feed> createState() => _FeedState();
}

class _FeedState extends ConsumerState<_Feed> {
  String? _kind;

  @override
  Widget build(BuildContext context) => HubView(
    ref.watch(alertsProvider),
    builder: (all) {
      final list = [
        for (final a in all)
          if (_kind == null || a.kind == _kind) a,
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in [null, 'discovery', 'inbox', 'publish', 'account', 'summary'])
                      ChoiceChip(
                        label: Text(switch (k) {
                          null => 'All',
                          'discovery' => 'Discovery',
                          'inbox' => 'Inbox',
                          'publish' => 'Publishing',
                          'summary' => 'Weekly',
                          _ => 'Accounts',
                        }),
                        selected: _kind == k,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _kind = k),
                      ),
                  ],
                ),
              ),
              if (all.any((a) => !a.read))
                TextButton.icon(
                  onPressed: () => guarded(context, () => ref.hub((h) => h.markAlertsRead())),
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('Mark all read'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (list.isEmpty)
            const Big(
              icon: Icons.notifications_off_outlined,
              title: 'No alerts',
              message:
                  'Discovery watches and inbox rules raise alerts here and on your phone. Describe what you are '
                  'looking for under Discovery to start.',
            ),
          for (final (i, a) in list.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Stagger(i, child: AlertCard(alert: a)),
            ),
        ],
      );
    },
  );
}

class AlertCard extends ConsumerWidget {
  const AlertCard({super.key, required this.alert});
  final Alert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = alert;
    final t = Theme.of(context).textTheme;
    final tone = Tone.of(context);
    final pictured = a.kind == 'discovery' || a.image != null;
    return Panel(
      padding: const EdgeInsets.all(14),
      onTap: () {
        if (!a.read) ref.hub((h) => h.markAlertsRead([a.id])).ignore();
        if (a.url != null) openLink(context, a.url!);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pictured)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox.square(
                dimension: 96,
                child: Artwork(url: a.image, seed: a.id),
              ),
            )
          else
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: tone.cardHigh, borderRadius: BorderRadius.circular(16)),
              child: Icon(alertIcon(a.kind), color: a.read ? tone.muted : signal),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.title,
                        style: t.titleMedium?.copyWith(
                          fontWeight: a.read ? FontWeight.w500 : FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(ago(a.at), style: t.bodySmall),
                    if (!a.read)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: signal, shape: BoxShape.circle),
                      ),
                  ],
                ),
                if (a.body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(a.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.bodyMedium),
                ],
                if (a.score != null || a.reason != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (a.score != null)
                        Tag(
                          '${(a.score! * 100).round()}% match',
                          color: a.score! >= 0.7 ? growth : const Color(0xFFF59E0B),
                          icon: Icons.auto_awesome_rounded,
                        ),
                      if (a.reason != null)
                        Text(a.reason!, style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- discovery ----

class _Discovery extends ConsumerStatefulWidget {
  const _Discovery();

  @override
  ConsumerState<_Discovery> createState() => _DiscoveryState();
}

class _DiscoveryState extends ConsumerState<_Discovery> {
  final _describe = TextEditingController();
  final _postcode = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _describe.dispose();
    _postcode.dispose();
    super.dispose();
  }

  Future<void> _save(List<DiscoveryWatch> all, DiscoveryWatch w) async {
    final next = [for (final x in all) x.id == w.id ? w : x];
    if (!all.any((x) => x.id == w.id)) next.add(w);
    if (await guarded(context, () => ref.hub((h) => h.saveDiscovery(next))) && mounted) {
      showMessage(context, 'Watch saved. The hub checks it every ${w.everyMinutes} minutes.');
    }
  }

  Future<void> _draft(List<DiscoveryWatch> all) async {
    final text = _describe.text.trim();
    if (text.isEmpty) return showMessage(context, 'Describe what you want first.');
    setState(() => _busy = true);
    DiscoveryWatch? draft;
    await guarded(context, () async {
      draft = await ref.hub(
        (h) =>
            h.suggestDiscovery(text, postcode: _postcode.text.trim().isEmpty ? null : _postcode.text.trim()),
        refresh: false,
      );
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (draft == null) return;
    final d = draft!.id.isEmpty ? draft!.copyWith(id: newId()) : draft!;
    final saved = await editWatch(context, d);
    if (saved != null && mounted) {
      _describe.clear();
      await _save(all, saved);
    }
  }

  Future<void> _run(DiscoveryWatch w) async {
    DiscoveryRun? r;
    final ok = await guarded(context, () async => r = await ref.hub((h) => h.runDiscovery(w.id)));
    final run = r;
    if (!ok || !mounted || run == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _Finds(watch: w, run: run),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tone = Tone.of(context);
    return HubView(
      ref.watch(discoveryProvider),
      builder: (all) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cardRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [signal.withValues(alpha: 0.22), tone.card, tone.card],
              ),
              border: Border.all(color: tone.stroke),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: signal),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Hint(
                        'alerts.describe',
                        child: Text('Describe what you want', style: t.titleLarge),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'AI turns it into a watch over eBay and DoneDeal listings, Instagram hashtags and business '
                  'accounts, Bluesky and YouTube. You check it before it is saved.',
                  style: t.bodyMedium?.copyWith(color: tone.muted),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _describe,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'What are you looking for?',
                    hintText:
                        'A Toyota Yaris or Honda Jazz, automatic, under £6,000, within 40 km of Enniskillen. '
                        'Or: Instagram shops selling handmade ceramic mugs.',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _postcode,
                    decoration: const InputDecoration(
                      labelText: 'Postcode (optional)',
                      hintText: 'BT74 7AA',
                      prefixIcon: Icon(Icons.place_outlined, size: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    AiButton(label: 'Draft a watch', filled: true, busy: _busy, onPressed: () => _draft(all)),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final w = await editWatch(context, DiscoveryWatch(id: newId(), name: ''));
                        if (w != null && mounted) await _save(all, w);
                      },
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Set up by hand'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (final (i, w) in all.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Stagger(
                i,
                child: _WatchCard(
                  watch: w,
                  onRun: () => _run(w),
                  onPause: (paused) => _save(all, w.copyWith(paused: paused)),
                  onEdit: () async {
                    final e = await editWatch(context, w);
                    if (e != null && mounted) await _save(all, e);
                  },
                  onDelete: () async {
                    if (!await confirm(
                      context,
                      title: 'Delete "${w.name}"?',
                      message: 'Its alerts stay.',
                      action: 'Delete',
                      destructive: true,
                    )) {
                      return;
                    }
                    if (!context.mounted) return;
                    await guarded(
                      context,
                      () => ref.hub(
                        (h) => h.saveDiscovery([
                          for (final x in all)
                            if (x.id != w.id) x,
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WatchCard extends StatelessWidget {
  const _WatchCard({
    required this.watch,
    required this.onRun,
    required this.onPause,
    required this.onEdit,
    required this.onDelete,
  });
  final DiscoveryWatch watch;
  final VoidCallback onRun, onEdit, onDelete;
  final ValueChanged<bool> onPause;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final w = watch;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (w.paused ? Tone.of(context).muted : signal).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.travel_explore_rounded, color: w.paused ? Tone.of(context).muted : signal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.name.ifEmpty('Untitled watch'), style: t.titleMedium),
                    Text(w.paused ? 'Paused' : 'Every ${_every(w.everyMinutes)}', style: t.bodySmall),
                  ],
                ),
              ),
              Tooltip(
                message: w.paused ? 'Resume' : 'Pause',
                child: Switch(value: !w.paused, onChanged: (on) => onPause(!on)),
              ),
            ],
          ),
          if (w.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(w.description, style: t.bodyMedium),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in w.sources) Tag(DiscoverySource.label(s.type), icon: _sourceIcon(s.type)),
              for (final k in w.keywords) Tag(k, color: const Color(0xFF3B82F6)),
              if (w.ai) const Tag('AI match', color: growth, icon: Icons.auto_awesome_rounded),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              Hint(
                'alerts.run',
                child: TextButton.icon(
                  onPressed: onRun,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Run now'),
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _every(int minutes) => switch (minutes) {
  < 60 => '$minutes minutes',
  60 => 'hour',
  < 1440 => '${minutes ~/ 60} hours',
  1440 => 'day',
  _ => '${minutes ~/ 1440} days',
};

IconData _sourceIcon(String type) => switch (type) {
  'ebay' || 'donedeal' => Icons.sell_outlined,
  'instagram_hashtag' => Icons.tag_rounded,
  'instagram_business' => Icons.storefront_outlined,
  'youtube' => Icons.smart_display_outlined,
  _ => Icons.public_rounded,
};

class _Finds extends StatelessWidget {
  const _Finds({required this.watch, required this.run});
  final DiscoveryWatch watch;
  final DiscoveryRun run;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (:finds, alerts: news, :errors) = run;
    final alerts = news.length;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(watch.name, style: t.titleLarge),
          Text(
            '${finds.length} found, $alerts new ${alerts == 1 ? 'alert' : 'alerts'}',
            style: t.bodyMedium?.copyWith(color: Tone.of(context).muted),
          ),
          const SizedBox(height: 14),
          if (errors.isNotEmpty) ...[
            WarningBox('Some sources failed:\n${errors.join('\n')}'),
            const SizedBox(height: 12),
          ],
          if (finds.isEmpty) const Text('Nothing matched this time.'),
          for (final f in finds)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: const EdgeInsets.all(12),
                onTap: f.url.isEmpty ? null : () => openLink(context, f.url),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox.square(
                        dimension: 64,
                        child: Artwork(url: f.image, seed: f.id),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.title, style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                          Text(
                            [
                              DiscoverySource.label(f.source),
                              if (f.location != null) f.location!,
                            ].join(' · '),
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (f.price != null)
                      Text(
                        '${f.currency == 'EUR' ? '€' : (f.currency == 'GBP' || f.currency == null ? '£' : '${f.currency} ')}'
                        '${f.price!.toStringAsFixed(f.price! % 1 == 0 ? 0 : 2)}',
                        style: t.titleMedium?.copyWith(color: growth),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens the watch editor; returns the edited watch, or null.
Future<DiscoveryWatch?> editWatch(BuildContext context, DiscoveryWatch w) => Navigator.of(context)
    .push(MaterialPageRoute<DiscoveryWatch>(fullscreenDialog: true, builder: (_) => WatchEditor(watch: w)));

/// A discovery watch's name, description, keywords, schedule and sources,
/// each source with the fields its type takes.
class WatchEditor extends ConsumerStatefulWidget {
  const WatchEditor({super.key, required this.watch});
  final DiscoveryWatch watch;

  @override
  ConsumerState<WatchEditor> createState() => _WatchEditorState();
}

class _WatchEditorState extends ConsumerState<WatchEditor> {
  late final _name = TextEditingController(text: widget.watch.name);
  late final _description = TextEditingController(text: widget.watch.description);
  late final _keywords = TextEditingController(text: widget.watch.keywords.join(', '));
  late var _ai = widget.watch.ai;
  late var _every = widget.watch.everyMinutes;
  late final _sources = [
    for (final s in widget.watch.sources) DiscoverySource(s.type, {...s.data}),
  ];
  String? _error;

  static const _schedules = {
    10: 'Every 10 minutes',
    15: 'Every 15 minutes',
    30: 'Every 30 minutes',
    60: 'Every hour',
    180: 'Every 3 hours',
    360: 'Every 6 hours',
    1440: 'Once a day',
  };

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _keywords.dispose();
    super.dispose();
  }

  void _save() {
    final problems = [
      if (_name.text.trim().isEmpty) 'Give the watch a name.',
      if (_sources.isEmpty) 'Add at least one source.',
      for (final s in _sources) ?s.problem(),
      if (_every < 10) 'Run at most every 10 minutes.',
    ];
    if (problems.isNotEmpty) return setState(() => _error = problems.join('\n'));
    Navigator.pop(
      context,
      DiscoveryWatch(
        id: widget.watch.id,
        name: _name.text.trim(),
        description: _description.text.trim(),
        sources: _sources,
        keywords: splitList(_keywords.text),
        ai: _ai,
        everyMinutes: _every,
        paused: widget.watch.paused,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.watch.name.isEmpty ? 'New watch' : 'Edit watch'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: _save, child: const Text('Save')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 12),
                  ],
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Field(_name, 'Name', hint: 'Small automatic cars near me'),
                        Field(_description, 'What you are looking for', lines: 3),
                        Field(
                          _keywords,
                          'Keywords',
                          hint: 'Any of these, comma separated',
                          helper: 'Optional; a find must contain every keyword.',
                        ),
                        Choice<int>(
                          label: 'How often',
                          value: _every,
                          options: _schedules,
                          onChanged: (v) => setState(() => _every = v),
                        ),
                        Hint(
                          'alerts.ai',
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _ai,
                            onChanged: (v) => setState(() => _ai = v),
                            title: const Text('AI checks each find'),
                            subtitle: const Text('Alerts only on finds that match the description.'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: Text('Sources', style: t.titleMedium)),
                      PopupMenuButton<String>(
                        tooltip: 'Add source',
                        onSelected: (type) => setState(() => _sources.add(DiscoverySource(type, {}))),
                        itemBuilder: (_) => [
                          for (final type in DiscoverySource.types)
                            PopupMenuItem(
                              value: type,
                              child: ListTile(
                                leading: Icon(_sourceIcon(type)),
                                title: Text(DiscoverySource.label(type)),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                        ],
                        child: const Chip(
                          avatar: Icon(Icons.add_rounded, size: 18),
                          label: Text('Add source'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_sources.isEmpty)
                    Text(
                      'Facebook Marketplace has no API and Meta forbids scraping it, so car hunts use eBay and '
                      'DoneDeal listings instead.',
                      style: t.bodySmall,
                    ),
                  for (final (i, s) in _sources.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SourceEditor(
                        key: ObjectKey(s),
                        source: s,
                        accounts: accounts,
                        onRemove: () => setState(() => _sources.removeAt(i)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceEditor extends StatefulWidget {
  const _SourceEditor({super.key, required this.source, required this.accounts, required this.onRemove});
  final DiscoverySource source;
  final List<Account> accounts;
  final VoidCallback onRemove;

  @override
  State<_SourceEditor> createState() => _SourceEditorState();
}

class _SourceEditorState extends State<_SourceEditor> {
  final _controllers = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctl(SourceField f) => _controllers.putIfAbsent(f.key, () {
    final v = widget.source.data[f.key];
    final c = TextEditingController(text: v is List ? v.join(', ') : (v == null ? '' : '$v'));
    c.addListener(() {
      final text = c.text.trim();
      widget.source.data[f.key] = switch (f.kind) {
        'number' => num.tryParse(text),
        'list' => [for (final s in splitList(text)) s.replaceFirst(RegExp('^[#@]'), '')],
        _ => text,
      };
    });
    return c;
  });

  @override
  Widget build(BuildContext context) {
    final s = widget.source;
    final t = Theme.of(context).textTheme;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_sourceIcon(s.type), color: signal),
              const SizedBox(width: 10),
              Expanded(child: Text(DiscoverySource.label(s.type), style: t.titleSmall)),
              IconButton(
                tooltip: 'Remove source',
                onPressed: widget.onRemove,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final f in DiscoverySource.fields(s.type))
            if (f.kind.startsWith('account:'))
              Builder(
                builder: (context) {
                  final platform = f.kind.substring(8);
                  final options = {
                    for (final a in widget.accounts)
                      if (a.platform.name == platform) a.id: a.name,
                  };
                  if (options.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Connect a ${Platform.parse(platform).label} account first; searches run as it.',
                        style: t.bodySmall?.copyWith(color: signal),
                      ),
                    );
                  }
                  final current = str(s.data[f.key]);
                  if (!options.containsKey(current)) s.data[f.key] = options.keys.first;
                  return Choice<String>(
                    label: f.label,
                    value: str(s.data[f.key]),
                    options: options,
                    onChanged: (v) => setState(() => s.data[f.key] = v),
                  );
                },
              )
            else
              Field(
                _ctl(f),
                f.required ? f.label : '${f.label} (optional)',
                hint: f.hint.isEmpty ? null : f.hint,
                number: f.kind == 'number',
              ),
        ],
      ),
    );
  }
}

// ---- rules ----

class _Rules extends ConsumerWidget {
  const _Rules();

  Future<void> _save(BuildContext context, WidgetRef ref, List<InboxRule> rules) async {
    if (await guarded(context, () => ref.hub((h) => h.saveRules(rules))) && context.mounted) {
      showMessage(context, 'Rules saved.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    return HubView(
      ref.watch(rulesProvider),
      builder: (rules) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rules act on each new comment or message: alert you, label it, or reply for you.',
                  style: t.bodyMedium?.copyWith(color: Tone.of(context).muted),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () async {
                  final r = await editRule(context, InboxRule(id: newId(), name: ''), accounts);
                  if (r != null && context.mounted) await _save(context, ref, [...rules, r]);
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New rule'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (rules.isEmpty)
            const Big(
              icon: Icons.rule_rounded,
              title: 'No rules yet',
              message:
                  'Example: alert me when someone "asks about price or availability", and reply "Hi {name}, '
                  'sending you the details now!" in private.',
            ),
          for (final (i, r) in rules.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Stagger(
                i,
                child: Panel(
                  onTap: () async {
                    final e = await editRule(context, r, accounts);
                    if (e != null && context.mounted) {
                      await _save(context, ref, [for (final x in rules) x.id == r.id ? e : x]);
                    }
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.name.ifEmpty('Untitled rule'), style: t.titleMedium),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final k in r.keywords) Tag(k, color: const Color(0xFF3B82F6)),
                                if (r.description != null)
                                  Tag(r.description!, color: growth, icon: Icons.auto_awesome_rounded),
                                if (r.alert) const Tag('Alert', icon: Icons.notifications_active_outlined),
                                if (r.reply != null) const Tag('Auto-reply', icon: Icons.reply_rounded),
                                if (r.privateReply != null)
                                  const Tag('Private reply', icon: Icons.lock_outline_rounded),
                                Tag(
                                  r.accountIds == null ? 'All accounts' : '${r.accountIds!.length} accounts',
                                  icon: Icons.people_outline_rounded,
                                ),
                              ],
                            ),
                            if (r.reply != null) ...[
                              const SizedBox(height: 8),
                              Text('"${r.reply}"', style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Switch(
                            value: r.enabled,
                            onChanged: (on) => _save(context, ref, [
                              for (final x in rules) x.id == r.id ? x.copyWith(enabled: on) : x,
                            ]),
                          ),
                          IconButton(
                            tooltip: 'Delete rule',
                            onPressed: () => _save(context, ref, [
                              for (final x in rules)
                                if (x.id != r.id) x,
                            ]),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The rule editor; returns the edited rule, or null.
Future<InboxRule?> editRule(BuildContext context, InboxRule r, List<Account> accounts) async {
  final name = TextEditingController(text: r.name);
  final keywords = TextEditingController(text: r.keywords.join(', '));
  final description = TextEditingController(text: r.description ?? '');
  final reply = TextEditingController(text: r.reply ?? '');
  final privateReply = TextEditingController(text: r.privateReply ?? '');
  var alert = r.alert;
  Set<String>? only = r.accountIds?.toSet();
  InboxRule? out;
  await showFormDialog(
    context,
    title: r.name.isEmpty ? 'New rule' : 'Edit rule',
    fields: (setState) => [
      Field(name, 'Name', hint: 'Price questions'),
      Field(keywords, 'Keywords', hint: 'price, how much, available', helper: 'Matches any of them.'),
      Hint(
        'rules.description',
        child: Field(
          description,
          'Or describe it (AI judges)',
          hint: 'asks about price or availability',
          lines: 2,
        ),
      ),
      Field(
        reply,
        'Public reply (optional)',
        hint: 'Hi {name}, check your DMs!',
        helper: '{name} becomes their first name.',
        lines: 2,
      ),
      Field(privateReply, 'Private reply (optional)', hint: 'Instagram and Facebook comments only', lines: 2),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: alert,
        onChanged: (v) => setState(() => alert = v),
        title: const Text('Alert me'),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: only == null,
        onChanged: (all) => setState(() => only = all ? null : {}),
        title: const Text('Every account'),
      ),
      if (only != null)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final a in accounts)
              FilterChip(
                avatar: PlatformBadge(a.platform, size: 20),
                label: Text(a.name),
                selected: only!.contains(a.id),
                onSelected: (on) => setState(() => on ? only!.add(a.id) : only!.remove(a.id)),
              ),
          ],
        ),
      const SizedBox(height: 12),
    ],
    onSave: () async {
      if (name.text.trim().isEmpty) return 'Give the rule a name.';
      if (keywords.text.trim().isEmpty && description.text.trim().isEmpty) {
        return 'Add keywords or describe what to look for.';
      }
      if (only != null && only!.isEmpty) return 'Pick at least one account, or switch on every account.';
      out = InboxRule(
        id: r.id,
        name: name.text.trim(),
        enabled: r.enabled,
        accountIds: only?.toList(),
        keywords: splitList(keywords.text),
        description: description.text.trim().isEmpty ? null : description.text.trim(),
        reply: reply.text.trim().isEmpty ? null : reply.text.trim(),
        privateReply: privateReply.text.trim().isEmpty ? null : privateReply.text.trim(),
        alert: alert,
      );
      return null;
    },
  );
  return out;
}
