import 'dart:convert';

import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../dates.dart';
import '../ui/widgets.dart' show Status;
import 'core_checks.dart';

/// Sentinel, Brahma's security watch. Each [SecurityCheck] looks at one
/// thing (sync, updates, an app's tokens) and reports what needs attention
/// as [Finding]s; the Sentinel page lists them, with a fix where there is
/// one. Nothing is changed unless the user taps that fix.

/// A fix the user can apply with one tap.
class QuickFix {
  const QuickFix(this.label, this.run);

  /// The button, e.g. "Sync now".
  final String label;

  /// Gets a context to ask with (a dialog) and the ref to change things.
  final Future<void> Function(BuildContext context, WidgetRef ref) run;
}

/// One thing that needs attention.
class Finding {
  const Finding({
    required this.id,
    required this.status,
    required this.title,
    required this.why,
    this.steps,
    this.fix,
  });

  /// Stable across runs, so a snooze outlasts a restart, e.g. 'sync.stale'.
  final String id;

  /// [Status.info], [Status.warning], [Status.serious] or [Status.critical].
  /// Info is worth knowing but not counted as something to fix.
  final Status status;
  final String title;

  /// What the risk is, in plain words.
  final String why;

  /// What to do about it, when there is no [fix] or as well as one.
  final String? steps;
  final QuickFix? fix;
}

/// One check. [findings] is a provider, so each check decides what it
/// watches and how often it runs: a network check once per start, a sync
/// check whenever sync changes. A check that throws shows as an info
/// finding, so a broken check is seen rather than read as all clear.
class SecurityCheck {
  const SecurityCheck({required this.id, required this.title, required this.findings});
  final String id;

  /// What is checked, e.g. "Updates".
  final String title;
  final FutureProvider<List<Finding>> findings;
}

/// Every check that runs: core's, plus the app's own. The suite app adds
/// each hosted app's [SuiteApp.securityChecks].
final sentinelChecksProvider = Provider<List<SecurityCheck>>((ref) => coreChecks);

/// What the checks found, most severe first, without snoozed findings.
class SentinelReport {
  const SentinelReport(this.findings, {required this.checking, required this.snoozed});
  final List<Finding> findings;

  /// Some checks have not finished yet.
  final bool checking;

  /// How many findings are snoozed and hidden.
  final int snoozed;

  /// The findings worth acting on (all but info).
  List<Finding> get toFix => [
    for (final f in findings)
      if (f.status != Status.info) f,
  ];

  /// The most severe status of [toFix], or [Status.good] when there is none.
  Status get status => toFix.firstOrNull?.status ?? Status.good;
}

const _order = [Status.critical, Status.serious, Status.warning, Status.info];

final sentinelProvider = Provider<SentinelReport>((ref) {
  final snoozes = ref.watch(snoozesProvider).value ?? const {};
  var checking = false, snoozed = 0;
  final found = <Finding>[];
  for (final check in ref.watch(sentinelChecksProvider)) {
    final v = ref.watch(check.findings);
    if (v.hasValue) {
      found.addAll(v.value!);
    } else if (v.hasError) {
      found.add(
        Finding(
          id: '${check.id}.failed',
          status: Status.info,
          title: 'Could not check: ${check.title}',
          why: describeError(v.error!),
        ),
      );
    } else {
      checking = true;
    }
  }
  final shown = <Finding>[];
  for (final f in found) {
    if (snoozes.containsKey(f.id)) {
      snoozed++;
    } else {
      shown.add(f);
    }
  }
  shown.sort((a, b) => _order.indexOf(a.status).compareTo(_order.indexOf(b.status)));
  return SentinelReport(shown, checking: checking, snoozed: snoozed);
});

/// Runs every check again.
void recheck(WidgetRef ref) {
  for (final check in ref.read(sentinelChecksProvider)) {
    ref.invalidate(check.findings);
  }
}

/// Snoozed findings by id, each with the day it shows again. Kept on this
/// device only, like the findings themselves.
class Snoozes extends AsyncNotifier<Map<String, String>> {
  static const _key = 'sentinel.snoozed';

  @override
  Future<Map<String, String>> build() async {
    final saved = await ref.watch(coreSessionProvider).db.localSetting(_key);
    final all = saved == null ? <String, String>{} : (jsonDecode(saved) as Map).cast<String, String>();
    final now = today();
    return {
      for (final e in all.entries)
        if (e.value.compareTo(now) > 0) e.key: e.value,
    };
  }

  Future<void> _save(Map<String, String> s) async {
    state = AsyncData(s);
    await ref.read(coreSessionProvider).db.setLocalSetting(_key, jsonEncode(s));
  }

  Future<void> snooze(String id, {int days = 30}) =>
      _save({...state.value ?? const {}, id: addDays(today(), days)});

  /// Shows every snoozed finding again.
  Future<void> restore() => _save(const {});
}

final snoozesProvider = AsyncNotifierProvider<Snoozes, Map<String, String>>(Snoozes.new);
