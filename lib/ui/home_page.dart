import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/providers.dart';
import '../domain/models.dart';
import 'common.dart';
import 'compose_page.dart';
import 'look.dart';
import 'post_page.dart';

/// The dashboard: a big greeting, the headline numbers, a ticker of what is
/// happening, the best-performing post, ideas, today's replies, a clock and
/// what goes out next. Everything comes from GET /social/overview.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(overviewProvider);
    final name = ref.watch(nameProvider).value ?? '';
    return HubView(
      overview,
      loading: const _HomeSkeleton(),
      builder: (o) => LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 1180;
          final main = _Main(o: o, name: name, wide: wide);
          if (!wide) return main;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: main),
              SizedBox(width: 330, child: _Side(o: o)),
              _PlatformRail(accounts: o.accounts),
            ],
          );
        },
      ),
    );
  }
}

String greeting(DateTime now) => switch (now.hour) {
  < 5 => 'Good evening',
  < 12 => 'Good morning',
  < 18 => 'Good afternoon',
  _ => 'Good evening',
};

class _Main extends StatelessWidget {
  const _Main({required this.o, required this.name, required this.wide});
  final Overview o;
  final String name;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final today = o.upcoming
        .where((p) => DateUtils.isSameDay(localTime(p.scheduledAt), DateTime.now()))
        .length;
    return PageBody(
      children: [
        _Greeting(name: name, inboxNew: o.inboxNew, today: today),
        if (o.accounts.isEmpty)
          Big(
            icon: Icons.add_link_rounded,
            title: 'Connect your first account',
            message:
                'Link Instagram, Facebook Pages, YouTube, LinkedIn, Threads, Bluesky or Mastodon. The hub keeps '
                'the sign-in and does the posting.',
            action: Consumer(
              builder: (context, ref, _) => FilledButton.icon(
                onPressed: () => ref.read(tabProvider.notifier).go(VaniTab.accounts),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Connect an account'),
              ),
            ),
          )
        else ...[
          _Kpis(o: o),
          const SizedBox(height: 18),
          _Ticker(o: o),
          const SizedBox(height: 18),
          if (narrow) ...[
            _Hero(o: o),
            const SizedBox(height: 18),
            _Activity(items: o.recentInbox),
            const SizedBox(height: 18),
            _Ideas(o: o),
          ] else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: _Hero(o: o)),
                  const SizedBox(width: 18),
                  Expanded(flex: 2, child: _Ideas(o: o)),
                ],
              ),
            ),
          if (!wide && !narrow) ...[
            const SizedBox(height: 18),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(child: _ClockCard()),
                  const SizedBox(width: 18),
                  Expanded(child: _Activity(items: o.recentInbox)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 26),
          _UpNext(o: o),
        ],
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.inboxNew, required this.today});
  final String name;
  final int inboxNew, today;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final who = name.trim().isEmpty ? '' : ', ${name.trim().split(' ').first}';
    final parts = [
      if (inboxNew > 0) '$inboxNew new ${inboxNew == 1 ? 'reply' : 'replies'} waiting',
      if (today > 0) '$today ${today == 1 ? 'post goes' : 'posts go'} out today',
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: narrow ? 18 : 26, top: narrow ? 4 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${greeting(DateTime.now())}$who!',
                  style: (narrow ? t.headlineLarge : t.displayMedium)?.copyWith(height: 1.02),
                ),
                const SizedBox(height: 10),
                Text(
                  parts.isEmpty
                      ? 'All caught up. Plan something new or see how your posts are doing.'
                      : '${parts.join(' and ')}.',
                  style: t.titleMedium?.copyWith(color: Tone.of(context).muted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (!narrow) ...[
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: () => openCompose(context),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Create post'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Followers, views, replies and account health, in one strip on wide
/// screens and a 2 by 2 grid on phones.
class _Kpis extends StatelessWidget {
  const _Kpis({required this.o});
  final Overview o;

  @override
  Widget build(BuildContext context) {
    final s = o.stats;
    final series = [for (final p in s.totalSeries) p.followers.toDouble()];
    final base = s.followers - s.followersDelta;
    final followerPct = base > 0 ? s.followersDelta / base * 100 : 0.0;
    final healthy = o.accounts.where((a) => a.status == 'ok').length;
    final perDay = _views(s);
    final tiles = <Widget>[
      _Kpi(
        label: 'Total followers',
        value: s.followers,
        delta: followerPct,
        foot: MeterBars(values: _diffs(series), slots: 28),
      ),
      _Kpi(
        label: 'Views · 28 days',
        value: s.views28d,
        foot: MeterBars(values: perDay, slots: 28, color: const Color(0xFFF5F5F5)),
        sub: '${o.topContent.length} top posts',
      ),
      _Kpi(
        label: 'New replies',
        value: o.inboxNew,
        sub: '${o.inboxRead} read, not done',
        foot: _ReplyDots(fresh: o.inboxNew, read: o.inboxRead),
      ),
      _Kpi(
        label: 'Accounts',
        value: o.accounts.length,
        sub: '$healthy healthy',
        side: Gauge(
          fraction: o.accounts.isEmpty ? 0 : healthy / o.accounts.length,
          size: 68,
          label: '${o.accounts.isEmpty ? 0 : (healthy * 100 / o.accounts.length).round()}%',
        ),
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 760) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: box.maxWidth < 420 ? 0.98 : 1.5,
            children: [for (final t in tiles) Panel(padding: const EdgeInsets.all(16), child: t)],
          );
        }
        return Panel(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 6),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, t) in tiles.indexed) ...[
                  if (i > 0) VerticalDivider(width: 1, color: Tone.of(context).stroke),
                  Expanded(
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: t),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Daily follower gains, for the bars (the levels themselves barely move).
  static List<double> _diffs(List<double> s) =>
      s.length < 2 ? s : [for (var i = 1; i < s.length; i++) math.max(0, s[i] - s[i - 1]) + 1];

  /// A smooth stand-in for daily views: top content views, newest last.
  static List<double> _views(Stats s) {
    final v = [for (final c in s.topContent.reversed) (c.views ?? c.likes * 10).toDouble()];
    return v.isEmpty ? const [] : v;
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, this.delta, this.sub, this.foot, this.side});
  final String label;
  final int value;
  final double? delta;
  final String? sub;
  final Widget? foot, side;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tone = Tone.of(context);
    final number = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: t.bodyMedium?.copyWith(color: tone.muted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CountUp(value, style: t.headlineLarge?.copyWith(fontSize: 34, height: 1)),
              if (delta != null) ...[const SizedBox(width: 10), DeltaChip(delta!)],
            ],
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 6),
          Text(sub!, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (side == null)
          number
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: number),
              side!,
            ],
          ),
        if (foot != null) ...[const SizedBox(height: 14), SizedBox(height: 40, child: foot)],
      ],
    );
  }
}

