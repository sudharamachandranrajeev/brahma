import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import 'common.dart';
import 'zen.dart';

Future<void> noteEditor(BuildContext context, WidgetRef ref, {Note? note}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _NoteEditor(note)));

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  var _query = '';
  String? _tag;

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Notes',
    banner: 'page.notes',
    fab: FloatingActionButton.extended(
      onPressed: () => noteEditor(context, ref),
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Note'),
    ),
    body: AsyncView(
      ref.watch(notesProvider),
      onRetry: () => ref.invalidate(notesProvider),
      builder: (notes) {
        final tags = <String>{
          for (final n in notes) ...n.tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty),
        }.toList()..sort();
        final q = _query.toLowerCase();
        final shown = notes
            .where((n) => _tag == null || n.tags.split(',').map((t) => t.trim()).contains(_tag))
            .where((n) => q.isEmpty || n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q))
            .toList();
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 96 + MediaQuery.paddingOf(context).bottom),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search notes',
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    if (tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final t in tags)
                              FilterChip(
                                label: Text(t),
                                selected: _tag == t,
                                onSelected: (on) => setState(() => _tag = on ? t : null),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (notes.isEmpty)
                      const EmptyState(
                        icon: Icons.edit_note,
                        title: 'No notes yet',
                        message: 'Writing what you learned in your own words is how it stays.',
                      )
                    else if (shown.isEmpty)
                      const EmptyState(icon: Icons.search_off, title: 'Nothing matches'),
                    for (final n in shown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            title: Text(n.title),
                            subtitle: Text(
                              [
                                n.body.replaceAll('\n', ' '),
                                if (n.tags.isNotEmpty)
                                  '#${n.tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).join(' #')}',
                              ].where((e) => e.isNotEmpty).join('\n'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => noteEditor(context, ref, note: n),
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

class _NoteEditor extends ConsumerStatefulWidget {
  const _NoteEditor(this.note);
  final Note? note;

  @override
  ConsumerState<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<_NoteEditor> {
  late final _title = TextEditingController(text: widget.note?.title ?? '');
  late final _body = TextEditingController(text: widget.note?.body ?? '');
  late final _tags = TextEditingController(text: widget.note?.tags ?? '');

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return showMessage(context, 'Give the note a title.');
    await ref.mutate(
      (s) => s.book.saveNote(
        _title.text.trim(),
        _body.text,
        _tags.text.trim(),
        today: today(),
        existing: widget.note,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Backdrop(
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New note' : 'Note'),
        actions: [
          if (widget.note != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await askSure(context, 'Delete note?', widget.note!.title) || !context.mounted) return;
                await ref.mutate((s) => s.book.remove(s.db.learnNotes, widget.note!.id));
                if (context.mounted) Navigator.pop(context);
              },
            ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  Field(_title, 'Title', autofocus: widget.note == null),
                  Field(_tags, 'Tags', hint: 'Comma-separated'),
                  Field(_body, 'Note', lines: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
