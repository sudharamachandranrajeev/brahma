import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/book.dart';
import '../domain/humanizer.dart';
import '../domain/json.dart';
import '../domain/linkedin.dart';
import 'carousel.dart';
import 'common.dart';
import 'look.dart';

const _icons = {
  LinkedInTool.profile: Icons.badge_outlined,
  LinkedInTool.post: Icons.edit_note,
  LinkedInTool.comment: Icons.mode_comment_outlined,
  LinkedInTool.outreach: Icons.person_add_alt,
  LinkedInTool.inbox: Icons.inbox_outlined,
  LinkedInTool.replies: Icons.forum_outlined,
  LinkedInTool.plan: Icons.calendar_view_week_outlined,
  LinkedInTool.audit: Icons.insights_outlined,
  LinkedInTool.carousel: Icons.view_carousel_outlined,
  LinkedInTool.repurpose: Icons.recycling,
  LinkedInTool.humanCheck: Icons.fact_check_outlined,
};

final _voiceProvider = FutureProvider<String>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(sessionProvider).book.pref<String>(PrefKeys.linkedInVoice, '');
});

/// The LinkedIn studio: drafts for the user to post and send by hand.
class LinkedInPage extends ConsumerWidget {
  const LinkedInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAi = ref.watch(advisorProvider).value != null;
    final voice = ref.watch(_voiceProvider).value ?? '';
    final reports = ref.watch(reportsProvider).value ?? const <Report>[];
    final recent = reports.where((r) => r.kind.startsWith('linkedin.')).take(30).toList();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return PageScaffold(
      title: 'LinkedIn',
      banner: 'page.linkedin',
      children: [
        if (!hasAi) const NeedsKey(what: 'The LinkedIn drafts'),
        SectionCard(
          title: 'Your voice',
          hint: 'linkedin.voice',
          trailing: TextButton(
            onPressed: () => _editVoice(context, ref, voice),
            child: Text(voice.isEmpty ? 'Describe' : 'Edit'),
          ),
          child: Text(
            voice.isEmpty
                ? 'How you write: a few words on tone and two or three lines you have written yourself. Every '
                      'draft follows it.'
                : voice,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: voice.isEmpty ? TextStyle(color: muted) : null,
          ),
        ),
        SectionCard(
          title: 'Tools',
          child: TiltGrid(
            minWidth: 220,
            children: [
              for (final t in LinkedInTool.values)
                _ToolTile(
                  t,
                  enabled: hasAi || t == LinkedInTool.humanCheck,
                  onTap: () => openLinkedInTool(context, ref, t),
                ),
            ],
          ),
        ),
        SectionCard(
          title: 'Recent',
          child: recent.isEmpty
              ? Text('What the tools write is kept here.', style: TextStyle(color: muted))
              : Column(
                  children: [
                    for (final r in recent)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(_icons[LinkedInTool.ofKind(r.kind)] ?? Icons.article_outlined),
                        title: Text(
                          str(decodeObject(r.content)['headline'])
                              .ifEmpty(LinkedInTool.ofKind(r.kind)?.title ?? 'Draft'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${LinkedInTool.ofKind(r.kind)?.title ?? ''} · ${niceDateTime(r.created)}'
                          '${str(decodeObject(r.content)['posted']).isEmpty ? '' : ' · posted'}',
                        ),
                        onTap: () =>
                            Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => LinkedInResultPage(r.id))),
                      ),
                  ],
                ),
        ),
        StatusLabel(
          Status.info,
          'Udyoga only drafts. You post and send everything yourself: tools that post, invite or message '
          'for you break LinkedIn\'s User Agreement and get accounts restricted.',
        ),
      ],
    );
  }

  Future<void> _editVoice(BuildContext context, WidgetRef ref, String voice) async {
    final c = TextEditingController(text: voice);
    await showFormDialog(
      context,
      title: 'Your voice',
      fields: (_) => [
        Field(
          c,
          'How you write',
          lines: 6,
          helper:
              'For example: "Plain and dry, short sentences, a bit of humour, British spelling." Then paste two or '
              'three lines from posts or messages you wrote yourself.',
        ),
      ],
      onSave: () async {
        await ref.mutate((s) => s.book.setPref(PrefKeys.linkedInVoice, c.text.trim()));
        return null;
      },
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile(this.tool, {required this.enabled, required this.onTap});
  final LinkedInTool tool;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_icons[tool], color: scheme.primary),
                const SizedBox(height: 8),
                Text(tool.title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  tool.blurb,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for [tool]'s inputs (starting from [prefill]), runs it and opens
/// the result. The human check runs on the device.
Future<void> openLinkedInTool(
  BuildContext context,
  WidgetRef ref,
  LinkedInTool tool, {
  Map<String, String> prefill = const {},
}) async {
  final controllers = {for (final f in tool.fields) f.key: TextEditingController(text: prefill[f.key] ?? '')};
  final ok = await showFormDialog(
    context,
    title: tool.title,
    action: tool == LinkedInTool.humanCheck ? 'Check' : 'Write',
    width: 600,
    fields: (_) => [
      Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(tool.blurb)),
      for (final f in tool.fields)
        Field(
          controllers[f.key]!,
          f.label,
          lines: f.lines,
          helper: f.helper,
          autofocus: f == tool.fields.first,
        ),
    ],
    onSave: () async {
      final missing = tool.fields.where((f) => !f.optional && controllers[f.key]!.text.trim().isEmpty);
      return missing.isEmpty ? null : 'Fill in "${missing.first.label}".';
    },
  );
  final input = {for (final e in controllers.entries) e.key: e.value.text.trim()};
  if (!ok || !context.mounted) return;
  if (tool == LinkedInTool.humanCheck) return showHumanCheck(context, input['text']!);

  final s = ref.read(sessionProvider);
  final p = await ref.read(profileProvider.future);
  final voice = await s.book.pref<String>(PrefKeys.linkedInVoice, '');
  final history = [
    for (final r in (await ref.read(
      reportsProvider.future,
    )).where((r) => r.kind == LinkedInTool.post.kind).take(12))
      postHistory(decodeObject(r.content), r.created),
  ];
  if (!context.mounted) return;
  final r = await runAi(
    context,
    title: tool.title,
    task: (progress) async => LinkedInCoach(
      (await requireAdvisor(ref)).ai,
      today: today(),
    ).run(tool, input, p, voice: voice, history: history, onProgress: progress),
  );
  if (r == null) return;
  final id = await ref.mutate(
    (s) => s.book.saveReport(tool.kind, {...r.data, 'input': input}, r.sources, at: nowLocal()),
  );
  if (context.mounted) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => LinkedInResultPage(id)));
  }
}

