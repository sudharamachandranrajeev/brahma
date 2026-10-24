import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/providers.dart';
import '../domain/models.dart';
import 'common.dart';
import 'compose_page.dart';
import 'look.dart';
import 'post_page.dart';

/// Every post by month or week. Posts are coloured by status; drag one to
/// another day (or hour, in the week view) to reschedule it, tap an empty
/// day to plan one there. Drafts and failed posts sit alongside, failed ones
/// with Retry and a warning when they may have gone out after all.
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _focus = DateUtils.dateOnly(DateTime.now());
  DateTime _selected = DateUtils.dateOnly(DateTime.now());
  var _week = false;

  DateTime get _from {
    if (_week) return _focus.subtract(Duration(days: _focus.weekday - 1));
    final first = DateTime(_focus.year, _focus.month);
    return first.subtract(Duration(days: first.weekday - 1));
  }

  DateTime get _to => _from.add(Duration(days: _week ? 7 : 42));

  void _shift(int n) => setState(() {
    _focus = _week ? _focus.add(Duration(days: 7 * n)) : DateTime(_focus.year, _focus.month + n);
  });

  Future<void> _move(Post post, DateTime day, {int? hour}) async {
    if (!post.editable) return showMessage(context, 'Only drafts and scheduled posts can be moved.');
    final old = localTime(post.scheduledAt) ?? DateTime(day.year, day.month, day.day, 9);
    final at = DateTime(day.year, day.month, day.day, hour ?? old.hour, hour == null ? old.minute : 0);
    if (at.isBefore(DateTime.now())) return showMessage(context, 'That time has passed.');
    final ok = await guarded(
      context,
      () => ref.hub((h) => h.updatePost(post.id, PostInput.of(post, scheduledAt: hubTime(at)))),
    );
    if (ok && mounted) showMessage(context, 'Moved to ${whenLabel(hubTime(at))}.');
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(postsProvider((hubTime(_from), hubTime(_to))));
    final accounts = {for (final a in ref.watch(accountsProvider).value ?? const <Account>[]) a.id: a};
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final t = Theme.of(context).textTheme;
    final title = _week
        ? '${DateFormat('d MMM').format(_from)} – ${DateFormat('d MMM y').format(_to.subtract(const Duration(days: 1)))}'
        : DateFormat('MMMM y').format(_focus);
    return HubView(
      posts,
      builder: (list) {
        final byDay = <DateTime, List<Post>>{};
        for (final p in list) {
          final at = localTime(p.when);
          if (at != null) byDay.putIfAbsent(DateUtils.dateOnly(at), () => []).add(p);
        }
        for (final l in byDay.values) {
          l.sort((a, b) => (a.when ?? '').compareTo(b.when ?? ''));
        }
        final grid = _week
            ? _WeekGrid(from: _from, byDay: byDay, accounts: accounts, onMove: _move)
            : _MonthGrid(
                from: _from,
                month: _focus.month,
                byDay: byDay,
                accounts: accounts,
                compact: narrow,
                selected: _selected,
                onSelect: (d) => setState(() => _selected = d),
                onMove: _move,
              );
        final header = Row(
          children: [
            Expanded(
              child: Text(title, style: (narrow ? t.headlineSmall : t.displaySmall)?.copyWith(height: 1.05)),
            ),
            IconButton(
              tooltip: 'Previous',
              onPressed: () => _shift(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            TextButton(
              onPressed: () => setState(() => _focus = _selected = DateUtils.dateOnly(DateTime.now())),
              child: const Text('Today'),
            ),
            IconButton(
              tooltip: 'Next',
              onPressed: () => _shift(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        );
        final toggle = SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Month'),
              icon: Icon(Icons.calendar_view_month_rounded, size: 18),
            ),
            ButtonSegment(value: true, label: Text('Week'), icon: Icon(Icons.view_week_rounded, size: 18)),
          ],
          selected: {_week},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _week = s.first),
        );
        final legend = Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final s in ['scheduled', 'publishing', 'published', 'failed', 'draft'])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: statusLook(s).color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(statusLook(s).label, style: t.bodySmall),
                ],
              ),
          ],
        );
        final side = _Side(accounts: accounts);
        final dayPosts = byDay[_selected] ?? const <Post>[];
        return LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= 1200;
            final main = PageBody(
              children: [
                header,
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [toggle, legend],
                ),
                const SizedBox(height: 18),
                Panel(padding: const EdgeInsets.all(10), child: grid),
                if (narrow && !_week) ...[
                  const SizedBox(height: 18),
                  SectionTitle(
                    DateFormat('EEEE d MMMM').format(_selected),
                    action: 'Plan',
                    onAction: () => openCompose(
                      context,
                      at: DateTime(_selected.year, _selected.month, _selected.day, 12),
                    ),
                  ),
                  if (dayPosts.isEmpty)
                    Text('Nothing this day.', style: t.bodyMedium?.copyWith(color: Tone.of(context).muted)),
                  for (final p in dayPosts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PostChip(post: p, accounts: accounts, roomy: true),
                    ),
                ],
                if (!wide) ...[const SizedBox(height: 18), side],
              ],
            );
            if (!wide) return main;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: main),
                SizedBox(
                  width: 340,
                  child: ListView(padding: const EdgeInsets.fromLTRB(0, 28, 28, 28), children: [side]),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.from,
    required this.month,
    required this.byDay,
    required this.accounts,
    required this.compact,
    required this.selected,
    required this.onSelect,
    required this.onMove,
  });
  final DateTime from, selected;
  final int month;
  final Map<DateTime, List<Post>> byDay;
  final Map<String, Account> accounts;
  final bool compact;
  final ValueChanged<DateTime> onSelect;
  final Future<void> Function(Post, DateTime, {int? hour}) onMove;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tone = Tone.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    return Column(
      children: [
        Row(
          children: [
            for (final d in weekdays)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    compact ? d.substring(0, 1) : d,
                    textAlign: TextAlign.center,
                    style: t.labelMedium?.copyWith(color: tone.muted),
                  ),
                ),
              ),
          ],
        ),
        for (var w = 0; w < 6; w++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final day = DateUtils.dateOnly(from.add(Duration(days: w * 7 + d)));
                      final posts = byDay[day] ?? const <Post>[];
                      return DragTarget<Post>(
                        onWillAcceptWithDetails: (_) => !day.isBefore(today),
                        onAcceptWithDetails: (details) => onMove(details.data, day),
                        builder: (context, hover, _) => _DayCell(
                          day: day,
                          inMonth: day.month == month,
                          today: day == today,
                          selected: compact && day == selected,
                          hover: hover.isNotEmpty,
                          compact: compact,
                          posts: posts,
                          accounts: accounts,
                          onTap: () => compact
                              ? onSelect(day)
                              : openCompose(context, at: DateTime(day.year, day.month, day.day, 12)),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.today,
    required this.selected,
    required this.hover,
    required this.compact,
    required this.posts,
    required this.accounts,
    required this.onTap,
  });
  final DateTime day;
  final bool inMonth, today, selected, hover, compact;
  final List<Post> posts;
  final Map<String, Account> accounts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    final t = Theme.of(context).textTheme;
    final number = Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: today ? signal : Colors.transparent, shape: BoxShape.circle),
      child: Text(
        '${day.day}',
        style: t.labelLarge?.copyWith(
          color: today ? Colors.white : (inMonth ? tone.text : tone.muted.withValues(alpha: 0.5)),
          fontWeight: today ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
    return AnimatedContainer(
      duration: Motion.short,
      margin: const EdgeInsets.all(3),
      height: compact ? 56 : 128,
      decoration: BoxDecoration(
        color: hover
            ? signal.withValues(alpha: 0.16)
            : selected
            ? tone.cardHigh
            : (inMonth ? tone.cardHigh.withValues(alpha: 0.45) : Colors.transparent),
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        border: Border.all(color: hover || selected ? signal : Colors.transparent, width: 1.4),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 4 : 8),
          child: compact
              ? Column(
                  children: [
                    number,
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 3,
                      children: [
                        for (final p in posts.take(3))
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusLook(p.status).color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    number,
                    const SizedBox(height: 4),
                    for (final p in posts.take(posts.length > 3 ? 2 : 3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _PostChip(post: p, accounts: accounts),
                      ),
                    if (posts.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          '+${posts.length - 2} more',
                          style: t.labelSmall?.copyWith(color: tone.muted),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.from, required this.byDay, required this.accounts, required this.onMove});
  final DateTime from;
  final Map<DateTime, List<Post>> byDay;
  final Map<String, Account> accounts;
  final Future<void> Function(Post, DateTime, {int? hour}) onMove;

  static final _hours = [for (var h = 6; h < 24; h++) h];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tone = Tone.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final days = [for (var i = 0; i < 7; i++) DateUtils.dateOnly(from.add(Duration(days: i)))];
    return LayoutBuilder(
      builder: (context, box) {
        final colWidth = ((box.maxWidth - 52) / 7).clamp(96.0, 400.0);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 52 + colWidth * 7,
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 52),
                    for (final d in days)
                      SizedBox(
                        width: colWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              Text(
                                weekdays[d.weekday - 1],
                                style: t.labelMedium?.copyWith(color: tone.muted),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: d == today ? signal : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${d.day}',
                                  style: t.titleMedium?.copyWith(color: d == today ? Colors.white : null),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                for (final h in _hours)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 52,
                        height: 58,
                        child: Text(
                          '${h.toString().padLeft(2, '0')}:00',
                          style: t.labelSmall?.copyWith(color: tone.muted),
                        ),
                      ),
                      for (final d in days)
                        SizedBox(
                          width: colWidth,
                          child: DragTarget<Post>(
                            onWillAcceptWithDetails: (_) =>
                                DateTime(d.year, d.month, d.day, h + 1).isAfter(DateTime.now()),
                            onAcceptWithDetails: (details) => onMove(details.data, d, hour: h),
                            builder: (context, hover, _) {
                              final posts = [
                                for (final p in byDay[d] ?? const <Post>[])
                                  if (localTime(p.when)?.hour == h) p,
                              ];
                              return AnimatedContainer(
                                duration: Motion.short,
                                constraints: const BoxConstraints(minHeight: 58),
                                decoration: BoxDecoration(
                                  color: hover.isNotEmpty ? signal.withValues(alpha: 0.16) : null,
                                  border: Border(
                                    top: BorderSide(color: tone.stroke),
                                    left: BorderSide(color: tone.stroke),
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () => openCompose(context, at: DateTime(d.year, d.month, d.day, h)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: Column(
                                      children: [
                                        for (final p in posts)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 3),
                                            child: _PostChip(post: p, accounts: accounts),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A post in the calendar: status colour, time, platforms and text. Drafts
/// and scheduled posts can be dragged to another day.
class _PostChip extends StatelessWidget {
  const _PostChip({required this.post, required this.accounts, this.roomy = false});
  final Post post;
  final Map<String, Account> accounts;
  final bool roomy;

  @override
  Widget build(BuildContext context) {
    final look = statusLook(post.status);
    final t = Theme.of(context).textTheme;
    final platforms = {for (final x in post.targets) ?accounts[x.accountId]?.platform};
    final time = localTime(post.when);
    Widget chip({double? width}) => Material(
      color: look.color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => openPost(context, post),
        child: Container(
          width: width,
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: roomy ? 10 : 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: look.color, width: 3)),
          ),
          child: LayoutBuilder(
            builder: (context, box) => Row(
              children: [
                if (post.maybePosted)
                  const Padding(
                    padding: EdgeInsets.only(right: 3),
                    child: Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFF59E0B)),
                  ),
                if (time != null)
                  Text(
                    DateFormat.Hm().format(time),
                    style: t.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: look.color),
                  ),
                const SizedBox(width: 4),
                // Narrow week cells keep the time and text, not the badges.
                for (final p in platforms.take(box.maxWidth < 120 ? 0 : (roomy ? 4 : 2)))
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: PlatformBadge(p, size: roomy ? 20 : 14),
                  ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    post.text.ifEmpty('(media)'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (roomy ? t.bodyMedium : t.labelSmall),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!post.editable) return chip();
    return LayoutBuilder(
      builder: (context, box) => Draggable<Post>(
        data: post,
        feedback: Material(
          color: Colors.transparent,
          elevation: 8,
          borderRadius: BorderRadius.circular(10),
          child: chip(width: box.maxWidth.isFinite ? box.maxWidth : 180),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: chip()),
        child: chip(),
      ),
    );
  }
}

/// Drafts to schedule and failed posts to retry.
class _Side extends ConsumerWidget {
  const _Side({required this.accounts});
  final Map<String, Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(draftsProvider).value ?? const <Post>[];
    final failed = ref.watch(failedProvider).value ?? const <Post>[];
    final t = Theme.of(context).textTheme;
    final tone = Tone.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failed.isNotEmpty) ...[
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle('Failed (${failed.length})'),
                for (final p in failed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PostChip(post: p, accounts: accounts, roomy: true),
                        if (p.maybePosted)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'May have posted. Check before retrying.',
                              style: t.bodySmall?.copyWith(color: const Color(0xFFF59E0B)),
                            ),
                          ),
                        for (final e in p.targets.map((x) => x.error).nonNulls.take(1))
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(e, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => p.maybePosted
                                ? openPost(context, p)
                                : guarded(context, () => ref.hub((h) => h.retryPost(p.id))),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Retry'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle('Drafts (${drafts.length})', action: 'New', onAction: () => openCompose(context)),
              if (drafts.isEmpty)
                Text(
                  'Drafts you save land here. Drag one onto a day to schedule it.',
                  style: t.bodyMedium?.copyWith(color: tone.muted),
                ),
              for (final p in drafts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PostChip(post: p, accounts: accounts, roomy: true),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
