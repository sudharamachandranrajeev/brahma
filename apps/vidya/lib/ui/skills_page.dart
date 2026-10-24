import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/book.dart';
import 'common.dart';
import 'dialogs.dart';
import 'zen.dart';

class SkillsPage extends ConsumerWidget {
  const SkillsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageScaffold(
    title: 'Skills',
    banner: 'page.skills',
    fab: FloatingActionButton.extended(
      onPressed: () => skillDialog(context, ref),
      icon: const Icon(Icons.add),
      label: const Text('Skill'),
    ),
    body: AsyncView(
      ref.watch(skillsProvider),
      onRetry: () => ref.invalidate(skillsProvider),
      builder: (skills) {
        if (skills.isEmpty) {
          return const EmptyState(
            icon: Icons.track_changes,
            title: 'No skills yet',
            message:
                'List what you can do, or want to. Importing a program template adds the skills it builds.',
          );
        }
        final groups = <String, List<Skill>>{};
        for (final k in skills) {
          (groups[k.category] ??= []).add(k);
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 96 + MediaQuery.paddingOf(context).bottom),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final g in groups.entries)
                      SectionCard(
                        title: g.key,
                        child: Column(children: [for (final k in g.value) _SkillRow(k)]),
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

class _SkillRow extends ConsumerWidget {
  const _SkillRow(this.k);
  final Skill k;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(k.name),
      subtitle: Text(
        '${skillLevels[k.level]}${k.level >= k.target ? ' · on target' : ' · aiming for ${skillLevels[k.target]}'}',
      ),
      onTap: () => skillDialog(context, ref, skill: k),
      onLongPress: () async {
        if (await askSure(context, 'Delete skill?', k.name) && context.mounted) {
          await ref.mutate((s) => s.book.remove(s.db.learnSkills, k.id));
        }
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Semantics(
              label: 'Set ${k.name} to level $i',
              button: true,
              child: InkResponse(
                radius: 18,
                onTap: () =>
                    ref.mutate((s) => s.book.setSkillLevel(k, k.level == i ? i - 1 : i, today: today())),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    i <= k.level ? Icons.circle : (i == k.target ? Icons.adjust : Icons.circle_outlined),
                    size: 16,
                    color: i <= k.level ? primary : muted(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
