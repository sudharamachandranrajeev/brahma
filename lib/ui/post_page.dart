import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/models.dart';
import 'common.dart';
import 'compose_page.dart';
import 'look.dart';

Future<void> openPost(BuildContext context, Post post) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PostPage(post: post)));

/// A post's picture: its first media file (videos show generated art with a
/// play mark), shared between list tiles and the detail page so it flies
/// from one to the other.
class PostArt extends StatelessWidget {
  const PostArt({super.key, required this.post, this.media, this.platform});
  final Post post;
  final MediaItem? media;
  final Platform? platform;

  @override
  Widget build(BuildContext context) => Hero(
    tag: 'post-${post.id}',
    child: Stack(
      fit: StackFit.expand,
      children: [
        Artwork(url: media?.isImage ?? false ? media!.url : null, seed: post.id, platform: platform),
        if (media?.isVideo ?? false)
          Center(
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
            ),
          ),
      ],
    ),
  );
}

/// One post: where it goes, how each account fared, and what can still be
/// done with it (edit, publish now, retry, delete).
class PostPage extends ConsumerStatefulWidget {
  const PostPage({super.key, required this.post});
  final Post post;

  @override
  ConsumerState<PostPage> createState() => _PostPageState();
}

class _PostPageState extends ConsumerState<PostPage> {
  late Post post = widget.post;

  Future<void> _act(Future<Post> Function() call, String done) async {
    final ok = await guarded(context, () async => post = await call());
    if (ok && mounted) {
      setState(() {});
      showMessage(context, done);
    }
  }

  Future<void> _retry() async {
    var force = false;
    if (post.maybePosted) {
      force = await confirm(
        context,
        title: 'It may already be posted',
        message:
            'The platform may have accepted this post before the error. Check the account first: retrying '
            'could post it twice.',
        action: 'Retry anyway',
        destructive: true,
      );
      if (!force) return;
    }
    await _act(() => ref.hub((h) => h.retryPost(post.id, force: force)), 'Retrying now.');
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete this post?',
      message: post.status == 'published'
          ? 'It stays on the platforms; Vani forgets it.'
          : 'It will not be published.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    if (await guarded(context, () => ref.hub((h) => h.deletePost(post.id))) && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accounts = {for (final a in ref.watch(accountsProvider).value ?? const <Account>[]) a.id: a};
    final media = {for (final m in ref.watch(mediaProvider).value ?? const <MediaItem>[]) m.id: m};
    final first = post.media.isEmpty ? null : media[post.media.first];
    final look = statusLook(post.status);
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final failed = post.targets.any((x) => x.status == 'failed');
    final art = ClipRRect(
      borderRadius: BorderRadius.circular(cardRadius),
      child: AspectRatio(
        aspectRatio: narrow ? 4 / 3 : 1,
        child: PostArt(
          post: post,
          media: first,
          platform: accounts[post.targets.firstOrNull?.accountId]?.platform,
        ),
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Tag(look.label, color: look.color, icon: look.icon),
            Tag(whenLabel(post.when), icon: Icons.schedule_rounded),
            if (post.recycleDays != null)
              Tag('Repeats every ${post.recycleDays} days', icon: Icons.autorenew_rounded),
            for (final tag in post.tags) Tag('#$tag'),
          ],
        ),
        if (post.maybePosted) ...[
          const SizedBox(height: 16),
          WarningBox(
            'An account failed after the platform may already have taken the post. Check it there before retrying.',
          ),
        ],
        const SizedBox(height: 18),
        SelectableText(post.text.ifEmpty('(no text)'), style: t.bodyLarge),
        if (post.media.length > 1) ...[
          const SizedBox(height: 12),
          Text('${post.media.length} media files', style: t.bodySmall),
        ],
        const SizedBox(height: 22),
        Text('Accounts', style: t.titleMedium),
        const SizedBox(height: 10),
        for (final target in post.targets)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TargetRow(target: target, account: accounts[target.accountId]),
          ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (post.editable)
              FilledButton.icon(
                onPressed: () async {
                  await openCompose(context, post: post);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit'),
              ),
            if (post.editable)
              OutlinedButton.icon(
                onPressed: () => _act(() => ref.hub((h) => h.publishPost(post.id)), 'Publishing now.'),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Publish now'),
              ),
            if (failed)
              FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            OutlinedButton.icon(
              onPressed: () => openCompose(
                context,
                text: post.text,
                accountIds: [for (final x in post.targets) x.accountId],
              ),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Duplicate'),
            ),
            TextButton.icon(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete'),
            ),
          ],
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(narrow ? 16 : 28, 8, narrow ? 16 : 28, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: narrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [art, const SizedBox(height: 20), details],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: art),
                        const SizedBox(width: 28),
                        Expanded(
                          flex: 6,
                          child: Panel(padding: const EdgeInsets.all(24), child: details),
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

class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.target, this.account});
  final Target target;
  final Account? account;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final look = statusLook(target.status);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Tone.of(context).cardHigh, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (account != null) PlatformBadge(account!.platform, size: 34) else const Icon(Icons.help_outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${account?.name ?? 'Removed account'} · ${formatLabel(target.format)}',
                  style: t.titleSmall,
                ),
                if (target.title != null) Text(target.title!, style: t.bodySmall),
                if (target.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(target.error!, style: t.bodySmall?.copyWith(color: signal)),
                  ),
                if (target.attempts > 1) Text('${target.attempts} attempts', style: t.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Tag(look.label, color: look.color),
              if (target.permalink != null)
                TextButton(
                  onPressed: () => openLink(context, target.permalink!),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Open'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class WarningBox extends StatelessWidget {
  const WarningBox(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
