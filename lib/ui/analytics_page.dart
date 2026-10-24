import 'dart:math' as math;

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/providers.dart';
import '../domain/models.dart';
import 'common.dart';
import 'look.dart';

/// Followers over time, when your posts do best, and your top content.
class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  String? _account;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsProvider);
    final accounts = {for (final a in ref.watch(accountsProvider).value ?? const <Account>[]) a.id: a};
    return HubView(
      stats,
      builder: (s) {
        final chosen = s.accounts.where((a) => a.accountId == _account).firstOrNull;
        final series = chosen?.series ?? s.totalSeries;
        final base = s.followers - s.followersDelta;
        return PageBody(
          children: [
            const PageHeader('Analytics', subtitle: 'Followers, timing and what works'),
            _KpiRow(
              tiles: [
                ('Followers', s.followers, base > 0 ? s.followersDelta / base * 100 : null),
                ('New this week', s.followersDelta, null),
                ('Views · 28 days', s.views28d, null),
                ('Posts', s.accounts.fold(0, (n, a) => n + (a.posts ?? 0)), null),
              ],
            ),
            const SizedBox(height: 18),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Followers'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All accounts'),
                        selected: _account == null,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _account = null),
                      ),
                      for (final a in s.accounts)
                        if (accounts[a.accountId] != null)
                          ChoiceChip(
                            avatar: PlatformBadge(accounts[a.accountId]!.platform, size: 20),
                            label: Text(accounts[a.accountId]!.name),
                            selected: _account == a.accountId,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _account = a.accountId),
                          ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 240,
                    child: series.length < 2
                        ? Center(
                            child: Text(
                              'The hub takes a follower snapshot each night; the chart fills in from there.',
                              style: TextStyle(color: Tone.of(context).muted),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : _LineChart(key: ValueKey(_account), points: series),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, box) {
                final heat = _Heatmap(times: s.bestTimes, best: s.bestSlot);
                final table = _AccountTable(stats: s.accounts, accounts: accounts);
                if (box.maxWidth < 1000) return Column(children: [heat, const SizedBox(height: 18), table]);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: heat),
                    const SizedBox(width: 18),
                    Expanded(flex: 2, child: table),
                  ],
                );
              },
            ),
            const SizedBox(height: 26),
            const SectionTitle('Top content'),
            if (s.topContent.isEmpty)
              Text('Nothing ranked yet.', style: TextStyle(color: Tone.of(context).muted))
            else
              _TopGrid(content: s.topContent, accounts: accounts),
          ],
        );
      },
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.tiles});
  final List<(String, int, double?)> tiles;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, box) {
        final n = box.maxWidth < 700 ? 2 : 4;
        final w = (box.maxWidth - 14 * (n - 1)) / n;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final (label, value, delta) in tiles)
              SizedBox(
                width: w,
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: t.bodyMedium?.copyWith(color: Tone.of(context).muted)),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            CountUp(value, style: t.headlineLarge?.copyWith(fontSize: 32, height: 1)),
                            if (delta != null) ...[const SizedBox(width: 10), DeltaChip(delta)],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A smooth line with a soft red fill, drawn in from left to right.
