import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/providers.dart';
import '../identity.dart';

/// Reporting a problem or suggesting a feature as a GitHub issue. The app
/// holds no GitHub token: it opens GitHub's new-issue page with the report
/// filled in, and the user signs in and submits it there. Nothing is sent
/// until they do, and they see and can edit every word first.

enum ReportKind {
  bug('Report a problem', 'bug', 'Bug'),
  feature('Suggest a feature', 'enhancement', 'Feature');

  const ReportKind(this.label, this.githubLabel, this.prefix);
  final String label, githubLabel, prefix;
}

/// Where an app's issues go: its own repository, else Brahma's.
String issueRepo(AppIdentity app) => app.releases ?? 'sudharamachandranrajeev/brahma';

/// The last few errors the user met (shown to them, or uncaught), newest
/// last, to attach to a problem report if they choose.
abstract final class AppErrors {
  static final recent = <String>[];
  static var _watching = false;

  static void record(Object error, [StackTrace? stack]) {
    final frames = stack == null
        ? ''
        : '\n${stack.toString().split('\n').where((l) => l.trim().isNotEmpty).take(8).join('\n')}';
    recent.add('$error$frames');
    if (recent.length > 3) recent.removeAt(0);
  }

  static String? get last => recent.lastOrNull;

  /// Keeps uncaught errors too, after whatever handled them before.
  static void watch() {
    if (_watching) return;
    _watching = true;
    final flutter = FlutterError.onError;
    FlutterError.onError = (details) {
      record(details.exception, details.stack);
      flutter?.call(details);
    };
    final platform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack);
      return platform?.call(error, stack) ?? false;
    };
  }
}

/// The issue text.
String reportBody({
  required ReportKind kind,
  required String app,
  required String version,
  required String platform,
  required String details,
  String steps = '',
  String? error,
}) => [
  if (kind == ReportKind.bug) ...[
    '### What happened',
    details,
    if (steps.isNotEmpty) ...['', '### Steps to see it', steps],
    if (error != null) ...['', '### Error', '```', error, '```'],
  ] else ...[
    '### What would help',
    details,
    if (steps.isNotEmpty) ...['', '### How it would work', steps],
  ],
  '',
  '---',
  '$app $version on $platform. Sent from the app\'s ${kind.label} form.',
].join('\n');

/// GitHub's new-issue page with [title] and [body] filled in. GitHub only
/// applies the label when the user may label issues.
Uri issueLink({required String repo, required ReportKind kind, required String title, required String body}) {
  // Long addresses fail; the clipboard has the full text.
  final short = body.length > 6000 ? '${body.substring(0, 6000)}\n\n(Cut short: paste the rest.)' : body;
  return Uri.https('github.com', '/$repo/issues/new', {
    'title': '${kind.prefix}: $title',
    'body': short,
    'labels': kind.githubLabel,
  });
}

Future<void> showReport(BuildContext context, {ReportKind kind = ReportKind.bug, String? error}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ReportDialog(kind: kind, error: error ?? AppErrors.last),
    );

class _ReportDialog extends ConsumerStatefulWidget {
  const _ReportDialog({required this.kind, this.error});
  final ReportKind kind;
  final String? error;

  @override
  ConsumerState<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<_ReportDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _details = TextEditingController();
  final _steps = TextEditingController();
  late var _kind = widget.kind;
  bool _withError = true;
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (mounted) setState(() => _version = p.version);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    for (final c in [_title, _details, _steps]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _body => reportBody(
    kind: _kind,
    app: ref.read(appIdentityProvider).name,
    version: _version,
    platform: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    details: _details.text.trim(),
    steps: _steps.text.trim(),
    error: _kind == ReportKind.bug && _withError ? widget.error : null,
  );

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final body = _body;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: body));
    final link = issueLink(
      repo: issueRepo(ref.read(appIdentityProvider)),
      kind: _kind,
      title: _title.text.trim(),
      body: body,
    );
    final ok = await launchUrl(link, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'GitHub is open with your report. Sign in there and choose Submit new issue.'
              : 'Could not open the browser. The report is copied: paste it at github.com/'
                    '${issueRepo(ref.read(appIdentityProvider))}/issues/new',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bug = _kind == ReportKind.bug;
    final theme = Theme.of(context);
    final error = widget.error;
    return AlertDialog(
      title: Text(_kind.label),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<ReportKind>(
                  segments: [
                    for (final k in ReportKind.values) ButtonSegment(value: k, label: Text(k.prefix)),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _title,
                  decoration: InputDecoration(
                    labelText: bug ? 'In a few words, what went wrong?' : 'In a few words, what would help?',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').trim().length < 4 ? 'Give it a short title' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _details,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: bug ? 'What happened, and what did you expect?' : 'What do you want to do?',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Say a little more' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _steps,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: bug ? 'Steps to see it (optional)' : 'How it could work (optional)',
                    hintText: bug ? '1. Open …\n2. Tap …' : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (bug && error != null) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _withError,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _withError = v ?? false),
                    title: const Text('Include the last error'),
                    subtitle: Text(error, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'This opens GitHub in your browser with the report filled in; sign in there (a free '
                  'account) and choose Submit. Issues are public: leave out names, e-mail addresses, '
                  'amounts and anything else private. The app version and system are added.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _send,
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Continue on GitHub'),
        ),
      ],
    );
  }
}
