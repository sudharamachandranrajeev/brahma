import 'dart:async';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import 'charts.dart';
import 'common.dart';
import 'zen.dart';

Future<void> openFocus(BuildContext context, {String? courseId}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => FocusPage(courseId: courseId)));

/// A quiet countdown. When it ends, or is ended early, the time is logged
/// as a study session.
class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key, this.courseId});
  final String? courseId;

  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage> {
  static const presets = [15, 25, 45, 60];

  var _minutes = 25;
  late var _course = widget.courseId ?? '';
  Timer? _tick;

  /// Time counted before the latest start; the clock, not the ticks, is
  /// the measure, so a slow frame or a paused app loses nothing.
  var _banked = Duration.zero;
  DateTime? _since;
  var _logged = false;

  Duration get _elapsed => _banked + (_since == null ? Duration.zero : DateTime.now().difference(_since!));
  Duration get _goal => Duration(minutes: _minutes);
  bool get _running => _since != null;
  bool get _started => _running || _banked > Duration.zero;

  void _start() {
    _since = DateTime.now();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_elapsed >= _goal) {
        _finish();
      } else {
        setState(() {});
      }
    });
    setState(() {});
  }

  void _pause() {
    _banked = _elapsed;
    _since = null;
    _tick?.cancel();
    setState(() {});
  }

  Future<void> _finish() async {
    if (_logged) return;
    final spent = _elapsed > _goal ? _goal : _elapsed;
    _tick?.cancel();
    _banked = spent;
    _since = null;
    _logged = true;
    final m = spent.inMinutes;
    if (m >= 1) {
      await ref.mutate(
        (s) => s.book.logSession(
          m,
          today: today(),
          courseId: _course.isEmpty ? null : _course,
          note: 'Focus session',
        ),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final courses = (ref.watch(coursesProvider).value ?? const <Course>[])
        .where((c) => c.status != 'done' && c.status != 'dropped' || c.id == _course)
        .toList();
    final left = _goal - _elapsed;
    final shown = left.isNegative ? Duration.zero : left;
    final mm = shown.inMinutes.toString().padLeft(2, '0'),
        ss = (shown.inSeconds % 60).toString().padLeft(2, '0');
    return Backdrop(
      child: Scaffold(
        appBar: AppBar(title: const Text('Focus')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      label: _logged ? 'Session logged' : '$mm minutes $ss seconds left',
                      child: Ring(
                        value: _elapsed.inMilliseconds / _goal.inMilliseconds,
                        size: 240,
                        stroke: 12,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _logged ? minutesText(_banked.inMinutes) : '$mm:$ss',
                              style: t.displayMedium?.merge(tabular),
                            ),
                            Text(
                              _logged
                                  ? (_banked.inMinutes >= 1 ? 'logged' : 'too short to log')
                                  : _running
                                  ? 'breathe, and stay with it'
                                  : _started
                                  ? 'paused'
                                  : 'ready when you are',
                              style: t.bodyMedium?.copyWith(color: muted(context)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (!_started) ...[
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final p in presets)
                            ChoiceChip(
                              label: Text('$p min'),
                              selected: _minutes == p,
                              onSelected: (_) => setState(() => _minutes = p),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Choice<String>(
                        label: 'Course',
                        value: _course,
                        options: {'': 'No course', for (final c in courses) c.id: c.title},
                        onChanged: (v) => setState(() => _course = v),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (_logged)
                      FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))
                    else
                      Wrap(
                        spacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: _running ? _pause : _start,
                            icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                            label: Text(_running ? 'Pause' : (_started ? 'Resume' : 'Begin')),
                          ),
                          if (_started)
                            OutlinedButton.icon(
                              onPressed: _finish,
                              icon: const Icon(Icons.stop),
                              label: const Text('End and log'),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