class _LineChart extends StatelessWidget {
  const _LineChart({super.key, required this.points});
  final List<StatPoint> points;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    final t = Theme.of(context).textTheme;
    final values = [for (final p in points) p.followers.toDouble()];
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    String day(String d) => DateTime.tryParse(d) == null ? d : DateFormat('d MMM').format(DateTime.parse(d));
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 48,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(compactNumber(hi.round()), style: t.labelSmall?.copyWith(color: tone.muted)),
                    Text(compactNumber(lo.round()), style: t.labelSmall?.copyWith(color: tone.muted)),
                  ],
                ),
              ),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: Motion.reduced(context) ? 1 : 0, end: 1),
                  duration: const Duration(milliseconds: 1400),
                  curve: Curves.easeOutCubic,
                  builder: (context, p, _) =>
                      CustomPaint(painter: _LinePainter(values, lo, hi, p, tone.stroke), size: Size.infinite),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(day(points.first.day), style: t.labelSmall?.copyWith(color: tone.muted)),
              Text(day(points.last.day), style: t.labelSmall?.copyWith(color: tone.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.lo, this.hi, this.progress, this.grid);
  final List<double> values;
  final double lo, hi, progress;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final span = hi - lo == 0 ? 1 : hi - lo;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    Offset at(int i) => Offset(
      size.width * i / (values.length - 1),
      size.height - (values[i] - lo) / span * size.height * 0.86 - size.height * 0.07,
    );
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      final a = at(i - 1), b = at(i);
      final mid = (a.dx + b.dx) / 2;
      line.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [signal.withValues(alpha: 0.32), signal.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = signal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    if (progress > 0.98) {
      final end = at(values.length - 1);
      canvas.drawCircle(end, 7, Paint()..color = signal.withValues(alpha: 0.25));
      canvas.drawCircle(end, 4, Paint()..color = signal);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.progress != progress || old.values != values || old.grid != grid;
}

/// Engagement by weekday and hour in local time, darker red for better.
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.times, required this.best});
  final List<BestTime> times;
  final BestTime? best;

  /// A UTC weekday/hour as local weekday (0 = Monday) and hour.
  static (int, int) _local(int day, int hour) {
    // 1 January 2024 was a Monday.
    final l = DateTime.utc(2024, 1, 1 + day, hour).toLocal();
    return (l.weekday - 1, l.hour);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tone = Tone.of(context);
    final grid = List.generate(7, (_) => List<double>.filled(24, 0));
    for (final b in times) {
      final (d, h) = _local(b.day, b.hour);
      grid[d][h] = math.max(grid[d][h], b.score);
    }
    final bestLocal = best == null ? null : _local(best!.day, best!.hour);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Hint('analytics.best', child: Text('Best times to post', style: t.titleMedium)),
              ),
              if (bestLocal != null)
                Tag(
                  '${weekdays[bestLocal.$1]} ${bestLocal.$2.toString().padLeft(2, '0')}:00',
                  color: growth,
                  icon: Icons.bolt_rounded,
                ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final cell = ((box.maxWidth - 36) / 24).clamp(6.0, 30.0);
              return Column(
                children: [
                  for (var d = 0; d < 7; d++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text(weekdays[d], style: t.labelSmall?.copyWith(color: tone.muted)),
                          ),
                          for (var h = 0; h < 24; h++)
                            Tooltip(
                              message:
                                  '${weekdays[d]} ${h.toString().padLeft(2, '0')}:00 · ${(grid[d][h] * 100).round()}%',
                              child: Container(
                                width: cell - 3,
                                height: cell - 3,
                                margin: const EdgeInsets.only(right: 3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(math.min(6, cell / 3)),
                                  color: grid[d][h] == 0
                                      ? tone.cardHigh
                                      : signal.withValues(alpha: 0.18 + 0.82 * grid[d][h]),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 36, top: 4),
                    child: Row(
                      children: [
                        for (final h in [0, 6, 12, 18])
                          SizedBox(
                            width: cell * 6,
                            child: Text(
                              '${h.toString().padLeft(2, '0')}:00',
                              style: t.labelSmall?.copyWith(color: tone.muted),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          if (times.isEmpty) ...[
            const SizedBox(height: 10),
            Text('Fills in as your posts gather engagement.', style: t.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _AccountTable extends StatelessWidget {
  const _AccountTable({required this.stats, required this.accounts});
  final List<AccountStats> stats;
  final Map<String, Account> accounts;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('By account'),
          for (final s in stats)
            if (accounts[s.accountId] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    PlatformBadge(accounts[s.accountId]!.platform, size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            accounts[s.accountId]!.name,
                            style: t.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            s.views28d == null
                                ? '${s.posts ?? 0} posts'
                                : '${compactNumber(s.views28d!)} views',
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(compactNumber(s.followers ?? 0), style: t.titleMedium?.merge(tabular)),
                        if (s.followersDelta7d != null)
                          Text(
                            '${s.followersDelta7d! >= 0 ? '+' : ''}${s.followersDelta7d}',
                            style: t.labelSmall?.copyWith(
                              color: s.followersDelta7d! >= 0 ? growth : signal,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _TopGrid extends StatelessWidget {
  const _TopGrid({required this.content, required this.accounts});
  final List<Content> content;
  final Map<String, Account> accounts;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, box) {
        final n = (box.maxWidth / 240).floor().clamp(2, 5);
        final w = (box.maxWidth - 14 * (n - 1)) / n;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final (i, c) in content.indexed)
              SizedBox(
                width: w,
                child: Stagger(
                  i,
                  child: Panel(
                    padding: EdgeInsets.zero,
                    onTap: c.url == null ? null : () => openLink(context, c.url!),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Artwork(url: c.thumbnail, seed: c.id, platform: c.platform),
                              Positioned(left: 10, top: 10, child: PlatformBadge(c.platform, size: 28)),
                              Positioned(
                                right: 10,
                                top: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '#${i + 1}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.caption.ifEmpty(contextLabel(c.type)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                children: [
                                  if (c.views != null) _N(Icons.visibility_outlined, c.views!),
                                  _N(Icons.favorite_border_rounded, c.likes),
                                  _N(Icons.mode_comment_outlined, c.comments),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _N extends StatelessWidget {
  const _N(this.icon, this.n);
  final IconData icon;
  final int n;

  @override
  Widget build(BuildContext context) {
    final muted = Tone.of(context).muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: muted),
        const SizedBox(width: 4),
        Text(
          compactNumber(n),
          style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