/// New replies as bright dots, read ones dim, in a row of 24.
class _ReplyDots extends StatelessWidget {
  const _ReplyDots({required this.fresh, required this.read});
  final int fresh, read;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final n = math.max(1, (box.maxWidth / 13).floor());
        return Align(
          alignment: Alignment.bottomLeft,
          child: Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (var i = 0; i < n; i++)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < fresh
                        ? signal
                        : i < fresh + read
                        ? signal.withValues(alpha: 0.35)
                        : tone.stroke,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// "YOUR DIGITAL HUB • 3 POSTS TODAY • …" sliding past.
class _Ticker extends StatelessWidget {
  const _Ticker({required this.o});
  final Overview o;

  @override
  Widget build(BuildContext context) {
    final next = o.upcoming.firstOrNull;
    final nextAccount = next == null
        ? null
        : o.accounts.where((a) => a.id == next.targets.firstOrNull?.accountId).firstOrNull;
    final items = [
      'YOUR DIGITAL HUB',
      '${o.accounts.length} ACCOUNTS LIVE',
      '${o.inboxNew} NEW REPLIES',
      '${o.upcoming.length} POSTS QUEUED',
      if (next != null && nextAccount != null)
        'NEXT: ${nextAccount.platform.label.toUpperCase()} ${whenLabel(next.scheduledAt).toUpperCase()}',
      '${o.alerts.where((a) => !a.read).length} ALERTS',
    ];
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final style = Theme.of(context).textTheme.displaySmall
        ?.copyWith(fontSize: narrow ? 26 : 40, letterSpacing: -0.5, height: 1, color: Tone.of(context).text);
    return Panel(
      padding: EdgeInsets.symmetric(vertical: narrow ? 16 : 22),
      clip: true,
      child: SizedBox(
        height: narrow ? 28 : 42,
        child: Marquee(items.join('  •  '), style: style, speed: 46),
      ),
    );
  }
}

/// The best-performing recent post, full-bleed, or the next post when
/// there are no numbers yet.
class _Hero extends ConsumerWidget {
  const _Hero({required this.o});
  final Overview o;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = o.topContent.firstOrNull;
    final t = Theme.of(context).textTheme;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    if (top == null) {
      return Big(
        icon: Icons.auto_awesome_rounded,
        title: 'Your best post will show here',
        message: 'Once your posts gather likes and views, the hub ranks them here.',
        action: FilledButton(onPressed: () => openCompose(context), child: const Text('Create a post')),
      );
    }
    final account = o.accounts.where((a) => a.id == top.accountId).firstOrNull;
    return Lift(
      amount: 1.01,
      child: Material(
        color: Tone.of(context).card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
        child: InkWell(
          onTap: top.url == null ? null : () => openLink(context, top.url!),
          child: SizedBox(
            height: narrow ? 300 : 380,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Artwork(url: top.thumbnail, seed: top.id, platform: top.platform),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.25, 1],
                      colors: [Color(0x00000000), Color(0xE6000000)],
                    ),
                  ),
                ),
                Positioned(
                  top: 18,
                  left: 18,
                  right: 18,
                  child: Row(
                    children: [
                      _Glass(label: 'Top ${contextLabel(top.type).toLowerCase()}'),
                      const Spacer(),
                      PlatformBadge(top.platform, size: 38),
                    ],
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${account?.name ?? top.platform.label} · ${ago(top.at)}',
                        style: t.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        top.caption.ifEmpty('Untitled'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: (narrow ? t.headlineSmall : t.headlineMedium)?.copyWith(
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 16,
                        children: [
                          if (top.views != null) _Stat(Icons.visibility_outlined, top.views!),
                          _Stat(Icons.favorite_border_rounded, top.likes),
                          _Stat(Icons.mode_comment_outlined, top.comments),
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
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.value);
  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: Colors.white70),
      const SizedBox(width: 5),
      Text(
        compactNumber(value),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

/// The hub's AI ideas, or more top posts when there are none.
class _Ideas extends StatelessWidget {
  const _Ideas({required this.o});
  final Overview o;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tone = Tone.of(context);
    final ideas = o.ideas.take(4).toList();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(ideas.isEmpty ? 'More top posts' : 'Ideas for you'),
          if (ideas.isEmpty && o.topContent.length < 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Post ideas from Claude appear here each morning once your Anthropic key is set on the hub.',
                style: t.bodyMedium?.copyWith(color: tone.muted),
              ),
            ),
          for (final (i, idea) in ideas.indexed)
            _Row(
              seed: idea.title,
              tag: idea.kind,
              title: idea.title,
              body: idea.body,
              last: i == ideas.length - 1,
              onTap: () => openCompose(context, text: '${idea.title}\n\n${idea.body}'),
            ),
          if (ideas.isEmpty)
            for (final (i, c) in o.topContent.skip(1).take(4).indexed)
              _Row(
                seed: c.id,
                platform: c.platform,
                url: c.thumbnail,
                tag: contextLabel(c.type),
                title: c.caption.ifEmpty('Untitled'),
                body: '${compactNumber(c.likes)} likes · ${compactNumber(c.comments)} comments',
                last: i == math.min(4, o.topContent.length - 1) - 1,
                onTap: c.url == null ? null : () => openLink(context, c.url!),
              ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.seed,
    required this.tag,
    required this.title,
    required this.body,
    required this.last,
    this.platform,
    this.url,
    this.onTap,
  });
  final String seed, tag, title, body;
  final Platform? platform;
  final String? url;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 72,
                height: 72,
                child: Artwork(url: url, seed: seed, platform: platform),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tag.toUpperCase(),
                    style: t.labelSmall?.copyWith(
                      color: signal,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                  const SizedBox(height: 2),
                  Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What goes out next, as tall tiles with the platforms on them.
class _UpNext extends ConsumerWidget {
  const _UpNext({required this.o});
  final Overview o;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = {for (final m in ref.watch(mediaProvider).value ?? const <MediaItem>[]) m.id: m};
    final byId = {for (final a in o.accounts) a.id: a};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Up next',
          action: 'Calendar',
          onAction: () => ref.read(tabProvider.notifier).go(VaniTab.calendar),
        ),
        if (o.upcoming.isEmpty)
          Panel(
            onTap: () => openCompose(context),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline_rounded, color: signal),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nothing scheduled. Plan your next post.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: o.upcoming.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final p = o.upcoming[i];
                final platforms = {for (final t in p.targets) ?byId[t.accountId]?.platform}.toList();
                return Stagger(
                  i,
                  child: SizedBox(
                    width: 210,
                    child: PostTile(
                      post: p,
                      media: p.media.isEmpty ? null : media[p.media.first],
                      platforms: platforms,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// A post as a tall card: its picture (shared with the detail page), the
/// platforms as badges, when it goes out and its text.
class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post, required this.platforms, this.media});
  final Post post;
  final List<Platform> platforms;
  final MediaItem? media;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final look = statusLook(post.status);
    return Lift(
      child: Material(
        color: Tone.of(context).card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Tone.of(context).stroke),
        ),
        child: InkWell(
          onTap: () => openPost(context, post),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PostArt(post: post, media: media, platform: platforms.firstOrNull),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Row(
                        children: [
                          for (final (i, p) in platforms.take(4).indexed)
                            Transform.translate(
                              offset: Offset(-8.0 * i, 0),
                              child: PlatformBadge(p, size: 30, ring: true),
                            ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Tag(look.label, color: look.color, icon: look.icon),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      whenLabel(post.when),
                      style: t.labelMedium?.copyWith(color: signal, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post.text.ifEmpty('(media only)'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium?.copyWith(height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The right column: clock, today's replies, latest alerts.
class _Side extends StatelessWidget {
  const _Side({required this.o});
  final Overview o;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(0, 28, 0, 28),
    children: [
      const Stagger(1, child: _ClockCard()),
      const SizedBox(height: 18),
      Stagger(2, child: _Activity(items: o.recentInbox)),
      if (o.alerts.isNotEmpty) ...[const SizedBox(height: 18), Stagger(3, child: _Alerts(alerts: o.alerts))],
    ],
  );
}

/// An analog face and the digital time, ticking each second.
class _ClockCard extends StatefulWidget {
  const _ClockCard();

  @override
  State<_ClockCard> createState() => _ClockCardState();
}

class _ClockCardState extends State<_ClockCard> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tone = Tone.of(context);
    return Panel(
      child: Row(
        children: [
          SizedBox.square(dimension: 96, child: CustomPaint(painter: _ClockFace(_now, tone))),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      text: DateFormat.Hm().format(_now),
                      children: [
                        TextSpan(
                          text: ':${_now.second.toString().padLeft(2, '0')}',
                          style: TextStyle(color: tone.muted, fontSize: 20),
                        ),
                      ],
                    ),
                    style: t.headlineLarge?.copyWith(fontSize: 38, height: 1).merge(_tab),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('EEEE, d MMMM').format(_now),
                  style: t.bodyMedium?.copyWith(color: tone.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  _now.timeZoneName,
                  style: t.labelSmall?.copyWith(
                    color: signal,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _tab = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
}

class _ClockFace extends CustomPainter {
  _ClockFace(this.now, this.tone);
  final DateTime now;
  final Tone tone;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = tone.cardHigh);
    canvas.drawCircle(
      c,
      r - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = tone.stroke,
    );
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final major = i % 3 == 0;
      final p1 = c + Offset(math.sin(a), -math.cos(a)) * (r - 7);
      final p2 = c + Offset(math.sin(a), -math.cos(a)) * (r - (major ? 15 : 11));
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = major ? tone.text : tone.muted
          ..strokeWidth = major ? 2.4 : 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
    void hand(double turns, double length, double width, Color color) {
      final a = turns * 2 * math.pi;
      canvas.drawLine(
        c - Offset(math.sin(a), -math.cos(a)) * 6,
        c + Offset(math.sin(a), -math.cos(a)) * length,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    final s = now.second / 60;
    final m = (now.minute + s) / 60;
    final h = ((now.hour % 12) + m) / 12;
    hand(h, r * 0.48, 4, tone.text);
    hand(m, r * 0.7, 3, tone.text);
    hand(s, r * 0.78, 1.6, signal);
    canvas.drawCircle(c, 4, Paint()..color = signal);
  }

  @override
  bool shouldRepaint(_ClockFace old) => old.now != now || old.tone != tone;
}

/// Today's replies: who said what, where, and when.
class _Activity extends ConsumerWidget {
  const _Activity({required this.items});
  final List<InboxItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final tone = Tone.of(context);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Today\'s activity',
            action: 'Inbox',
            onAction: () => ref.read(tabProvider.notifier).go(VaniTab.inbox),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No new replies. Quiet day.', style: t.bodyMedium?.copyWith(color: tone.muted)),
            ),
          for (final (i, item) in items.take(5).indexed)
            Padding(
              padding: EdgeInsets.only(bottom: i == math.min(5, items.length) - 1 ? 0 : 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => ref.read(tabProvider.notifier).go(VaniTab.inbox),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Avatar(name: item.author.name, url: item.author.avatar, size: 40),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: PlatformBadge(item.platform, size: 20, ring: true),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.author.name,
                                  style: t.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(ago(item.at), style: t.bodySmall),
                            ],
                          ),
                          Text(
                            '${kindLabel(item.kind)} on ${contextLabel(item.context.type).toLowerCase()}',
                            style: t.labelSmall?.copyWith(color: tone.muted),
                          ),
                          const SizedBox(height: 3),
                          Text(item.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyMedium),
                        ],
                      ),
                    ),
                    if (item.status == 'new')
                      Container(
                        margin: const EdgeInsets.only(left: 8, top: 6),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: signal, shape: BoxShape.circle),
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

class _Alerts extends ConsumerWidget {
  const _Alerts({required this.alerts});
  final List<Alert> alerts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Alerts',
            action: 'All',
            onAction: () => ref.read(tabProvider.notifier).go(VaniTab.alerts),
          ),
          for (final a in alerts.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(alertIcon(a.kind), size: 20, color: a.read ? Tone.of(context).muted : signal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                        Text(a.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(ago(a.at), style: t.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

IconData alertIcon(String kind) => switch (kind) {
  'discovery' => Icons.travel_explore_rounded,
  'inbox' => Icons.forum_rounded,
  'publish' => Icons.send_rounded,
  'account' => Icons.manage_accounts_rounded,
  'summary' => Icons.insights_rounded,
  _ => Icons.info_rounded,
};

/// The far-right column of round platform buttons, one per connected
/// platform, like a dock.
class _PlatformRail extends ConsumerWidget {
  const _PlatformRail({required this.accounts});
  final List<Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byPlatform = <Platform, List<Account>>{};
    for (final a in accounts) {
      byPlatform.putIfAbsent(a.platform, () => []).add(a);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 20, 28),
      child: Column(
        children: [
          for (final (i, e) in byPlatform.entries.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Stagger(
                i + 2,
                child: Tooltip(
                  message: [for (final a in e.value) a.name].join(', '),
                  child: Lift(
                    amount: 1.12,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => openCompose(context, accountIds: [for (final a in e.value) a.id]),
                      child: PlatformBadge(e.key, size: 48),
                    ),
                  ),
                ),
              ),
            ),
          Tooltip(
            message: 'Connect an account',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => ref.read(tabProvider.notifier).go(VaniTab.accounts),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Tone.of(context).stroke, width: 1.5),
                ),
                child: Icon(Icons.add_rounded, color: Tone.of(context).muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(height: 54, width: 460, radius: 16),
        SizedBox(height: 12),
        Skeleton(height: 18, width: 300),
        SizedBox(height: 28),
        Skeleton(height: 150, radius: cardRadius),
        SizedBox(height: 18),
        Skeleton(height: 80, radius: cardRadius),
        SizedBox(height: 18),
        Skeleton(height: 320, radius: cardRadius),
      ],
    ),
  );
}
