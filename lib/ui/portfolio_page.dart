import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/book.dart';
import 'charts.dart';
import 'common.dart';
import 'dialogs.dart';
import 'zen.dart';

const _icons = {
  'project': Icons.code,
  'certificate': Icons.workspace_premium_outlined,
  'publication': Icons.article_outlined,
  'talk': Icons.record_voice_over_outlined,
  'contribution': Icons.merge_type,
  'degree': Icons.school_outlined,
};

class PortfolioPage extends ConsumerWidget {
  const PortfolioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageScaffold(
    title: 'Portfolio',
    banner: 'page.portfolio',
    fab: FloatingActionButton.extended(
      onPressed: () => portfolioDialog(context, ref),
      icon: const Icon(Icons.add),
      label: const Text('Add'),
    ),
    body: AsyncView(
      ref.watch(statsProvider),
      onRetry: () => ref.invalidate(statsProvider),
      builder: (s) {
        final t = Theme.of(context).textTheme;
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 96 + MediaQuery.paddingOf(context).bottom),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Ring(
                              value: s.portfolioScore / 100,
                              size: 84,
                              stroke: 8,
                              child: Text('${s.portfolioScore}', style: t.titleLarge?.merge(tabular)),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Portfolio strength', style: t.titleMedium),
                                  const SizedBox(height: 4),
                                  Text(
                                    s.portfolio.isEmpty
                                        ? 'Add your first project, certificate or talk.'
                                        : s.unbackedSkills.isEmpty
                                        ? 'Every skill you have is backed by something you show.'
                                        : 'Nothing yet shows: ${s.unbackedSkills.take(4).map((k) => k.name).join(', ')}.',
                                    style: t.bodyMedium?.copyWith(color: muted(context)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (s.portfolio.isEmpty)
                      const EmptyState(
                        icon: Icons.folder_special_outlined,
                        title: 'Nothing here yet',
                        message: 'Work you can point to is the strongest evidence of what you know.',
                      ),
                    for (final p in s.portfolio)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            leading: Icon(_icons[p.kind] ?? Icons.folder_outlined),
                            title: Text(p.title),
                            subtitle: Text(
                              [
                                portfolioKinds[p.kind] ?? p.kind,
                                niceDate(p.day),
                                if (p.skills.isNotEmpty) p.skills,
                                if (p.summary.isNotEmpty) p.summary,
                              ].join(' · '),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: p.url.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.open_in_new),
                                    tooltip: 'Open',
                                    onPressed: () => openLink(context, p.url),
                                  ),
                            onTap: () => portfolioDialog(context, ref, item: p),
                            onLongPress: () async {
                              if (await askSure(context, 'Delete item?', p.title) && context.mounted) {
                                await ref.mutate((x) => x.book.remove(x.db.learnPortfolio, p.id));
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
