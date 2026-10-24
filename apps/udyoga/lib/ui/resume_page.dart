import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/insights.dart';
import '../domain/json.dart';
import '../domain/resume.dart';
import 'common.dart';

const _docxMime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

/// A CV: what tailoring changed, the cover letter, the CV itself and export.
class ResumePage extends ConsumerWidget {
  const ResumePage(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(resumesProvider);
    final r = all.value?.where((r) => r.id == id).firstOrNull;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: all.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const EmptyState(icon: Icons.description_outlined, title: 'This CV was removed'),
      );
    }
    final doc = ResumeDoc.fromJson(decodeObject(r.content));
    final notes = r.tailoring.isEmpty ? null : TailorNotes(decodeObject(r.tailoring));
    final file = _fileName(doc.name, r.name);
    return PageScaffold(
      title: r.name,
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete',
          onPressed: () => _delete(context, ref, r),
        ),
      ],
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => saveBytes(context, '$file.docx', doc.toDocx(), mime: _docxMime),
              icon: const Icon(Icons.download),
              label: const Text('Word document'),
            ),
            OutlinedButton.icon(
              onPressed: () => saveBytes(context, '$file.txt', utf8.encode(doc.toText()), mime: 'text/plain'),
              icon: const Icon(Icons.text_snippet_outlined),
              label: const Text('Plain text'),
            ),
            OutlinedButton.icon(
              onPressed: () => copyText(context, doc.toText(), what: 'CV copied.'),
              icon: const Icon(Icons.copy),
              label: const Text('Copy'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (notes != null) ...[
          SectionCard(
            title: 'Before you send it',
            trailing: notes.atsScore > 0 ? FitBadge(notes.atsScore) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (notes.atsScore > 0)
                  Text('Keyword match for applicant tracking systems: ${notes.atsScore}%.'),
                if (notes.cautions.isNotEmpty) ...[
                  const Subhead('Check these'),
                  Bullets(notes.cautions, icon: Icons.warning_amber_rounded, color: Status.warning.color),
                ],
                if (notes.missing.isNotEmpty) ...[
                  const Subhead('Keywords not in your CV'),
                  const Text('Only add them if they are true of you; otherwise be ready to address them.'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final k in notes.missing) Chip(label: Text(k))],
                  ),
                ],
                if (notes.covered.isNotEmpty) ...[
                  const Subhead('Keywords covered'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final k in notes.covered)
                        Chip(
                          avatar: Icon(Icons.check, size: 16, color: Status.good.color),
                          label: Text(k),
                        ),
                    ],
                  ),
                ],
                if (notes.changes.isNotEmpty) ...[const Subhead('What was changed'), Bullets(notes.changes)],
              ],
            ),
          ),
          if (notes.coverLetter.isNotEmpty)
            SectionCard(
              title: 'Cover letter',
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy',
                onPressed: () => copyText(context, notes.coverLetter, what: 'Cover letter copied.'),
              ),
              child: SelectableText(notes.coverLetter),
            ),
        ],
        SectionCard(title: 'The CV', child: SelectableText(doc.toText())),
      ],
    );
  }

  static String _fileName(String person, String name) {
    final base = [person, name].where((s) => s.isNotEmpty).join(' - ');
    final clean = base.replaceAll(RegExp(r'[\\/:*?"<>|]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.isEmpty ? 'CV' : clean.substring(0, clean.length.clamp(0, 80));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Resume r) async {
    if (!await confirm(
      context,
      title: 'Delete this CV?',
      message: 'It is removed from every device. Files you saved are kept.',
      action: 'Delete',
      destructive: true,
    )) {
      return;
    }
    await ref.mutate((s) => s.book.remove(s.db.careerResumes, r.id));
    if (context.mounted) Navigator.of(context).maybePop();
  }
}
