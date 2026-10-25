import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/providers.dart';
import '../domain/hub.dart';
import '../domain/models.dart';
import 'common.dart';
import 'look.dart';

/// Opens the composer: blank, prefilled with [text] or [accountIds], at a
/// calendar slot [at], or editing [post].
Future<void> openCompose(
  BuildContext context, {
  Post? post,
  String? text,
  List<String>? accountIds,
  DateTime? at,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => ComposePage(post: post, text: text, accountIds: accountIds, at: at),
  ),
);

enum When {
  now('Now', Icons.send_rounded, 'Post now'),
  schedule('Schedule', Icons.event_rounded, 'Schedule'),
  queue('Queue', Icons.playlist_add_rounded, 'Add to queue'),
  draft('Draft', Icons.edit_note_rounded, 'Save draft');

  const When(this.label, this.icon, this.action);
  final String label, action;
  final IconData icon;
}

const _recycleOptions = {
  0: 'Off',
  7: 'Every week',
  14: 'Every 2 weeks',
  30: 'Every month',
  90: 'Every 3 months',
};

/// The composer: one text for every chosen account with per-account
/// wording, formats, YouTube titles and first comments; media uploaded to
/// the hub in parts; live length counters from each platform's limits; and
/// post now, schedule, queue or draft. A live preview sits alongside on
/// wide screens.
class ComposePage extends ConsumerStatefulWidget {
  const ComposePage({super.key, this.post, this.text, this.accountIds, this.at});
  final Post? post;
  final String? text;
  final List<String>? accountIds;
  final DateTime? at;

  @override
  ConsumerState<ComposePage> createState() => _ComposePageState();
}

class _Upload {
  _Upload(this.name);
  final String name;
  double progress = 0;
}

class _ComposePageState extends ConsumerState<ComposePage> {
  final _text = TextEditingController();
  final _firstComment = TextEditingController();
  final _tags = TextEditingController();
  final _selected = <String>[];
  final _format = <String, String>{};
  final _overrides = <String, TextEditingController>{};
  final _titles = <String, TextEditingController>{};
  final _comments = <String, TextEditingController>{};
  final _mediaIds = <String>[];
  final _known = <String, MediaItem>{};
  final _uploads = <_Upload>[];
  var _hashtags = <String>[];
  var _custom = false;
  var _when = When.now;
  late DateTime _at;
  var _recycle = 0;
  var _busy = false;

