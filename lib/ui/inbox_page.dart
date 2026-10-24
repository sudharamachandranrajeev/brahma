import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/models.dart';
import 'common.dart';
import 'look.dart';

/// Every comment, reply, DM, mention and live-chat message from every
/// account in one list. Each shows where it was said (a reel, a story, a
/// live); reply inline, in private where the platform allows, with Claude's
/// suggestions or a saved reply; mark done one by one or in bulk.
class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
  final _picked = <String>{};

  Future<void> _refresh() async {
    final ok = await guarded(context, () async {
      final n = await ref.hub((h) => h.refreshInbox());
      if (mounted) showMessage(context, n == 0 ? 'Nothing new.' : '$n new.');
    });
    if (!ok) return;
  }

  Future<void> _bulk(String status) async {
    final ids = _picked.toList();
    if (await guarded(context, () => ref.hub((h) => h.bulkInbox(ids, status))) && mounted) {
      setState(_picked.clear);
      showMessage(context, '${ids.length} marked $status.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(inboxProvider);
    final filter = ref.watch(inboxFilterProvider);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final byId = {for (final a in accounts) a.id: a};
    final platforms = {for (final a in accounts) a.platform}.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    void set(InboxFilter f) {
      _picked.clear();
      ref.read(inboxFilterProvider.notifier).set(f);
    }

    final counts = page.value?.counts;
    final ai = ref.watch(metaProvider).value?.ai ?? false;
    return RefreshIndicator(
      color: signal,
      onRefresh: _refresh,
      child: PageBody(
        maxWidth: 1000,
        children: [
          PageHeader(
            'Inbox',
            subtitle: counts == null
                ? 'Replies from every account'
                : '${counts.fresh} new · ${counts.read} read · ${counts.done} done',
            actions: [
              Hint(
                'inbox.refresh',
                child: OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Check now'),
                ),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'open', label: Text('Open')),
                    ButtonSegment(value: 'new', label: Text('New')),
                    ButtonSegment(value: 'done', label: Text('Done')),
                  ],
                  selected: {filter.status},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => set((
                    status: s.first,
                    platform: filter.platform,
                    kind: filter.kind,
                    triage: filter.triage,
                  )),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String?>(
                  tooltip: 'Kind',
                  initialValue: filter.kind,
                  onSelected: (k) =>
                      set((status: filter.status, platform: filter.platform, kind: k, triage: filter.triage)),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: null, child: Text('Every kind')),
                    for (final k in ['comment', 'reply', 'message', 'mention', 'live_chat'])
                      PopupMenuItem(value: k, child: Text(kindLabel(k))),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.filter_list_rounded, size: 18),
                    label: Text(filter.kind == null ? 'Every kind' : kindLabel(filter.kind!)),
                  ),
                ),
                if (ai) ...[
                  const SizedBox(width: 8),
                  Hint(
                    'inbox.triage',
                    child: PopupMenuButton<String?>(
                      tooltip: 'Mood',
                      initialValue: filter.triage,
                      onSelected: (m) => set((
                        status: filter.status,
                        platform: filter.platform,
                        kind: filter.kind,
                        triage: m,
                      )),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: null, child: Text('Every mood')),
                        const PopupMenuItem(value: 'urgent', child: Text('Urgent')),
                        for (final m in moods) PopupMenuItem(value: m, child: Text(moodLabel(m))),
                      ],
                      child: Chip(
                        avatar: const Icon(Icons.auto_awesome_rounded, size: 18, color: signal),
                        label: Text(filter.triage == null ? 'Every mood' : moodLabel(filter.triage!)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (platforms.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in platforms)
                    FilterChip(
                      avatar: PlatformBadge(p, size: 22),
                      label: Text(p.label),
                      selected: filter.platform == p,
                      showCheckmark: false,
                      onSelected: (on) => set((
                        status: filter.status,
                        platform: on ? p : null,
                        kind: filter.kind,
                        triage: filter.triage,
                      )),
                    ),
                ],
              ),
            ),
          AnimatedSize(
            duration: Motion.medium,
            curve: Curves.easeOutCubic,
            child: _picked.isEmpty
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Panel(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: signal.withValues(alpha: 0.12),
                      child: Row(
                        children: [
                          Expanded(child: Text('${_picked.length} selected')),
                          TextButton(onPressed: () => _bulk('read'), child: const Text('Mark read')),
                          FilledButton(onPressed: () => _bulk('done'), child: const Text('Mark done')),
                          IconButton(
                            tooltip: 'Clear selection',
                            onPressed: () => setState(_picked.clear),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          HubView(
            page,
            builder: (p) => p.items.isEmpty
                ? Big(
                    icon: Icons.mark_chat_read_rounded,
                    title: filter.status == 'done' ? 'Nothing done yet' : 'Inbox zero',
                    message: accounts.isEmpty
                        ? 'Connect an account and its comments and messages arrive here.'
                        : 'New comments, DMs and mentions arrive here within minutes (seconds for Instagram, '
                              'Facebook and Threads).',
                  )
                : Column(
                    children: [
                      for (final (i, item) in p.items.indexed)
                        Padding(
                          key: ValueKey(item.id),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Stagger(
                            i,
                            child: InboxCard(
                              item: item,
                              account: byId[item.accountId],
                              picked: _picked.contains(item.id),
                              picking: _picked.isNotEmpty,
                              onPick: (on) =>
                                  setState(() => on ? _picked.add(item.id) : _picked.remove(item.id)),
                            ),
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

/// One inbox item; tap to open the reply box.
class InboxCard extends ConsumerStatefulWidget {
  const InboxCard({
    super.key,
    required this.item,
    this.account,
    this.picked = false,
    this.picking = false,
    required this.onPick,
  });
  final InboxItem item;
  final Account? account;
  final bool picked, picking;
  final ValueChanged<bool> onPick;

  @override
  ConsumerState<InboxCard> createState() => _InboxCardState();
}

class _InboxCardState extends ConsumerState<InboxCard> {
  final _reply = TextEditingController();
  late InboxItem _item = widget.item;
  var _open = false, _private = false, _busy = false;
  List<String>? _suggestions;

  @override
  void didUpdateWidget(InboxCard old) {
    super.didUpdateWidget(old);
    if (old.item != widget.item) _item = widget.item;
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  /// The owner's language, which triage's language is compared with.
  String get _mine => ref.read(hubSettingsProvider).value?.language ?? 'English';

  /// The item's language when it isn't the owner's, so a reply can be translated into it.
  String? get _theirs {
    final lang = _item.triage?.lang ?? _item.translation?.lang ?? '';
    if (lang.isEmpty) return null;
    final name = languageName(lang);
    return name.toLowerCase() == _mine.toLowerCase() ? null : name;
  }

  bool get _canPrivate =>
      (widget.account?.can('private_reply') ?? false) && _item.kind == 'comment' && _item.myReply == null;

  Future<void> _toggle() async {
    if (widget.picking) return widget.onPick(!widget.picked);
    setState(() => _open = !_open);
    if (_open && _item.status == 'new') {
      // Opening it is reading it; no reload, so the list stays put.
      final read = await ref
          .hub((h) => h.setInboxStatus(_item.id, 'read'), refresh: false)
          .catchError((_) => _item);
      if (mounted) setState(() => _item = read);
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    final ok = await guarded(context, () async {
      _item = await ref.hub((h) => h.reply(_item.id, text, private: _private));
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _reply.clear();
        _open = false;
      }
    });
    if (ok) showMessage(context, _private ? 'Sent privately.' : 'Replied.');
  }

  Future<void> _suggest() async {
    setState(() => _busy = true);
    await guarded(context, () async {
      _suggestions = await ref.hub((h) => h.suggestReplies(_item.id), refresh: false);
    });
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _translate() async {
    setState(() => _busy = true);
    await guarded(context, () async {
      _item = await ref.hub((h) => h.translateItem(_item.id), refresh: false);
    });
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _replyInTheirs(String language) async {
    final text = _reply.text.trim();
    if (text.isEmpty) return showMessage(context, 'Write the reply first, then translate it.');
    setState(() => _busy = true);
    await guarded(context, () async {
      _reply.text = await ref.hub((h) => h.translate(text, language), refresh: false);
    });
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _moderate(String action) async {
    if (action == 'delete' &&
        !await confirm(
          context,
          title: 'Delete this comment?',
          message: 'It is removed from ${_item.platform.label} for everyone. This can\'t be undone.',
          action: 'Delete',
          destructive: true,
        )) {
      return;
    }
    if (!mounted) return;
    final ok = await guarded(context, () async {
      _item = await ref.hub((h) => h.moderate(_item.id, action));
    });
    if (ok && mounted) {
      setState(() {});
      showMessage(context, switch (action) {
        'hide' => 'Hidden from the public.',
        'unhide' => 'Visible again.',
        _ => 'Deleted.',
      });
    }
  }

  Future<void> _done() async {
    final next = _item.status == 'done' ? 'read' : 'done';
    await guarded(context, () => ref.hub((h) => h.setInboxStatus(_item.id, next)));
  }

  String _fill(String text) => text.replaceAll('{name}', _item.author.name.split(' ').first);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tone = Tone.of(context);
    final i = _item;
    final saved = ref.watch(hubSettingsProvider).value?.savedReplies ?? const <SavedReply>[];
    final meta = ref.watch(metaProvider).value ?? const HubMeta();
    final allowed = meta.info(i.platform).moderation;
    final canModerate = (i.kind == 'comment' || i.kind == 'reply') && i.moderation != 'deleted';
    final theirs = _theirs;
    return Panel(
      padding: EdgeInsets.zero,
      color: widget.picked ? signal.withValues(alpha: 0.1) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _toggle,
            onLongPress: () => widget.onPick(!widget.picked),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.picking)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Checkbox(value: widget.picked, onChanged: (v) => widget.onPick(v ?? false)),
                    ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Avatar(name: i.author.name, url: i.author.avatar, size: 44),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: PlatformBadge(i.platform, size: 22, ring: true),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      i.author.name,
                                      style: t.titleSmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (i.author.handle.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        i.author.handle,
                                        style: t.bodySmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Text(ago(i.at), style: t.bodySmall),
                            if (i.status == 'new')
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: signal, shape: BoxShape.circle),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Tag(kindLabel(i.kind), color: _kindColor(i.kind)),
                            _ContextChip(context: i.context, platform: i.platform),
                            if (widget.account != null)
                              Tag(widget.account!.name, icon: Icons.person_outline_rounded),
                            for (final l in i.labels)
                              Tag(l, color: const Color(0xFFA855F7), icon: Icons.bolt_rounded),
                            if ((i.likes ?? 0) > 0) Tag('${i.likes}', icon: Icons.favorite_rounded),
                            if (i.triage?.priority == 'high')
                              const Tag('Urgent', color: signal, icon: Icons.priority_high_rounded),
                            if (i.triage != null && i.triage!.mood != 'neutral')
                              Tag(moodLabel(i.triage!.mood), color: _moodColor(i.triage!.mood)),
                            if (theirs != null) Tag(theirs, icon: Icons.translate_rounded),
                            if (i.moderation != null)
                              Tag(
                                i.moderation == 'hidden' ? 'Hidden' : 'Deleted',
                                icon: i.moderation == 'hidden'
                                    ? Icons.visibility_off_rounded
                                    : Icons.delete_outline_rounded,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          i.text,
                          style: t.bodyLarge?.copyWith(
                            decoration: i.moderation == 'deleted' ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (i.translation != null && i.translation!.text != i.text)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              i.translation!.text,
                              style: t.bodyMedium?.copyWith(color: tone.muted, fontStyle: FontStyle.italic),
                            ),
                          ),
                        if (i.myReply != null)
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: tone.cardHigh,
                              borderRadius: BorderRadius.circular(14),
                              border: Border(
                                left: BorderSide(color: growth.withValues(alpha: 0.8), width: 3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  i.myReply!.private
                                      ? 'You replied privately · ${ago(i.myReply!.at)}'
                                      : 'You replied · ${ago(i.myReply!.at)}',
                                  style: t.labelSmall?.copyWith(color: growth, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(i.myReply!.text),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: Motion.medium,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_suggestions != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final s in _suggestions!)
                                  ActionChip(
                                    avatar: const Icon(Icons.auto_awesome_rounded, size: 16, color: signal),
                                    label: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 420),
                                      child: Text(s, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    ),
                                    onPressed: () => setState(() => _reply.text = s),
                                  ),
                              ],
                            ),
                          ),
                        TextField(
                          controller: _reply,
                          minLines: 1,
                          maxLines: 6,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: _private
                                ? 'Private reply to ${i.author.name}'
                                : 'Reply to ${i.author.name}',
                            suffixIcon: IconButton(
                              tooltip: 'Send',
                              onPressed: _busy ? null : _send,
                              icon: const Icon(Icons.send_rounded, color: signal),
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Hint(
                              'inbox.suggest',
                              child: AiButton(label: 'Suggest', onPressed: _busy ? null : _suggest),
                            ),
                            if (saved.isNotEmpty)
                              PopupMenuButton<SavedReply>(
                                tooltip: 'Saved replies',
                                onSelected: (r) => setState(() => _reply.text = _fill(r.text)),
                                itemBuilder: (_) => [
                                  for (final r in saved) PopupMenuItem(value: r, child: Text(r.title)),
                                ],
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bookmark_outline_rounded, size: 18),
                                      SizedBox(width: 6),
                                      Text('Saved replies'),
                                    ],
                                  ),
                                ),
                              ),
                            if (theirs != null && i.translation?.to != _mine)
                              AiButton(label: 'Translate', onPressed: _busy ? null : _translate),
                            if (theirs != null)
                              AiButton(
                                label: 'Reply in $theirs',
                                onPressed: _busy ? null : () => _replyInTheirs(theirs),
                              ),
                            if (_canPrivate)
                              Hint(
                                'inbox.private',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(value: _private, onChanged: (v) => setState(() => _private = v)),
                                    const Text('Reply privately'),
                                  ],
                                ),
                              ),
                            if (i.context.url != null)
                              TextButton.icon(
                                onPressed: () => openLink(context, i.context.url!),
                                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                label: const Text('Open'),
                              ),
                            TextButton.icon(
                              onPressed: _done,
                              icon: Icon(
                                i.status == 'done' ? Icons.undo_rounded : Icons.check_rounded,
                                size: 18,
                              ),
                              label: Text(i.status == 'done' ? 'Reopen' : 'Done'),
                            ),
                            if (canModerate && allowed.isNotEmpty)
                              PopupMenuButton<String>(
                                tooltip: 'Moderate',
                                icon: const Icon(Icons.shield_outlined),
                                onSelected: _moderate,
                                itemBuilder: (_) => [
                                  if (allowed.contains('hide'))
                                    i.moderation == 'hidden'
                                        ? const PopupMenuItem(value: 'unhide', child: Text('Unhide'))
                                        : const PopupMenuItem(
                                            value: 'hide',
                                            child: Text('Hide from the public'),
                                          ),
                                  if (allowed.contains('delete'))
                                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static Color _moodColor(String mood) => switch (mood) {
    'question' => const Color(0xFF3B82F6),
    'complaint' => const Color(0xFFF59E0B),
    'positive' => growth,
    _ => const Color(0xFF8A8A99),
  };

  static Color _kindColor(String kind) => switch (kind) {
    'message' => const Color(0xFF3B82F6),
    'mention' => const Color(0xFFF59E0B),
    'live_chat' => signal,
    _ => growth,
  };
}

/// Where it was said: "Reel · Autumn menu", with a thumbnail.
class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.context, required this.platform});
  final InboxContext context;
  final Platform platform;

  @override
  Widget build(BuildContext buildContext) {
    final tone = Tone.of(buildContext);
    final label = context.title.isEmpty
        ? contextLabel(context.type)
        : '${contextLabel(context.type)} · ${context.title}';
    return Container(
      padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
      decoration: BoxDecoration(color: tone.cardHigh, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: SizedBox.square(
              dimension: 18,
              child: Artwork(url: context.thumbnail, seed: context.id.ifEmpty(context.title), platform: null),
            ),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tone.muted, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}
