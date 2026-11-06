import 'package:flutter/material.dart';

import 'providers.dart';
import 'updater.dart';

/// Asks GitHub for a newer version and, when there is one, offers to
/// install it. Says so when this is the newest.
Future<void> checkForUpdate(BuildContext context, AppUpdater updater) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(const SnackBar(content: Text('Checking for updates…')));
  Release? release;
  try {
    release = await updater.check();
  } on Object catch (e) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(describeError(e))));
    return;
  }
  messenger?.hideCurrentSnackBar();
  if (!context.mounted) return;
  if (release == null) {
    messenger?.showSnackBar(
      SnackBar(content: Text('${updater.app.name} ${updater.current} is the newest version.')),
    );
    return;
  }
  await showUpdate(context, updater, release);
}

/// Shows what is new in [release] and installs it on Update: download with
/// progress, checksum, then the platform's installer.
Future<void> showUpdate(BuildContext context, AppUpdater updater, Release release) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _UpdateDialog(updater, release),
);

enum _Step { offer, downloading, installing, restart, failed }

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog(this.updater, this.release);
  final AppUpdater updater;
  final Release release;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  var _step = _Step.offer;
  double? _done;
  String _error = '';

  Future<void> _update() async {
    setState(() {
      _step = _Step.downloading;
      _done = null;
    });
    try {
      final file = await widget.updater.download(
        widget.release,
        onProgress: (d) => mounted ? setState(() => _done = d) : null,
      );
      if (!mounted) return;
      setState(() => _step = _Step.installing);
      final restart = await widget.updater.install(file);
      if (!mounted) return;
      if (restart) {
        setState(() => _step = _Step.restart);
      } else {
        Navigator.pop(context); // Android: the system installer takes over.
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _step = _Step.failed;
          _error = describeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.release;
    final name = widget.updater.app.name;
    final busy = _step == _Step.downloading || _step == _Step.installing;
    return AlertDialog(
      title: Text(switch (_step) {
        _Step.restart => '$name ${r.version} is installed',
        _Step.failed => 'The update did not install',
        _ => 'Update to $name ${r.version}',
      }),
      content: SizedBox(
        width: 440,
        child: switch (_step) {
          _Step.offer => SingleChildScrollView(
            child: SelectableText(
              'You have ${widget.updater.current}.\n\n'
              '${r.notes.isEmpty ? 'See the release page for what is new.' : r.notes}\n\n'
              'The download is checked against the release checksums before it installs. '
              'Your data stays where it is.',
            ),
          ),
          _Step.downloading || _Step.installing => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _step == _Step.installing
                    ? 'Installing…'
                    : 'Downloading${_done == null ? '' : ' ${(_done! * 100).round()}%'}…',
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _step == _Step.installing ? null : _done),
            ],
          ),
          _Step.restart => Text('Restart $name to start using ${r.version}.'),
          _Step.failed => SelectableText(_error),
        },
      ),
      actions: [
        if (!busy)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_step == _Step.restart ? 'Later' : 'Close'),
          ),
        if (_step == _Step.offer || _step == _Step.failed)
          FilledButton(onPressed: _update, child: Text(_step == _Step.failed ? 'Try again' : 'Update')),
        if (_step == _Step.restart)
          FilledButton(onPressed: widget.updater.restart, child: const Text('Restart now')),
      ],
    );
  }
}