  bool get _editing => widget.post != null;

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    final next = DateTime.now().add(const Duration(hours: 1));
    _at = widget.at ?? DateTime(next.year, next.month, next.day, next.hour);
    if (p != null) {
      _text.text = p.text;
      _mediaIds.addAll(p.media);
      _tags.text = p.tags.join(', ');
      _recycle = p.recycleDays ?? 0;
      _when = p.status == 'draft' ? When.draft : When.schedule;
      _at = localTime(p.scheduledAt) ?? _at;
      for (final t in p.targets) {
        _selected.add(t.accountId);
        _format[t.accountId] = t.format;
        if (t.text != null) {
          _custom = true;
          _ctl(_overrides, t.accountId).text = t.text!;
        }
        if (t.title != null) _ctl(_titles, t.accountId).text = t.title!;
        if (t.firstComment != null) _ctl(_comments, t.accountId).text = t.firstComment!;
      }
      if (_comments.length == p.targets.length && _comments.values.map((c) => c.text).toSet().length == 1) {
        _firstComment.text = _comments.values.first.text;
        _comments.clear();
      }
    } else {
      _text.text = widget.text ?? '';
      _selected.addAll(widget.accountIds ?? const []);
      if (widget.at != null) _when = When.schedule;
    }
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [
      _text,
      _firstComment,
      _tags,
      ..._overrides.values,
      ..._titles.values,
      ..._comments.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctl(Map<String, TextEditingController> m, String id) => m.putIfAbsent(id, () {
    final c = TextEditingController();
    c.addListener(() => setState(() {}));
    return c;
  });

  String _textFor(String id) {
    final o = _overrides[id]?.text ?? '';
    return _custom && o.trim().isNotEmpty ? o : _text.text;
  }

  List<Account> _chosen(List<Account> all) => [
    for (final id in _selected) ?all.where((a) => a.id == id).firstOrNull,
  ];

  String _formatOf(Account a, HubMeta meta) {
    final formats = meta.info(a.platform).formats;
    final f = _format[a.id];
    return f != null && (formats.isEmpty || formats.contains(f)) ? f : (formats.firstOrNull ?? 'post');
  }

  /// What would stop this post going out, worded for the user.
  List<String> _problems(List<Account> chosen, HubMeta meta) {
    final out = <String>[];
    if (chosen.isEmpty) out.add('Choose at least one account.');
    if (_text.text.trim().isEmpty && _mediaIds.isEmpty && !_custom) out.add('Write something or add media.');
    if (_uploads.isNotEmpty) out.add('Wait for the uploads to finish.');
    for (final a in chosen) {
      final info = meta.info(a.platform);
      final len = _textFor(a.id).characters.length;
      if (len > info.maxText) out.add('${a.platform.label}: ${len - info.maxText} characters too long.');
      final f = _formatOf(a, meta);
      if (info.mediaRequired.contains(f) && _mediaIds.isEmpty) {
        out.add('${a.platform.label} ${formatLabel(f).toLowerCase()} needs a photo or video.');
      }
      if (_mediaIds.length > info.maxMedia) {
        out.add('${a.platform.label} takes at most ${info.maxMedia} media files.');
      }
      if (a.platform == Platform.youtube && (_titles[a.id]?.text.trim() ?? '').isEmpty) {
        out.add('YouTube needs a title.');
      }
      if (!a.can('publish')) out.add('${a.name} cannot publish (see Accounts).');
    }
    if (_when == When.schedule && _at.isBefore(DateTime.now())) out.add('Pick a time in the future.');
    return out;
  }

  Future<void> _submit(List<Account> chosen, HubMeta meta) async {
    final problems = _problems(chosen, meta);
    if (problems.isNotEmpty) {
      showError(context, HubException('Not ready yet', problems: problems));
      return;
    }
    final input = PostInput(
      text: _text.text.trim(),
      media: _mediaIds,
      targets: [
        for (final a in chosen)
          Target(
            accountId: a.id,
            format: _formatOf(a, meta),
            text: _custom ? _overrides[a.id]?.text.trim() : null,
            title: a.platform == Platform.youtube ? _titles[a.id]?.text.trim() : null,
            firstComment:
                (_custom ? _comments[a.id]?.text.trim() : null).nullIfEmpty ??
                _firstComment.text.trim().nullIfEmpty,
          ),
      ],
      scheduledAt: _when == When.schedule ? hubTime(_at) : null,
      queue: _when == When.queue,
      draft: _when == When.draft,
      recycleDays: _recycle == 0 ? null : _recycle,
      tags: [for (final t in splitList(_tags.text)) t.replaceFirst('#', '')],
    );
    setState(() => _busy = true);
    Post? saved;
    final ok = await guarded(context, () async {
      saved = await ref.hub((h) => _editing ? h.updatePost(widget.post!.id, input) : h.createPost(input));
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    final message = switch (_when) {
      When.now => 'Posting within a minute.',
      When.schedule => 'Scheduled for ${whenLabel(saved?.scheduledAt ?? hubTime(_at))}.',
      When.queue => 'Queued for ${whenLabel(saved?.scheduledAt)}.',
      When.draft => 'Draft saved.',
    };
    Navigator.pop(context);
    showMessage(context, message);
  }

  Future<void> _pickMedia() async {
    final files = await FilePicker.pickFiles(dialogTitle: 'Add photos or videos', type: FileType.media);
    for (final f in files) {
      if (!mounted) return;
      final up = _Upload(f.name);
      setState(() => _uploads.add(up));
      final ok = await guarded(context, () async {
        void progress(double p) => mounted ? setState(() => up.progress = p) : null;
        final path = f.path;
        final item = await ref.hub(
          (h) async => path != null
              ? h.uploadFile(File(path), onProgress: progress)
              : h.uploadBytes(f.name, contentTypeFor(f.name), await f.readAsBytes(), onProgress: progress),
        );
        _known[item.id] = item;
        _mediaIds.add(item.id);
      });
      if (!mounted) return;
      setState(() => _uploads.remove(up));
      if (!ok) break;
    }
  }

  Future<void> _library() async {
    final picked = await showModalBottomSheet<MediaItem>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _Library(),
    );
    if (picked != null && !_mediaIds.contains(picked.id)) {
      setState(() {
        _known[picked.id] = picked;
        _mediaIds.add(picked.id);
      });
    }
  }

  Future<void> _ai(List<Account> chosen) async {
    final brief = TextEditingController(text: _text.text);
    var tone = 'friendly';
    final platforms = {for (final a in chosen) a.platform}.toList();
    if (platforms.isEmpty) return showMessage(context, 'Choose the accounts first.');
    CaptionResult? result;
    await showFormDialog(
      context,
      title: 'Write with AI',
      action: 'Draft captions',
      fields: (setState) => [
        Field(
          brief,
          'What is the post about?',
          lines: 4,
          hint: 'New autumn menu, launches Friday, 20% off for the first week',
        ),
        Choice<String>(
          label: 'Tone',
          value: tone,
          options: const {
            'friendly': 'Friendly',
            'professional': 'Professional',
            'playful': 'Playful',
            'bold': 'Bold and punchy',
          },
          onChanged: (v) => tone = v,
        ),
        Text(
          'Drafts one caption per platform (${platforms.map((p) => p.label).join(', ')}) using the AI '
          'you set up in Settings.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      onSave: () async {
        if (brief.text.trim().isEmpty) return 'Describe the post first.';
        result = await ref.hub((h) => h.caption(brief.text.trim(), platforms, tone: tone), refresh: false);
        return null;
      },
    );
    final r = result;
    if (r == null || !mounted) return;
    setState(() {
      final variants = r.variants.values.toSet();
      if (variants.isNotEmpty) _text.text = r.variants[platforms.first] ?? variants.first;
      if (variants.length > 1) {
        _custom = true;
        for (final a in chosen) {
          final v = r.variants[a.platform];
          if (v != null) _ctl(_overrides, a.id).text = v;
        }
      }
      _hashtags = r.hashtags;
    });
  }

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
    if (time == null) return;
    setState(() {
      _at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _when = When.schedule;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final meta = ref.watch(metaProvider).value ?? const HubMeta();
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit post' : 'Create post'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: HubView(
        accounts,
        builder: (all) {
          final chosen = _chosen(all);
          final problems = _problems(chosen, meta);
          final editor = _editor(all, chosen, meta);
          return Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    if (box.maxWidth < 980) return editor;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: editor),
                        SizedBox(
                          width: 400,
                          child: _Previews(
                            accounts: chosen,
                            textFor: _textFor,
                            media: [for (final id in _mediaIds) ?_known[id] ?? _lookup(id)],
                            formatOf: (a) => _formatOf(a, meta),
                            titleOf: (a) => _titles[a.id]?.text ?? '',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              _SubmitBar(when: _when, problems: problems, busy: _busy, onSubmit: () => _submit(chosen, meta)),
            ],
          );
        },
      ),
    );
  }

  MediaItem? _lookup(String id) => ref.watch(mediaProvider).value?.where((m) => m.id == id).firstOrNull;

  Widget _editor(List<Account> all, List<Account> chosen, HubMeta meta) {
    final t = Theme.of(context).textTheme;
    final tone = Tone.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final best = ref.watch(statsProvider).value?.bestSlot;
    return ListView(
      padding: EdgeInsets.fromLTRB(narrow ? 16 : 28, 4, narrow ? 16 : 20, 24),
      children: [
        Stagger(
          0,
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('Post to'),
                if (all.isEmpty)
                  Text(
                    'Connect an account first (Accounts).',
                    style: t.bodyMedium?.copyWith(color: tone.muted),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final a in all)
                        _AccountChip(
                          account: a,
                          selected: _selected.contains(a.id),
                          onTap: () => setState(
                            () => _selected.contains(a.id) ? _selected.remove(a.id) : _selected.add(a.id),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Stagger(
          1,
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Text', style: t.titleMedium)),
                    Hint(
                      'compose.ai',
                      child: AiButton(label: 'Write with AI', onPressed: () => _ai(chosen)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _text,
                  minLines: 5,
                  maxLines: 14,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText: 'What do you want to share?',
                    labelText: 'Post text',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in {for (final a in chosen) a.platform})
                      _Counter(platform: p, length: _text.text.characters.length, max: meta.info(p).maxText),
                  ],
                ),
                if (_hashtags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final h in _hashtags)
                        ActionChip(
                          label: Text(h.startsWith('#') ? h : '#$h'),
                          onPressed: () => setState(
                            () => _text.text = '${_text.text.trimRight()} ${h.startsWith('#') ? h : '#$h'}',
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Hint(
                  'compose.firstComment',
                  child: Field(
                    _firstComment,
                    'First comment (optional)',
                    hint: 'Hashtags or a link',
                    lines: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Stagger(2, child: _mediaPanel()),
        if (chosen.isNotEmpty) ...[
          const SizedBox(height: 16),
          Stagger(
            3,
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Per account', style: t.titleMedium)),
                      Hint(
                        'compose.custom',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Custom text', style: t.bodyMedium),
                            const SizedBox(width: 8),
                            Switch(value: _custom, onChanged: (v) => setState(() => _custom = v)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final a in chosen) _perAccount(a, meta),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Stagger(
          4,
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('When'),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<When>(
                    segments: [
                      for (final w in When.values)
                        ButtonSegment(value: w, label: Text(w.label), icon: Icon(w.icon, size: 18)),
                    ],
                    selected: {_when},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _when = s.first),
                  ),
                ),
                const SizedBox(height: 14),
                AnimatedSize(
                  duration: Motion.medium,
                  curve: Curves.easeOutCubic,
                  child: switch (_when) {
                    When.schedule => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.event_rounded, size: 18),
                          label: Text(DateFormat('EEE d MMM y, HH:mm').format(_at)),
                        ),
                        for (final (label, at) in _quickTimes(best))
                          ActionChip(label: Text(label), onPressed: () => setState(() => _at = at)),
                      ],
                    ),
                    When.queue => Hint(
                      'compose.queue',
                      child: Text(
                        'Goes out in the next free slot of your posting queue.',
                        style: t.bodyMedium?.copyWith(color: tone.muted),
                      ),
                    ),
                    When.now => Text(
                      'Goes out within a minute.',
                      style: t.bodyMedium?.copyWith(color: tone.muted),
                    ),
                    When.draft => Text(
                      'Kept unscheduled; find it in Calendar > Drafts.',
                      style: t.bodyMedium?.copyWith(color: tone.muted),
                    ),
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Hint(
                        'compose.recycle',
                        child: Choice<int>(
                          label: 'Post again',
                          value: _recycle,
                          options: _recycleOptions,
                          onChanged: (v) => setState(() => _recycle = v),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Field(_tags, 'Tags', hint: 'launch, autumn')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Tonight, tomorrow morning, and the best time from the stats.
  List<(String, DateTime)> _quickTimes(BestTime? best) {
    final now = DateTime.now();
    final tonight = DateTime(now.year, now.month, now.day, 19);
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 9);
    return [
      if (tonight.isAfter(now)) ('Tonight 19:00', tonight),
      ('Tomorrow 09:00', tomorrow),
      if (best != null) _bestNext(best, now),
    ];
  }

  (String, DateTime) _bestNext(BestTime b, DateTime now) {
    final utcNow = now.toUtc();
    var d = DateTime.utc(utcNow.year, utcNow.month, utcNow.day, b.hour);
    while (d.weekday - 1 != b.day || d.isBefore(utcNow)) {
      d = d.add(const Duration(days: 1));
    }
    final local = d.toLocal();
    return ('Best: ${DateFormat('EEE HH:mm').format(local)}', local);
  }

  Widget _perAccount(Account a, HubMeta meta) {
    final info = meta.info(a.platform);
    final t = Theme.of(context).textTheme;
    final formats = info.formats.isEmpty ? const ['post'] : info.formats;
    final f = _formatOf(a, meta);
    final overrideLen = _textFor(a.id).characters.length;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PlatformBadge(a.platform, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(a.name, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              _Counter(platform: a.platform, length: overrideLen, max: info.maxText, compact: true),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final x in formats)
                ChoiceChip(
                  label: Text(formatLabel(x)),
                  selected: x == f,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _format[a.id] = x),
                ),
            ],
          ),
          if (a.platform == Platform.youtube) ...[
            const SizedBox(height: 10),
            Field(_ctl(_titles, a.id), 'YouTube title', hint: 'Required by YouTube'),
          ],
          if (_custom) ...[
            const SizedBox(height: 10),
            Field(
              _ctl(_overrides, a.id),
              'Text for ${a.platform.label}',
              hint: 'Empty uses the main text',
              lines: 4,
            ),
            if (a.platform != Platform.telegram)
              Field(_ctl(_comments, a.id), 'First comment for ${a.platform.label}', lines: 2),
          ],
        ],
      ),
    );
  }

  /// Alt text for one file: typed, or drafted by Claude from the image and the post's text.
  Future<void> _editAlt(MediaItem m) async {
    final alt = TextEditingController(text: m.alt ?? '');
    var drafting = false;
    MediaItem? saved;
    await showFormDialog(
      context,
      title: 'Alt text',
      fields: (setState) => [
        const Text(
          'Describe the picture for people using screen readers. It goes out on Instagram, Facebook, Threads, '
          'Bluesky, Mastodon and LinkedIn.',
        ),
        const SizedBox(height: 16),
        Field(alt, 'Alt text', hint: 'A ginger cat asleep on a sunny windowsill', lines: 3, autofocus: true),
        if (m.isImage)
          Align(
            alignment: Alignment.centerLeft,
            child: AiButton(
              label: 'Describe',
              busy: drafting,
              onPressed: drafting
                  ? null
                  : () async {
                      setState(() => drafting = true);
                      final text = _text.text.trim();
                      await guarded(context, () async {
                        saved = await ref.hub((h) => h.describeMedia(m.id, context: text), refresh: false);
                        alt.text = saved!.alt ?? '';
                      });
                      setState(() => drafting = false);
                    },
            ),
          ),
      ],
      onSave: () async {
        saved = await ref.hub((h) => h.setAlt(m.id, alt.text.trim()));
        return null;
      },
    );
    alt.dispose();
    if (saved != null && mounted) setState(() => _known[m.id] = saved!);
  }

  Widget _mediaPanel() {
    final t = Theme.of(context).textTheme;
    final items = [for (final id in _mediaIds) (id, _known[id] ?? _lookup(id))];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Media', style: t.titleMedium)),
              TextButton.icon(
                onPressed: _library,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Library'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 112,
            child: ReorderableListView(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: true,
              onReorderItem: (from, to) => setState(() => _mediaIds.insert(to, _mediaIds.removeAt(from))),
              footer: Row(
                children: [
                  for (final u in _uploads) _UploadTile(upload: u),
                  _AddTile(onTap: _pickMedia),
                ],
              ),
              children: [
                for (final (id, m) in items)
                  Padding(
                    key: ValueKey(id),
                    padding: const EdgeInsets.only(right: 10),
                    child: _MediaTile(
                      id: id,
                      media: m,
                      onRemove: () => setState(() => _mediaIds.remove(id)),
                      onAlt: m == null ? null : () => _editAlt(m),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on String? {
  String? get nullIfEmpty => this == null || this!.isEmpty ? null : this;
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.account, required this.selected, required this.onTap});
  final Account account;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
          decoration: BoxDecoration(
            color: selected ? signal.withValues(alpha: 0.14) : tone.cardHigh,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? signal : tone.stroke, width: selected ? 1.6 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlatformBadge(account.platform, size: 30),
              const SizedBox(width: 8),
              Text(account.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: selected
                    ? const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.check_circle_rounded, size: 18, color: signal),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "IG 140 / 2,200" with a ring that fills and turns red past the limit.
class _Counter extends StatelessWidget {
  const _Counter({required this.platform, required this.length, required this.max, this.compact = false});
  final Platform platform;
  final int length, max;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final over = length > max;
    final f = max == 0 ? 0.0 : (length / max).clamp(0.0, 1.0);
    final color = over ? signal : (f > 0.9 ? const Color(0xFFF59E0B) : growth);
    final fmt = NumberFormat.decimalPattern();
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
      decoration: BoxDecoration(
        color: over ? signal.withValues(alpha: 0.14) : Tone.of(context).cardHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 18,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: f),
              duration: Motion.short,
              builder: (context, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 2.6,
                color: color,
                backgroundColor: Tone.of(context).stroke,
              ),
            ),
          ),
          const SizedBox(width: 7),
          if (!compact) ...[
            Text(platform.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(width: 6),
          ],
          Text(
            over ? '-${fmt.format(length - max)}' : '${fmt.format(length)} / ${fmt.format(max)}',
            style: TextStyle(fontSize: 12, color: over ? signal : Tone.of(context).muted).merge(tabular),
          ),
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.id, required this.media, required this.onRemove, this.onAlt});
  final String id;
  final MediaItem? media;
  final VoidCallback onRemove;
  final VoidCallback? onAlt;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 112,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Artwork(url: media?.isImage ?? false ? media!.url : null, seed: id),
        ),
        if (media?.isVideo ?? false)
          const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 34)),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton.filled(
            tooltip: 'Remove',
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              minimumSize: const Size.square(28),
              padding: EdgeInsets.zero,
            ),
            iconSize: 16,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        if (onAlt != null)
          Positioned(
            left: 6,
            bottom: 6,
            child: Tooltip(
              message: (media?.alt ?? '').isEmpty ? 'Add alt text' : media!.alt!,
              child: Material(
                color: (media?.alt ?? '').isEmpty ? Colors.black54 : growth,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onAlt,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    child: Text(
                      'ALT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({required this.upload});
  final _Upload upload;

  @override
  Widget build(BuildContext context) => Container(
    width: 112,
    margin: const EdgeInsets.only(right: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Tone.of(context).cardHigh, borderRadius: BorderRadius.circular(18)),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox.square(
          dimension: 36,
          child: CircularProgressIndicator(
            value: upload.progress == 0 ? null : upload.progress,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          upload.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 112,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tone.stroke, width: 1.5),
          color: tone.cardHigh.withValues(alpha: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined, color: signal, size: 28),
            const SizedBox(height: 6),
            Text('Add media', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Media already on the hub, to reuse.
class _Library extends ConsumerWidget {
  const _Library();

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.7,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Media library', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Expanded(
            child: HubView(
              ref.watch(mediaProvider),
              builder: (items) => items.isEmpty
                  ? const Center(child: Text('Nothing uploaded yet.'))
                  : GridView.extent(
                      maxCrossAxisExtent: 140,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: [
                        for (final m in items.where((m) => m.status == 'ready'))
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.pop(context, m),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Artwork(url: m.isImage ? m.url : null, seed: m.id),
                                  if (m.isVideo)
                                    const Center(
                                      child: Icon(Icons.play_circle_fill_rounded, color: Colors.white),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.when, required this.problems, required this.busy, required this.onSubmit});
  final When when;
  final List<String> problems;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tone.card,
        border: Border(top: BorderSide(color: tone.stroke)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.short,
                  child: Text(
                    problems.isEmpty ? 'Ready.' : problems.first,
                    key: ValueKey(problems.firstOrNull),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: problems.isEmpty ? growth : tone.muted),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: busy ? null : onSubmit,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(when.icon, size: 18),
                label: Text(when.action),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How the post will look on each chosen account, roughly.
class _Previews extends StatelessWidget {
  const _Previews({
    required this.accounts,
    required this.textFor,
    required this.media,
    required this.formatOf,
    required this.titleOf,
  });
  final List<Account> accounts;
  final String Function(String id) textFor;
  final List<MediaItem> media;
  final String Function(Account) formatOf;
  final String Function(Account) titleOf;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tone = Tone.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 4, 28, 24),
      children: [
        Text('Preview', style: t.titleMedium),
        const SizedBox(height: 12),
        if (accounts.isEmpty)
          Panel(
            child: Text(
              'Choose accounts to see a preview.',
              style: t.bodyMedium?.copyWith(color: tone.muted),
            ),
          ),
        for (final (i, a) in accounts.take(4).indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Stagger(
              i,
              child: _Preview(
                account: a,
                text: textFor(a.id),
                media: media.firstOrNull,
                format: formatOf(a),
                title: titleOf(a),
              ),
            ),
          ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.account,
    required this.text,
    required this.format,
    required this.title,
    this.media,
  });
  final Account account;
  final String text, format, title;
  final MediaItem? media;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tall = format == 'reel' || format == 'story' || format == 'short';
    final wide = account.platform == Platform.youtube && !tall;
    final art = media == null && !tall
        ? null
        : ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: tall ? 9 / 12 : (wide ? 16 / 9 : 1),
              child: Artwork(
                url: media?.isImage ?? false ? media!.url : null,
                seed: media?.id ?? account.id,
                platform: account.platform,
              ),
            ),
          );
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(name: account.name, url: account.avatar, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      '${account.handle.isEmpty ? account.platform.label : account.handle} · ${formatLabel(format)}',
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              PlatformBadge(account.platform, size: 26),
            ],
          ),
          const SizedBox(height: 12),
          if (art != null &&
              account.platform != Platform.linkedin &&
              account.platform != Platform.bluesky) ...[
            art,
            const SizedBox(height: 10),
          ],
          if (title.isNotEmpty) Text(title, style: t.titleSmall),
          Text(
            text.ifEmpty('Your text appears here.'),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: t.bodyMedium?.copyWith(color: text.trim().isEmpty ? Tone.of(context).muted : null),
          ),
          if (art != null &&
              (account.platform == Platform.linkedin || account.platform == Platform.bluesky)) ...[
            const SizedBox(height: 10),
            art,
          ],
        ],
      ),
    );
  }
}