/// A saved result: the score, the sections and their text to paste, each
/// with its length and human check.
class LinkedInResultPage extends ConsumerWidget {
  const LinkedInResultPage(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider).value;
    final r = reports?.where((r) => r.id == id).firstOrNull;
    if (r == null) {
      return PageScaffold(
        title: 'LinkedIn',
        children: [
          if (reports != null)
            const EmptyState(icon: Icons.article_outlined, title: 'This draft was deleted'),
        ],
      );
    }
    final tool = LinkedInTool.ofKind(r.kind);
    final data = decodeObject(r.content);
    final score = intOf(data['score']) ?? -1, after = intOf(data['scoreAfter']) ?? -1;
    final slides = [for (final s in objs(data['slides'])) (title: str(s['title']), body: str(s['body']))];
    final posted = str(data['posted']);
    final next = str(data['next']);
    return PageScaffold(
      title: tool?.title ?? 'LinkedIn',
      actions: [
        if (tool == LinkedInTool.post)
          IconButton(
            tooltip: posted.isEmpty ? 'Mark as posted' : 'Posted ${niceDate(posted)}; tap to undo',
            icon: Icon(posted.isEmpty ? Icons.check_circle_outline : Icons.check_circle),
            onPressed: () => ref.mutate(
              (s) => s.book.save(
                s.db.careerReports,
                r.copyWith(content: jsonEncode({...data, 'posted': posted.isEmpty ? today() : ''})),
                r.id,
              ),
            ),
          ),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _delete(context, ref, r),
        ),
      ],
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(str(data['headline']), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Pill(niceDateTime(r.created), icon: Icons.schedule),
                if (score >= 0)
                  Pill(
                    'Score $score/100',
                    status: score >= 75 ? Status.good : (score >= 50 ? Status.warning : Status.serious),
                  ),
                if (after > score && score >= 0)
                  Pill('After the rewrites: about $after', status: Status.good),
                if (posted.isNotEmpty)
                  Pill('Posted ${niceDate(posted)}', status: Status.good, icon: Icons.check),
              ],
            ),
          ],
        ),
        if (slides.isNotEmpty)
          SectionCard(
            title: 'Carousel PDF',
            trailing: FilledButton.icon(
              onPressed: () => _savePdf(context, ref, slides),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Save PDF'),
            ),
            child: Text(
              '${slides.length} slides, 1080 by 1350. On LinkedIn: Start a post, the + button, Add a document, '
              'then give it a title. Paste the caption above it.',
            ),
          ),
        for (final s in objs(data['sections']))
          SectionCard(
            title: str(s['title']),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final b in objs(s['blocks'])) _BlockView(b)],
            ),
          ),
        if (next.isNotEmpty) StatusLabel(Status.info, 'Next: $next'),
        if (r.sources.isNotEmpty && r.sources != '[]')
          SectionCard(title: 'Sources', child: SourcesList(SourcesList.fromJson(r.sources))),
      ],
    );
  }

  Future<void> _savePdf(BuildContext context, WidgetRef ref, List<Slide> slides) async {
    final p = await ref.read(profileProvider.future);
    final bytes = await carouselPdf(slides, name: p.name);
    if (!context.mounted) return;
    final name = slides.first.title.replaceAll(RegExp(r'[\\/:*?"<>|]+'), ' ').trim();
    await saveBytes(context, '${name.ifEmpty('Carousel')}.pdf', bytes, mime: 'application/pdf');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Report r) async {
    if (!await confirm(
      context,
      title: 'Delete this draft?',
      message: 'It is removed from every device.',
      action: 'Delete',
      destructive: true,
    )) {
      return;
    }
    await ref.mutate((s) => s.book.remove(s.db.careerReports, r.id));
    if (context.mounted) Navigator.of(context).maybePop();
  }
}

