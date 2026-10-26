import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../sentinel/core_checks.dart' show releasesClientProvider, updateChecksProvider;
import '../sentinel/releases.dart';
import 'providers.dart';

/// Hours between asks to GitHub; in between, the last answer is reused.
const _checkEvery = Duration(hours: 24);
const _checkedKey = 'update.checked', _newestKey = 'update.newest', _dismissedKey = 'update.dismissed';

/// The newest release worth telling the user about at start-up, or null. Asks
/// GitHub at most once a day; an app without a releases repository, or with
/// update checks turned off in Sentinel, is never told.
final startupUpdateProvider = FutureProvider<ReleaseInfo?>((ref) async {
  final repo = ref.watch(appIdentityProvider).releases;
  if (repo == null || !await ref.watch(updateChecksProvider.future)) return null;
  final db = ref.watch(coreSessionProvider).db;
  final checked = DateTime.tryParse(await db.localSetting(_checkedKey) ?? '');
  ReleaseInfo? newest;
  if (checked != null && DateTime.now().toUtc().difference(checked) < _checkEvery) {
    newest = _decode(await db.localSetting(_newestKey));
    // The cache is checked like a fresh answer, so an edited one cannot redirect.
    if (newest != null &&
        (!isReleaseUrl(newest.page, repo) ||
            (newest.download != null && !isReleaseUrl(newest.download!, repo)))) {
      newest = null;
    }
  } else {
    try {
      newest = await fetchNewestRelease(ref.watch(releasesClientProvider), repo);
    } on CheckFailed {
      return null; // Offline: say nothing, ask again next start.
    }
    await db.setLocalSetting(_checkedKey, DateTime.now().toUtc().toIso8601String());
    await db.setLocalSetting(_newestKey, newest == null ? '' : _encode(newest));
  }
  if (newest == null) return null;
  final current = (await PackageInfo.fromPlatform()).version;
  if (!isNewerVersion(newest.version, current)) return null;
  if (await db.localSetting(_dismissedKey) == newest.version) return null;
  return newest;
});

String _encode(ReleaseInfo r) =>
    jsonEncode({'v': r.version, 'p': '${r.page}', 'n': r.notes, 'd': r.download?.toString()});

ReleaseInfo? _decode(String? text) {
  if (text == null || text.isEmpty) return null;
  try {
    final m = jsonDecode(text) as Map<String, Object?>;
    final d = m['d'] as String?;
    return (
      version: m['v']! as String,
      page: Uri.parse(m['p']! as String),
      notes: (m['n'] as String?) ?? '',
      download: d == null ? null : Uri.parse(d),
    );
  } catch (_) {
    return null;
  }
}

/// Puts a "new version" banner above [child] when [startupUpdateProvider]
/// finds one: What's new, Download (the installer for this platform, else
/// the release page) and Later (hides this version; the next one shows).
class UpdateNotice extends ConsumerStatefulWidget {
  const UpdateNotice({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<UpdateNotice> createState() => _UpdateNoticeState();
}

class _UpdateNoticeState extends ConsumerState<UpdateNotice> {
  bool _hidden = false;

  Future<void> _later(ReleaseInfo r) async {
    setState(() => _hidden = true);
    await ref.read(coreSessionProvider).db.setLocalSetting(_dismissedKey, r.version);
  }

  Future<void> _download(ReleaseInfo r) async {
    if (!await launchUrl(r.download ?? r.page, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('Could not open ${r.page}')));
    }
  }

  void _notes(ReleaseInfo r) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("What's new in ${r.version}"),
      content: SingleChildScrollView(
        child: SelectableText(r.notes.isEmpty ? 'See the release page for the details.' : r.notes),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            _download(r);
          },
          child: const Text('Download'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final release = _hidden ? null : ref.watch(startupUpdateProvider).value;
    if (release == null) return widget.child;
    final name = ref.watch(appIdentityProvider).name;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Material(
          color: scheme.primaryContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.system_update_outlined, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 12),
                      Text(
                        '$name ${release.version} is out',
                        style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(onPressed: () => _notes(release), child: const Text("What's new")),
                      TextButton(onPressed: () => _later(release), child: const Text('Later')),
                      FilledButton(onPressed: () => _download(release), child: const Text('Download')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(context: context, removeTop: true, child: widget.child),
        ),
      ],
    );
  }
}