class _BlockView extends ConsumerWidget {
  const _BlockView(this.block);
  final Json block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = str(block['text']);
    final note = str(block['note']);
    final copy = block['copy'] == true;
    final limit = intOf(block['limit']) ?? 0;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final check = copy ? humanize(text) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(str(block['label']), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          SelectableText(text),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(note, style: TextStyle(color: muted, fontSize: 13)),
          ],
          if (copy || block['write'] == true) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (copy) ...[
                  Pill(
                    limit > 0 ? '${text.length} / $limit' : '${text.length} characters',
                    status: limit > 0 && text.length > limit ? Status.serious : null,
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => showHumanCheck(context, text),
                    child: Pill(
                      'Human check ${check!.overall}',
                      status: check.pass ? Status.good : Status.warning,
                      icon: Icons.fact_check_outlined,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => copyText(context, check.text, what: 'Copied. Paste it into LinkedIn.'),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
                ],
                if (block['write'] == true && ref.watch(advisorProvider).value != null)
                  TextButton.icon(
                    onPressed: () =>
                        openLinkedInTool(context, ref, LinkedInTool.post, prefill: {'idea': text}),
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text('Write this post'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Cleans [text] of machine marks and shows its five checks, with the
/// cleaned text to copy. Runs on the device.
Future<void> showHumanCheck(BuildContext context, String text) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => HumanCheckPage(text)));

class HumanCheckPage extends StatelessWidget {
  const HumanCheckPage(this.draft, {super.key});
  final String draft;

  @override
  Widget build(BuildContext context) {
    final c = humanize(draft);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return PageScaffold(
      title: 'Human check',
      children: [
        Row(
          children: [
            Text('${c.overall}', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(width: 12),
            Pill(c.verdict, status: c.pass ? Status.good : Status.warning),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => copyText(context, c.text, what: 'Cleaned text copied.'),
              icon: const Icon(Icons.copy),
              label: const Text('Copy cleaned'),
            ),
          ],
        ),
        SectionCard(
          title: 'Checks',
          child: Column(
            children: [
              for (final MapEntry(key: name, value: why) in humanChecks.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          Text('${c.scores[name] ?? 0}'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: (c.scores[name] ?? 0) / 100,
                        color: (c.scores[name] ?? 0) >= 55 ? Status.good.color : Status.warning.color,
                      ),
                      const SizedBox(height: 2),
                      Text(why, style: TextStyle(color: muted, fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (c.fixes > 0 || c.flags.isNotEmpty)
          SectionCard(
            title: 'What it found',
            child: Bullets([
              if (c.invisible > 0)
                'Removed ${c.invisible} invisible character${c.invisible == 1 ? '' : 's'}.',
              if (c.typography > 0)
                'Fixed ${c.typography} dash${c.typography == 1 ? '' : 'es'}, quotes or marks.',
              for (final r in c.replaced) 'Replaced $r.',
              for (final f in c.flags) 'Rewrite by hand: $f',
            ]),
          ),
        SectionCard(title: 'Cleaned text', child: SelectableText(c.text)),
      ],
    );
  }
}

/// Opens the connection note tool for [lead], filled in from the contact.
Future<void> linkedInNoteFor(BuildContext context, WidgetRef ref, Lead lead, {Job? job}) => openLinkedInTool(
  context,
  ref,
  LinkedInTool.outreach,
  prefill: {
    'who': [lead.name, lead.title, lead.company].where((s) => s.isNotEmpty).join(', '),
    'why': [
      if (job != null) 'They are connected to the ${job.title} role at ${job.company} I am interested in.',
      if (lead.notes.isNotEmpty) lead.notes,
    ].join(' '),
    'want': switch (lead.kind) {
      'referral' => 'A referral, or advice on how to apply.',
      'hiring_manager' => 'A short conversation about the role.',
      _ => 'To be considered for suitable roles.',
    },
  },
);
